import 'package:drift/drift.dart';
import 'package:my_life/core/database/tables/records.dart';

@DataClassName('CalendarImportRow')
class CalendarImports extends Table {
  TextColumn get recordId =>
      text().references(Records, #id, onDelete: KeyAction.cascade)();

  TextColumn get calendarId => text()();

  TextColumn get externalInstanceId => text()();

  IntColumn get importedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {recordId};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {calendarId, externalInstanceId},
  ];
}
