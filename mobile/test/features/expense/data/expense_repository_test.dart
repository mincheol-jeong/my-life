import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_life/core/database/app_database.dart';
import 'package:my_life/features/expense/data/expense_repository.dart';
import 'package:my_life/features/expense/domain/expense_record.dart';
import 'package:my_life/features/record/domain/life_record.dart';
import 'package:my_life/features/record/domain/local_date.dart';

void main() {
  late AppDatabase database;
  late ExpenseRepository repository;
  late List<String> ids;
  final createdAt = DateTime.utc(2026, 9, 30, 1, 2, 3);

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    ids = ['record-1', 'expense-1', 'record-2', 'expense-2'];
    repository = ExpenseRepository(
      database,
      clock: () => createdAt,
      idGenerator: () => ids.removeAt(0),
    );
  });

  tearDown(() => database.close());

  ExpenseDraft draft({
    int amount = 45000,
    ExpenseCategory category = ExpenseCategory.food,
    PaymentMethod paymentMethod = PaymentMethod.card,
    String? memo = '  저녁 식사  ',
    String? title,
  }) {
    return ExpenseDraft(
      amount: amount,
      category: category,
      paymentMethod: paymentMethod,
      memo: memo,
      title: title,
      eventDate: LocalDate(2026, 9, 30),
      eventTimeMinutes: 19 * 60,
    );
  }

  test('creates one expense row for an Expense record', () async {
    final expense = await repository.create(draft());

    expect(expense.id, 'expense-1');
    expect(expense.record.id, 'record-1');
    expect(expense.record.type, RecordType.expense);
    expect(expense.amount, 45000);
    expect(expense.memo, '저녁 식사');
    expect(expense.record.createdAt, createdAt);
    expect(await database.select(database.records).get(), hasLength(1));
    expect(await database.select(database.expenses).get(), hasLength(1));
  });

  test('rejects zero and negative amounts before writing', () async {
    await expectLater(
      repository.create(draft(amount: 0)),
      throwsA(isA<ExpenseValidationException>()),
    );
    await expectLater(
      repository.create(draft(amount: -1)),
      throwsA(isA<ExpenseValidationException>()),
    );

    expect(await database.select(database.records).get(), isEmpty);
    expect(await database.select(database.expenses).get(), isEmpty);
  });

  test('uses title, memo, then category as the fallback label', () async {
    final titled = await repository.create(draft(title: '  회식  '));
    final memoOnly = await repository.create(draft());
    ids.addAll(['record-3', 'expense-3']);
    final categoryOnly = await repository.create(draft(memo: '  '));

    expect(titled.displayLabel, '회식');
    expect(memoOnly.displayLabel, '저녁 식사');
    expect(categoryOnly.displayLabel, '식비');
  });

  test('updates parent and subtype in one operation', () async {
    final original = await repository.create(draft());
    final updatedAt = createdAt.add(const Duration(hours: 3));
    repository = ExpenseRepository(
      database,
      clock: () => updatedAt,
      idGenerator: () => 'unused',
    );

    final updated = await repository.update(
      original.record.id,
      draft(
        amount: 12000,
        category: ExpenseCategory.transport,
        paymentMethod: PaymentMethod.cash,
        title: '버스',
      ),
    );

    expect(updated.id, original.id);
    expect(updated.record.createdAt, createdAt);
    expect(updated.record.updatedAt, updatedAt);
    expect(updated.amount, 12000);
    expect(updated.category, ExpenseCategory.transport);
    expect(updated.paymentMethod, PaymentMethod.cash);
  });

  test('rolls back the parent record when subtype insertion fails', () async {
    await repository.create(draft());
    ids
      ..clear()
      ..addAll(['record-2', 'expense-1']);

    await expectLater(repository.create(draft()), throwsA(anything));

    final recordIds = (await database.select(database.records).get()).map(
      (row) => row.id,
    );
    expect(recordIds, ['record-1']);
    expect(await database.select(database.expenses).get(), hasLength(1));
  });

  test('enforces foreign key and one-to-one constraints', () async {
    await expectLater(
      database
          .into(database.expenses)
          .insert(
            ExpensesCompanion.insert(
              id: 'orphan',
              recordId: 'missing',
              amount: 1000,
              category: ExpenseCategory.other.databaseValue,
              paymentMethod: PaymentMethod.cash.databaseValue,
            ),
          ),
      throwsA(anything),
    );

    final expense = await repository.create(draft());
    await expectLater(
      database
          .into(database.expenses)
          .insert(
            ExpensesCompanion.insert(
              id: 'duplicate',
              recordId: expense.record.id,
              amount: 1000,
              category: ExpenseCategory.other.databaseValue,
              paymentMethod: PaymentMethod.cash.databaseValue,
            ),
          ),
      throwsA(anything),
    );

    await database
        .into(database.records)
        .insert(
          RecordsCompanion.insert(
            id: 'record-for-zero',
            type: RecordType.expense.databaseValue,
            eventDate: '2026-09-30',
            createdAt: createdAt.millisecondsSinceEpoch,
            updatedAt: createdAt.millisecondsSinceEpoch,
          ),
        );
    await expectLater(
      database
          .into(database.expenses)
          .insert(
            ExpensesCompanion.insert(
              id: 'zero-amount',
              recordId: 'record-for-zero',
              amount: 0,
              category: ExpenseCategory.other.databaseValue,
              paymentMethod: PaymentMethod.cash.databaseValue,
            ),
          ),
      throwsA(anything),
    );
  });

  test('soft delete hides the record and preserves the expense row', () async {
    final expense = await repository.create(draft());

    await repository.softDelete(expense.record.id);

    expect(await repository.getById(expense.record.id), isNull);
    expect(await database.select(database.expenses).get(), hasLength(1));
    final record = await (database.select(
      database.records,
    )..where((row) => row.id.equals(expense.record.id))).getSingle();
    expect(record.deletedAt, createdAt.millisecondsSinceEpoch);
  });
}
