import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:my_life/core/database/tables/expenses.dart';
import 'package:my_life/core/database/tables/calendar_imports.dart';
import 'package:my_life/core/database/tables/photos.dart';
import 'package:my_life/core/database/tables/records.dart';
import 'package:my_life/core/database/tables/payment_imports.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Records, Expenses, Photos, CalendarImports, PaymentImports],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'my_life'));

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from > to) {
        throw StateError('Database downgrade is not supported: $from -> $to');
      }

      if (from < 2) {
        await migrator.createTable(records);
        await customStatement(
          'CREATE INDEX IF NOT EXISTS records_active_timeline_idx '
          'ON records (event_date DESC, event_time_minutes DESC, created_at DESC) '
          'WHERE deleted_at IS NULL',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS records_active_type_idx '
          'ON records (type, event_date DESC, event_time_minutes DESC) '
          'WHERE deleted_at IS NULL',
        );
      }

      if (from < 3) {
        await migrator.createTable(expenses);
        await customStatement(
          'CREATE INDEX IF NOT EXISTS expenses_category_idx '
          'ON expenses (category)',
        );
      }

      if (from < 4) {
        await migrator.createTable(photos);
      }

      if (from < 5) {
        await migrator.createTable(calendarImports);
      }
      if (from < 6) {
        await migrator.createTable(paymentImports);
        if (from >= 5) {
          await migrator.addColumn(
            calendarImports,
            calendarImports.sourceSnapshot,
          );
        }
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
