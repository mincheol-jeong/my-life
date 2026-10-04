import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_life/core/database/app_database.dart';
import 'package:my_life/features/record/domain/life_record.dart';
import 'package:my_life/features/record/domain/local_date.dart';
import 'package:my_life/features/timeline/data/timeline_repository.dart';
import 'package:my_life/features/timeline/domain/timeline_entry.dart';

void main() {
  late AppDatabase database;
  late TimelineRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = TimelineRepository(database);
  });

  tearDown(() => database.close());

  test('returns active records in date, time, and created order', () async {
    await _insertRecord(
      database,
      id: 'untimed',
      type: RecordType.memo,
      date: '2026-09-30',
      createdAt: 300,
      content: 'Untimed memo',
    );
    await _insertRecord(
      database,
      id: 'expense',
      type: RecordType.expense,
      date: '2026-09-30',
      time: 600,
      createdAt: 200,
      title: 'Lunch',
    );
    await database
        .into(database.expenses)
        .insert(
          ExpensesCompanion.insert(
            id: 'expense-row',
            recordId: 'expense',
            amount: 12000,
            category: 'FOOD',
            paymentMethod: 'CARD',
          ),
        );
    await _insertRecord(
      database,
      id: 'photo',
      type: RecordType.photo,
      date: '2026-09-30',
      time: 1200,
      createdAt: 100,
    );
    await database
        .into(database.photos)
        .insert(
          PhotosCompanion.insert(
            id: 'photo-1',
            recordId: 'photo',
            filePath: 'photos/photo/original.jpg',
            sortOrder: 0,
          ),
        );
    await _insertRecord(
      database,
      id: 'older',
      type: RecordType.memo,
      date: '2026-09-29',
      createdAt: 400,
      title: 'Older',
    );
    await _insertRecord(
      database,
      id: 'deleted',
      type: RecordType.memo,
      date: '2026-10-01',
      createdAt: 500,
      title: 'Deleted',
      deletedAt: 501,
    );

    final entries = await repository.watchEntries(const TimelineFilter()).first;

    expect(entries.map((entry) => entry.record.id), [
      'photo',
      'expense',
      'untimed',
      'older',
    ]);
    expect(entries.first.photos.single.id, 'photo-1');
    expect(entries[1].expenseAmount, 12000);
    expect(entries[1].expenseCategory?.databaseValue, 'FOOD');
  });

  test('applies type and inclusive local date filters', () async {
    await _insertRecord(
      database,
      id: 'memo-start',
      type: RecordType.memo,
      date: '2026-09-01',
      createdAt: 1,
      title: 'Start',
    );
    await _insertRecord(
      database,
      id: 'photo-middle',
      type: RecordType.photo,
      date: '2026-09-15',
      createdAt: 2,
    );
    await database
        .into(database.photos)
        .insert(
          PhotosCompanion.insert(
            id: 'photo-middle-row',
            recordId: 'photo-middle',
            filePath: 'photos/photo-middle/original.jpg',
            sortOrder: 0,
          ),
        );
    await _insertRecord(
      database,
      id: 'memo-end',
      type: RecordType.memo,
      date: '2026-09-30',
      createdAt: 3,
      title: 'End',
    );

    final entries = await repository
        .watchEntries(
          TimelineFilter(
            type: RecordType.memo,
            startDate: LocalDate(2026, 9, 1),
            endDate: LocalDate(2026, 9, 30),
          ),
        )
        .first;

    expect(entries.map((entry) => entry.record.id), ['memo-end', 'memo-start']);
  });

  test('watch stream updates after a record is inserted', () async {
    final iterator = StreamIterator(
      repository.watchEntries(const TimelineFilter()),
    );
    addTearDown(iterator.cancel);

    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current, isEmpty);

    await _insertRecord(
      database,
      id: 'new-memo',
      type: RecordType.memo,
      date: '2026-09-30',
      createdAt: 1,
      title: 'New memo',
    );

    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current.single.record.id, 'new-memo');
  });
}

Future<void> _insertRecord(
  AppDatabase database, {
  required String id,
  required RecordType type,
  required String date,
  required int createdAt,
  String? title,
  String? content,
  int? time,
  int? deletedAt,
}) {
  return database
      .into(database.records)
      .insert(
        RecordsCompanion.insert(
          id: id,
          type: type.databaseValue,
          title: Value(title),
          content: Value(content),
          eventDate: date,
          eventTimeMinutes: Value(time),
          placeName: const Value(null),
          createdAt: createdAt,
          updatedAt: createdAt,
          deletedAt: Value(deletedAt),
        ),
      );
}
