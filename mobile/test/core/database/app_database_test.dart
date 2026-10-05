import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_life/core/database/app_database.dart';
import 'package:my_life/features/expense/data/expense_repository.dart';
import 'package:my_life/features/expense/domain/expense_record.dart';
import 'package:my_life/features/record/data/record_repository.dart';
import 'package:my_life/features/record/domain/life_record.dart';
import 'package:my_life/features/record/domain/local_date.dart';

void main() {
  test(
    'upgrades a version 5 database preserving calendar links and records',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'my_life_upgrade_',
      );
      final file = File('${directory.path}/upgrade.sqlite');
      AppDatabase? database;
      try {
        database = AppDatabase(NativeDatabase(file));
        await database.customStatement(
          "INSERT INTO records (id, type, title, event_date, created_at, updated_at) VALUES ('memo', 'MEMO', 'Keep me', '2026-10-05', 1, 1)",
        );
        await database.customStatement(
          "INSERT INTO calendar_imports (record_id, calendar_id, external_instance_id, imported_at) VALUES ('memo', 'calendar', 'event', 1)",
        );
        await database.close();
        database = AppDatabase(
          NativeDatabase(
            file,
            setup: (raw) {
              raw.execute('DROP TABLE payment_imports');
              raw.execute(
                'ALTER TABLE calendar_imports DROP COLUMN source_snapshot',
              );
              raw.execute('PRAGMA user_version = 5');
            },
          ),
        );
        expect(
          (await database.select(database.records).get()).single.title,
          'Keep me',
        );
        expect(
          (await database.select(database.calendarImports).get())
              .single
              .sourceSnapshot,
          isNull,
        );
        expect(await database.select(database.paymentImports).get(), isEmpty);
        expect(
          await database.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        await database?.close();
        await directory.delete(recursive: true);
      }
    },
  );
  test('opens the database and enables foreign keys', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final row = await database.customSelect('PRAGMA foreign_keys').getSingle();

    expect(row.read<int>('foreign_keys'), 1);
    expect(database.schemaVersion, 6);
  });

  test('migrates a version 1 database through the current schema', () async {
    final database = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDatabase) {
          rawDatabase.execute('PRAGMA user_version = 1');
        },
      ),
    );
    addTearDown(database.close);

    final tables = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'records'",
        )
        .get();
    final indexes = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' AND name LIKE 'records_active_%'",
        )
        .get();

    expect(tables, hasLength(1));
    expect(
      indexes.map((row) => row.read<String>('name')),
      containsAll(['records_active_timeline_idx', 'records_active_type_idx']),
    );
    final expenseTable = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'expenses'",
        )
        .get();
    expect(expenseTable, hasLength(1));
    final photoTable = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'photos'",
        )
        .get();
    expect(photoTable, hasLength(1));
    final calendarImportTable = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'calendar_imports'",
        )
        .get();
    expect(calendarImportTable, hasLength(1));
  });

  test('migrates a version 2 database by creating expenses', () async {
    final database = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDatabase) {
          rawDatabase.execute('''
            CREATE TABLE records (
              id TEXT NOT NULL PRIMARY KEY,
              type TEXT NOT NULL CHECK (type IN ('MEMO', 'EXPENSE', 'PHOTO')),
              title TEXT,
              content TEXT,
              event_date TEXT NOT NULL,
              event_time_minutes INTEGER CHECK (
                event_time_minutes IS NULL OR event_time_minutes BETWEEN 0 AND 1439
              ),
              place_name TEXT,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              deleted_at INTEGER
            )
          ''');
          rawDatabase.execute('PRAGMA user_version = 2');
        },
      ),
    );
    addTearDown(database.close);

    final tables = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'expenses'",
        )
        .get();
    final indexes = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' AND name = 'expenses_category_idx'",
        )
        .get();

    expect(tables, hasLength(1));
    expect(indexes, hasLength(1));
  });

  test('migrates a version 3 database by creating photos', () async {
    final database = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDatabase) {
          rawDatabase.execute('''
            CREATE TABLE records (
              id TEXT NOT NULL PRIMARY KEY,
              type TEXT NOT NULL,
              title TEXT,
              content TEXT,
              event_date TEXT NOT NULL,
              event_time_minutes INTEGER,
              place_name TEXT,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              deleted_at INTEGER
            )
          ''');
          rawDatabase.execute('''
            CREATE TABLE expenses (
              id TEXT NOT NULL PRIMARY KEY,
              record_id TEXT NOT NULL UNIQUE REFERENCES records(id) ON DELETE CASCADE,
              amount INTEGER NOT NULL,
              category TEXT NOT NULL,
              payment_method TEXT NOT NULL,
              memo TEXT
            )
          ''');
          rawDatabase.execute('PRAGMA user_version = 3');
        },
      ),
    );
    addTearDown(database.close);

    final tables = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'photos'",
        )
        .get();

    expect(tables, hasLength(1));
  });

  test('migrates a version 4 database by creating calendar imports', () async {
    final database = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDatabase) {
          rawDatabase.execute('''
            CREATE TABLE records (
              id TEXT NOT NULL PRIMARY KEY,
              type TEXT NOT NULL,
              title TEXT,
              content TEXT,
              event_date TEXT NOT NULL,
              event_time_minutes INTEGER,
              place_name TEXT,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              deleted_at INTEGER
            )
          ''');
          rawDatabase.execute('PRAGMA user_version = 4');
        },
      ),
    );
    addTearDown(database.close);

    final tables = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'calendar_imports'",
        )
        .get();

    expect(tables, hasLength(1));
  });

  test('persists a memo after the database is reopened', () async {
    final directory = await Directory.systemTemp.createTemp('my_life_test_');
    final file = File('${directory.path}/records.sqlite');
    AppDatabase? database;
    try {
      database = AppDatabase(NativeDatabase(file));
      final repository = RecordRepository(
        database,
        idGenerator: () => 'persistent-record',
      );
      await repository.createMemo(
        MemoDraft(
          content: '다시 열어도 남아 있는 메모',
          eventDate: LocalDate(2026, 9, 30),
        ),
      );
      await database.close();

      database = AppDatabase(NativeDatabase(file));
      final reopened = await RecordRepository(database)
          .getById('persistent-record');

      expect(reopened?.content, '다시 열어도 남아 있는 메모');
    } finally {
      await database?.close();
      await directory.delete(recursive: true);
    }
  });

  test('persists an expense after the database is reopened', () async {
    final directory = await Directory.systemTemp.createTemp('my_life_test_');
    final file = File('${directory.path}/expenses.sqlite');
    AppDatabase? database;
    try {
      final ids = ['persistent-record', 'persistent-expense'].iterator;
      database = AppDatabase(NativeDatabase(file));
      await ExpenseRepository(
        database,
        idGenerator: () {
          ids.moveNext();
          return ids.current;
        },
      ).create(
        ExpenseDraft(
          amount: 45000,
          category: ExpenseCategory.food,
          paymentMethod: PaymentMethod.card,
          memo: '저녁 식사',
          eventDate: LocalDate(2026, 9, 30),
        ),
      );
      await database.close();

      database = AppDatabase(NativeDatabase(file));
      final reopened = await ExpenseRepository(database)
          .getById('persistent-record');

      expect(reopened?.amount, 45000);
      expect(reopened?.memo, '저녁 식사');
    } finally {
      await database?.close();
      await directory.delete(recursive: true);
    }
  });
}
