import 'package:drift/drift.dart';
import 'package:my_life/core/database/tables/records.dart';

@DataClassName('PhotoRow')
class Photos extends Table {
  TextColumn get id => text()();

  TextColumn get recordId =>
      text().references(Records, #id, onDelete: KeyAction.cascade)();

  TextColumn get filePath => text()();

  TextColumn get thumbnailPath => text().nullable()();

  IntColumn get width => integer().nullable().customConstraint(
    'CHECK (width IS NULL OR width > 0)',
  )();

  IntColumn get height => integer().nullable().customConstraint(
    'CHECK (height IS NULL OR height > 0)',
  )();

  IntColumn get sortOrder =>
      integer().customConstraint('NOT NULL CHECK (sort_order >= 0)')();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {recordId, sortOrder},
  ];
}
