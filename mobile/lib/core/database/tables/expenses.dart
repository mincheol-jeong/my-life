import 'package:drift/drift.dart';
import 'package:my_life/core/database/tables/records.dart';

@DataClassName('ExpenseRow')
@TableIndex.sql('CREATE INDEX expenses_category_idx ON expenses (category)')
class Expenses extends Table {
  TextColumn get id => text()();

  TextColumn get recordId =>
      text().unique().references(Records, #id, onDelete: KeyAction.cascade)();

  IntColumn get amount =>
      integer().customConstraint('NOT NULL CHECK (amount > 0)')();

  TextColumn get category => text().customConstraint(
    "NOT NULL CHECK (category IN ('FOOD', 'TRANSPORT', 'SHOPPING', "
    "'ENTERTAINMENT', 'TRAVEL', 'HOUSING', 'SUBSCRIPTION', 'OTHER'))",
  )();

  TextColumn get paymentMethod => text().customConstraint(
    "NOT NULL CHECK (payment_method IN ('CASH', 'CARD', 'TRANSFER', 'OTHER'))",
  )();

  TextColumn get memo => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
