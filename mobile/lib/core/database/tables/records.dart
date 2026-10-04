import 'package:drift/drift.dart';

@DataClassName('RecordRow')
@TableIndex.sql(
  'CREATE INDEX records_active_timeline_idx '
  'ON records (event_date DESC, event_time_minutes DESC, created_at DESC) '
  'WHERE deleted_at IS NULL',
)
@TableIndex.sql(
  'CREATE INDEX records_active_type_idx '
  'ON records (type, event_date DESC, event_time_minutes DESC) '
  'WHERE deleted_at IS NULL',
)
class Records extends Table {
  TextColumn get id => text()();

  TextColumn get type => text().customConstraint(
    "NOT NULL CHECK (type IN ('MEMO', 'EXPENSE', 'PHOTO'))",
  )();

  TextColumn get title => text().nullable()();

  TextColumn get content => text().nullable()();

  TextColumn get eventDate => text()();

  IntColumn get eventTimeMinutes => integer().nullable().customConstraint(
    'CHECK (event_time_minutes IS NULL OR '
    'event_time_minutes BETWEEN 0 AND 1439)',
  )();

  TextColumn get placeName => text().nullable()();

  IntColumn get createdAt => integer()();

  IntColumn get updatedAt => integer()();

  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
