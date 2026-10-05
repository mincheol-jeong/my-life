import 'package:drift/drift.dart';
import 'package:my_life/core/database/app_database.dart';
import 'package:my_life/features/record/domain/life_record.dart';
import 'package:my_life/features/record/domain/local_date.dart';
import 'package:my_life/features/timeline/data/timeline_repository.dart';
import 'package:my_life/features/timeline/domain/timeline_entry.dart';

class HomeRepository {
  HomeRepository(this._database) : _timeline = TimelineRepository(_database);

  final AppDatabase _database;
  final TimelineRepository _timeline;

  Stream<List<TimelineEntry>> watchRecentRecords() =>
      _timeline.watchEntries(const TimelineFilter(), limit: 5);

  Stream<List<TimelineEntry>> watchRecentPhotos() => _timeline.watchEntries(
    const TimelineFilter(type: RecordType.photo),
    limit: 6,
  );

  Stream<int> watchMonthlyExpense(LocalDate today) {
    final start = LocalDate(today.year, today.month, 1).toIso8601String();
    final next = DateTime.utc(today.year, today.month + 1, 1);
    final end = LocalDate.fromDateTime(next).toIso8601String();
    final total = _database.expenses.amount.sum();
    final query = _database.selectOnly(_database.expenses)
      ..addColumns([total])
      ..join([
        innerJoin(
          _database.records,
          _database.records.id.equalsExp(_database.expenses.recordId),
        ),
      ])
      ..where(
        _database.records.deletedAt.isNull() &
            _database.records.type.equals(RecordType.expense.databaseValue) &
            _database.records.eventDate.isBiggerOrEqualValue(start) &
            _database.records.eventDate.isSmallerThanValue(end),
      );
    return query.watchSingle().map((row) => row.read(total) ?? 0);
  }
}
