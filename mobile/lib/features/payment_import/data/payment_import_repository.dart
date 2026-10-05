import 'package:drift/drift.dart';
import 'package:my_life/core/database/app_database.dart';
import 'package:my_life/features/expense/data/expense_repository.dart';
import 'package:my_life/features/expense/domain/expense_record.dart';
import 'package:my_life/features/payment_import/domain/payment_message.dart';
import 'package:uuid/uuid.dart';

class PaymentImportRepository {
  PaymentImportRepository(this._database);
  final AppDatabase _database;
  static const parser = PaymentMessageParser();

  Stream<List<PaymentImportRow>> watchPending() =>
      (_database.select(_database.paymentImports)
            ..where((r) => r.recordId.isNull() & r.dismissedAt.isNull())
            ..orderBy([(r) => OrderingTerm.desc(r.receivedAt)]))
          .watch();

  Future<PaymentImportRow?> getPending(String id) =>
      (_database.select(_database.paymentImports)..where(
            (r) =>
                r.id.equals(id) & r.recordId.isNull() & r.dismissedAt.isNull(),
          ))
          .getSingleOrNull();

  Future<void> ingest(List<PaymentMessage> messages) async {
    await _database.transaction(() async {
      for (final message in messages) {
        if (message.text.length > 2000 ||
            message.externalId.isEmpty ||
            message.source.isEmpty) {
          continue;
        }
        if (parser.parse(message) == null) continue;
        await _database
            .into(_database.paymentImports)
            .insert(
              PaymentImportsCompanion.insert(
                id: const Uuid().v4(),
                source: message.source,
                externalId: message.externalId,
                rawText: message.text,
                receivedAt: message.receivedAt.toUtc().millisecondsSinceEpoch,
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
    });
  }

  Future<ExpenseRecord> save(String id, ExpenseDraft draft) =>
      _database.transaction(() async {
        if (await getPending(id) == null) {
          throw StateError('Import already processed');
        }
        final expense = await ExpenseRepository(_database).create(draft);
        await (_database.update(
          _database.paymentImports,
        )..where((r) => r.id.equals(id))).write(
          PaymentImportsCompanion(
            recordId: Value(expense.record.id),
            rawText: const Value(''),
          ),
        );
        return expense;
      });

  Future<void> dismiss(String id) async {
    await (_database.update(_database.paymentImports)..where(
          (r) => r.id.equals(id) & r.recordId.isNull() & r.dismissedAt.isNull(),
        ))
        .write(
          PaymentImportsCompanion(
            dismissedAt: Value(DateTime.now().toUtc().millisecondsSinceEpoch),
            rawText: const Value(''),
          ),
        );
  }
}
