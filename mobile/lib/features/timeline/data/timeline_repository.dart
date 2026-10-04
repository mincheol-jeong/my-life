import 'package:drift/drift.dart';
import 'package:my_life/core/database/app_database.dart';
import 'package:my_life/features/expense/domain/expense_record.dart';
import 'package:my_life/features/photo/domain/photo_record.dart';
import 'package:my_life/features/record/data/record_row_mapper.dart';
import 'package:my_life/features/timeline/domain/timeline_entry.dart';

class TimelineRepository {
  const TimelineRepository(this._database);

  final AppDatabase _database;

  Stream<List<TimelineEntry>> watchEntries(TimelineFilter filter) {
    final query = _database.select(_database.records).join([
      leftOuterJoin(
        _database.expenses,
        _database.expenses.recordId.equalsExp(_database.records.id),
      ),
      leftOuterJoin(
        _database.photos,
        _database.photos.recordId.equalsExp(_database.records.id),
      ),
    ]);

    var condition = _database.records.deletedAt.isNull();
    if (filter.type != null) {
      condition =
          condition & _database.records.type.equals(filter.type!.databaseValue);
    }
    if (filter.startDate != null) {
      condition =
          condition &
          _database.records.eventDate.isBiggerOrEqualValue(
            filter.startDate!.toIso8601String(),
          );
    }
    if (filter.endDate != null) {
      condition =
          condition &
          _database.records.eventDate.isSmallerOrEqualValue(
            filter.endDate!.toIso8601String(),
          );
    }

    query
      ..where(condition)
      ..orderBy([
        OrderingTerm.desc(_database.records.eventDate),
        OrderingTerm.desc(_database.records.eventTimeMinutes),
        OrderingTerm.desc(_database.records.createdAt),
        OrderingTerm.desc(_database.records.id),
        OrderingTerm.asc(_database.photos.sortOrder),
      ]);

    return query.watch().map(_mapRows);
  }

  List<TimelineEntry> _mapRows(List<TypedResult> rows) {
    final grouped = <String, List<TypedResult>>{};
    for (final row in rows) {
      final recordId = row.readTable(_database.records).id;
      grouped.putIfAbsent(recordId, () => []).add(row);
    }

    return grouped.values
        .map((recordRows) {
          final record = recordRows.first
              .readTable(_database.records)
              .toDomain();
          final expense = recordRows.first.readTableOrNull(_database.expenses);
          final photos = recordRows
              .map((row) => row.readTableOrNull(_database.photos))
              .whereType<PhotoRow>()
              .map(
                (photo) => StoredPhoto(
                  id: photo.id,
                  recordId: photo.recordId,
                  filePath: photo.filePath,
                  thumbnailPath: photo.thumbnailPath,
                  width: photo.width,
                  height: photo.height,
                  sortOrder: photo.sortOrder,
                ),
              )
              .toList(growable: false);

          return TimelineEntry(
            record: record,
            expenseAmount: expense?.amount,
            expenseCategory: expense == null
                ? null
                : ExpenseCategory.fromDatabase(expense.category),
            expenseMemo: expense?.memo,
            photos: photos,
          );
        })
        .toList(growable: false);
  }
}
