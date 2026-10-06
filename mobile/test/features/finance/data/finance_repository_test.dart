import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_life/core/database/app_database.dart';
import 'package:my_life/features/expense/data/expense_repository.dart';
import 'package:my_life/features/expense/domain/expense_record.dart';
import 'package:my_life/features/finance/data/finance_repository.dart';
import 'package:my_life/features/finance/domain/finance_summary.dart';
import 'package:my_life/features/home/data/home_repository.dart';
import 'package:my_life/features/record/domain/local_date.dart';
import 'package:my_life/features/timeline/data/timeline_repository.dart';
import 'package:my_life/features/timeline/domain/timeline_entry.dart';

void main() {
  late AppDatabase database;
  late ExpenseRepository expenses;
  late FinanceRepository finance;
  final month = LocalDate(2026, 10, 1);

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    expenses = ExpenseRepository(database);
    finance = FinanceRepository(database);
  });
  tearDown(() => database.close());

  test('empty month returns zero and no placeholder breakdowns', () async {
    final result = await finance.watchMonth(month).first;
    expect(result.total, 0);
    expect(result.categories, isEmpty);
    expect(result.days, isEmpty);
  });

  test('grouped totals are exact, deterministic and immutable', () async {
    await expenses.create(draft('2026-10-01', 1000));
    await expenses.create(draft('2026-10-01', 2000));
    await expenses.create(draft('2026-10-31', 3000, ExpenseCategory.shopping));
    await expenses.create(draft('2026-10-05', 1, ExpenseCategory.other));
    final result = await finance.watchMonth(month).first;
    expect(result.total, 6001);
    expect(result.categories.map((e) => (e.category, e.amount)), [
      (ExpenseCategory.food, 3000),
      (ExpenseCategory.shopping, 3000),
      (ExpenseCategory.other, 1),
    ]);
    expect(result.days.map((e) => (e.date.toIso8601String(), e.amount)), [
      ('2026-10-31', 3000),
      ('2026-10-05', 1),
      ('2026-10-01', 3000),
    ]);
    expect(() => result.categories.clear(), throwsUnsupportedError);
    expect(() => result.days.clear(), throwsUnsupportedError);
    expectBalanced(result);
  });

  test(
    'local date boundaries exclude adjacent months and soft deletes',
    () async {
      await expenses.create(draft('2026-09-30', 500));
      await expenses.create(draft('2026-10-01', 1000));
      await expenses.create(draft('2026-10-31', 2000));
      await expenses.create(draft('2026-11-01', 600));
      final deleted = await expenses.create(draft('2026-10-15', 9000));
      await expenses.softDelete(deleted.record.id);
      final result = await finance.watchMonth(LocalDate(2026, 10, 15)).first;
      expect(result.total, 3000);
      expect(result.days.length, 2);
      expect((await database.select(database.expenses).get()).length, 5);
      expectBalanced(result);
    },
  );

  test(
    'December, leap February and last supported year aggregate correctly',
    () async {
      await expenses.create(draft('2026-12-31', 100));
      await expenses.create(draft('2027-01-01', 200));
      await expenses.create(draft('2028-02-29', 300));
      await expenses.create(draft('2028-03-01', 400));
      await expenses.create(draft('9999-12-31', 500));
      expect(
        (await finance.watchMonth(LocalDate(2026, 12, 1)).first).total,
        100,
      );
      expect(
        (await finance.watchMonth(LocalDate(2028, 2, 1)).first).total,
        300,
      );
      expect(
        (await finance.watchMonth(LocalDate(9999, 12, 1)).first).total,
        500,
      );
    },
  );

  test(
    'all categories are included using integer amounts above 32-bit range',
    () async {
      for (final category in ExpenseCategory.values) {
        await expenses.create(draft('2026-10-05', 3000000000, category));
      }
      final result = await finance.watchMonth(month).first;
      expect(result.total, 24000000000);
      expect(result.categories.map((e) => e.category), ExpenseCategory.values);
      expect(result.days.single.amount, result.total);
      expectBalanced(result);
    },
  );

  test(
    'Memo, Photo and unconfirmed payment imports are not expenses',
    () async {
      for (final type in ['MEMO', 'PHOTO']) {
        await database
            .into(database.records)
            .insert(
              RecordsCompanion.insert(
                id: type,
                type: type,
                title: const Value('Not an expense'),
                eventDate: '2026-10-05',
                createdAt: 1,
                updatedAt: 1,
              ),
            );
      }
      await database
          .into(database.paymentImports)
          .insert(
            PaymentImportsCompanion.insert(
              id: 'pending',
              source: 'test',
              externalId: 'id',
              rawText: '승인 10,000원',
              receivedAt: 1,
            ),
          );
      expect((await finance.watchMonth(month).first).total, 0);
      await expenses.create(draft('2026-10-05', 1000));
      expect((await finance.watchMonth(month).first).total, 1000);
    },
  );

  test(
    'stream follows amount, category, day, month edits and soft delete',
    () async {
      final iterator = StreamIterator(finance.watchMonth(month));
      addTearDown(iterator.cancel);
      await iterator.moveNext();
      expect(iterator.current.total, 0);
      final expense = await expenses.create(draft('2026-10-05', 1000));
      await iterator.moveNext();
      expect(iterator.current.total, 1000);
      await expenses.update(
        expense.record.id,
        draft('2026-10-31', 2000, ExpenseCategory.transport),
      );
      await iterator.moveNext();
      expect(
        iterator.current.categories.single.category,
        ExpenseCategory.transport,
      );
      expect(iterator.current.days.single.date, LocalDate(2026, 10, 31));
      expectBalanced(iterator.current);
      await expenses.update(expense.record.id, draft('2026-11-01', 3000));
      await iterator.moveNext();
      expect(iterator.current.total, 0);
      await expenses.update(expense.record.id, draft('2026-10-01', 4000));
      await iterator.moveNext();
      expect(iterator.current.total, 4000);
      await expenses.softDelete(expense.record.id);
      await iterator.moveNext();
      expect(iterator.current.total, 0);
      expect(iterator.current.categories, isEmpty);
      expect(iterator.current.days, isEmpty);
    },
  );

  test(
    'Finance, Home and Timeline agree after create, edit and delete',
    () async {
      final home = HomeRepository(database);
      final timeline = TimelineRepository(database);
      Future<void> verify(int total, int count) async {
        final summary = await finance.watchMonth(month).first;
        expect(summary.total, total);
        expect(await home.watchMonthlyExpense(month).first, total);
        final entries = await timeline
            .watchEntries(const TimelineFilter())
            .first;
        expect(entries.length, count);
        expect(
          entries.fold<int>(0, (sum, e) => sum + (e.expenseAmount ?? 0)),
          total,
        );
        expectBalanced(summary);
      }

      final expense = await expenses.create(draft('2026-10-05', 100));
      await verify(100, 1);
      await expenses.update(expense.record.id, draft('2026-10-06', 200));
      await verify(200, 1);
      await expenses.softDelete(expense.record.id);
      await verify(0, 0);
    },
  );
}

ExpenseDraft draft(
  String date,
  int amount, [
  ExpenseCategory category = ExpenseCategory.food,
]) => ExpenseDraft(
  amount: amount,
  category: category,
  paymentMethod: PaymentMethod.card,
  eventDate: LocalDate.parse(date),
);

void expectBalanced(FinanceSummary value) {
  expect(
    value.categories.fold<int>(0, (sum, e) => sum + e.amount),
    value.total,
  );
  expect(value.days.fold<int>(0, (sum, e) => sum + e.amount), value.total);
}
