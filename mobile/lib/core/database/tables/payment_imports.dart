import 'package:drift/drift.dart';
import 'package:my_life/core/database/tables/records.dart';

@DataClassName('PaymentImportRow')
class PaymentImports extends Table {
  TextColumn get id => text()();
  TextColumn get source => text()();
  TextColumn get externalId => text()();
  TextColumn get rawText => text()();
  IntColumn get receivedAt => integer()();
  TextColumn get recordId => text().nullable().references(Records, #id)();
  IntColumn get dismissedAt => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {source, externalId},
  ];
}
