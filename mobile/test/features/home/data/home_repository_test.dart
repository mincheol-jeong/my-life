import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_life/core/database/app_database.dart';
import 'package:my_life/features/expense/data/expense_repository.dart';
import 'package:my_life/features/expense/domain/expense_record.dart';
import 'package:my_life/features/home/data/home_repository.dart';
import 'package:my_life/features/record/domain/local_date.dart';

void main() {
  late AppDatabase database;
  late HomeRepository home;
  late ExpenseRepository expenses;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    home = HomeRepository(database);
    expenses = ExpenseRepository(database);
  });
  tearDown(() => database.close());

  test(
    'monthly total includes month boundaries and excludes deleted expenses',
    () async {
      await expenses.create(_draft('2026-09-30', 100));
      await expenses.create(_draft('2026-10-01', 12000));
      await expenses.create(_draft('2026-10-31', 8000));
      await expenses.create(_draft('2026-11-01', 200));
      final deleted = await expenses.create(_draft('2026-10-15', 50000));
      await expenses.softDelete(deleted.record.id);
      expect(
        await home.watchMonthlyExpense(LocalDate(2026, 10, 5)).first,
        20000,
      );
      expect(await home.watchMonthlyExpense(LocalDate(2026, 8, 5)).first, 0);
    },
  );

  test('monthly total handles December and leap February', () async {
    await expenses.create(_draft('2026-12-31', 500));
    await expenses.create(_draft('2027-01-01', 900));
    await expenses.create(_draft('2028-02-29', 300));
    await expenses.create(_draft('2028-03-01', 700));
    expect(await home.watchMonthlyExpense(LocalDate(2026, 12, 1)).first, 500);
    expect(await home.watchMonthlyExpense(LocalDate(2028, 2, 1)).first, 300);
  });

  test(
    'monthly stream follows create, amount edit, month edit, and delete',
    () async {
      final iterator = StreamIterator(
        home.watchMonthlyExpense(LocalDate(2026, 10, 5)),
      );
      addTearDown(iterator.cancel);
      await iterator.moveNext();
      expect(iterator.current, 0);
      final expense = await expenses.create(_draft('2026-10-05', 1000));
      await iterator.moveNext();
      expect(iterator.current, 1000);
      await expenses.update(expense.record.id, _draft('2026-10-05', 2000));
      await iterator.moveNext();
      expect(iterator.current, 2000);
      await expenses.update(expense.record.id, _draft('2026-09-30', 2000));
      await iterator.moveNext();
      expect(iterator.current, 0);
      await expenses.update(expense.record.id, _draft('2026-10-31', 4000));
      await iterator.moveNext();
      expect(iterator.current, 4000);
      await expenses.softDelete(expense.record.id);
      await iterator.moveNext();
      expect(iterator.current, 0);
    },
  );

  test(
    'recent queries limit records before photos join and ignore deletions',
    () async {
      for (var i = 1; i <= 8; i++) {
        await database
            .into(database.records)
            .insert(
              RecordsCompanion.insert(
                id: 'photo-$i',
                type: 'PHOTO',
                eventDate: '2026-10-${i.toString().padLeft(2, '0')}',
                createdAt: i,
                updatedAt: i,
              ),
            );
        for (var j = 0; j < 3; j++) {
          await database
              .into(database.photos)
              .insert(
                PhotosCompanion.insert(
                  id: 'photo-$i-$j',
                  recordId: 'photo-$i',
                  filePath: 'photos/$i-$j.jpg',
                  sortOrder: j,
                ),
              );
        }
      }
      await (database.update(database.records)
            ..where((r) => r.id.equals('photo-8')))
          .write(const RecordsCompanion(deletedAt: Value(9)));
      await database
          .into(database.records)
          .insert(
            RecordsCompanion.insert(
              id: 'memo',
              type: 'MEMO',
              title: const Value('Latest memo'),
              eventDate: '2026-10-09',
              createdAt: 10,
              updatedAt: 10,
            ),
          );
      final recent = await home.watchRecentRecords().first;
      expect(recent.map((e) => e.record.id), [
        'memo',
        'photo-7',
        'photo-6',
        'photo-5',
        'photo-4',
      ]);
      expect(recent[1].photos.map((p) => p.sortOrder), [0, 1, 2]);
      final photos = await home.watchRecentPhotos().first;
      expect(photos.map((e) => e.record.id), [
        'photo-7',
        'photo-6',
        'photo-5',
        'photo-4',
        'photo-3',
        'photo-2',
      ]);
      expect(photos.every((e) => e.photos.length == 3), isTrue);
    },
  );

  test('recent photo stream follows attachment and record changes', () async {
    final iterator = StreamIterator(home.watchRecentPhotos());
    addTearDown(iterator.cancel);
    await iterator.moveNext();
    expect(iterator.current, isEmpty);
    await database.transaction(() async {
      await database
          .into(database.records)
          .insert(
            RecordsCompanion.insert(
              id: 'photo',
              type: 'PHOTO',
              eventDate: '2026-10-05',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      for (var i = 0; i < 2; i++) {
        await database
            .into(database.photos)
            .insert(
              PhotosCompanion.insert(
                id: 'p$i',
                recordId: 'photo',
                filePath: 'photos/p$i.jpg',
                sortOrder: i,
              ),
            );
      }
    });
    await iterator.moveNext();
    expect(iterator.current.single.photos.first.id, 'p0');
    await (database.delete(
      database.photos,
    )..where((p) => p.id.equals('p0'))).go();
    await iterator.moveNext();
    expect(iterator.current.single.photos.first.id, 'p1');
    await (database.update(database.records)
          ..where((r) => r.id.equals('photo')))
        .write(const RecordsCompanion(title: Value('Updated')));
    await iterator.moveNext();
    expect(iterator.current.single.record.title, 'Updated');
    await (database.update(database.records)
          ..where((r) => r.id.equals('photo')))
        .write(const RecordsCompanion(deletedAt: Value(2)));
    await iterator.moveNext();
    expect(iterator.current, isEmpty);
  });
}

ExpenseDraft _draft(String date, int amount) => ExpenseDraft(
  amount: amount,
  category: ExpenseCategory.food,
  paymentMethod: PaymentMethod.card,
  eventDate: LocalDate.parse(date),
);
