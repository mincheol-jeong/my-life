import 'package:drift/drift.dart';
import 'package:my_life/core/database/app_database.dart';
import 'package:my_life/features/expense/domain/expense_record.dart';
import 'package:my_life/features/record/data/record_repository.dart';
import 'package:my_life/features/record/data/record_row_mapper.dart';
import 'package:my_life/features/record/domain/life_record.dart';
import 'package:uuid/uuid.dart';

class ExpenseRepository {
  ExpenseRepository(this._database, {UtcClock? clock, IdGenerator? idGenerator})
    : _clock = clock ?? (() => DateTime.now().toUtc()),
      _idGenerator = idGenerator ?? const Uuid().v4;

  final AppDatabase _database;
  final UtcClock _clock;
  final IdGenerator _idGenerator;

  Future<ExpenseRecord> create(ExpenseDraft draft) async {
    final normalized = _normalizeAndValidate(draft);
    final recordId = _idGenerator();
    final expenseId = _idGenerator();
    final now = _clock().toUtc().millisecondsSinceEpoch;

    await _database.transaction(() async {
      await _database
          .into(_database.records)
          .insert(
            RecordsCompanion.insert(
              id: recordId,
              type: RecordType.expense.databaseValue,
              title: Value(normalized.title),
              content: const Value(null),
              eventDate: normalized.eventDate.toIso8601String(),
              eventTimeMinutes: Value(normalized.eventTimeMinutes),
              placeName: const Value(null),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _database
          .into(_database.expenses)
          .insert(
            ExpensesCompanion.insert(
              id: expenseId,
              recordId: recordId,
              amount: normalized.amount,
              category: normalized.category.databaseValue,
              paymentMethod: normalized.paymentMethod.databaseValue,
              memo: Value(normalized.memo),
            ),
          );
    });

    return (await getById(recordId))!;
  }

  Future<ExpenseRecord?> getById(String recordId) async {
    return (await _activeExpenseQuery(
      recordId,
    ).getSingleOrNull())?.toDomain(_database);
  }

  Stream<ExpenseRecord?> watchById(String recordId) {
    return _activeExpenseQuery(recordId)
        .watchSingleOrNull()
        .map((row) => row?.toDomain(_database));
  }

  Future<ExpenseRecord> update(String recordId, ExpenseDraft draft) async {
    final normalized = _normalizeAndValidate(draft);
    final updatedAt = _clock().toUtc().millisecondsSinceEpoch;

    await _database.transaction(() async {
      final existing = await getById(recordId);
      if (existing == null) throw RecordNotFoundException(recordId);

      final recordCount =
          await (_database.update(_database.records)..where(
                (record) =>
                    record.id.equals(recordId) &
                    record.type.equals(RecordType.expense.databaseValue) &
                    record.deletedAt.isNull(),
              ))
              .write(
                RecordsCompanion(
                  title: Value(normalized.title),
                  eventDate: Value(normalized.eventDate.toIso8601String()),
                  eventTimeMinutes: Value(normalized.eventTimeMinutes),
                  updatedAt: Value(updatedAt),
                ),
              );
      final expenseCount =
          await (_database.update(
            _database.expenses,
          )..where((expense) => expense.recordId.equals(recordId))).write(
            ExpensesCompanion(
              amount: Value(normalized.amount),
              category: Value(normalized.category.databaseValue),
              paymentMethod: Value(normalized.paymentMethod.databaseValue),
              memo: Value(normalized.memo),
            ),
          );
      if (recordCount != 1 || expenseCount != 1) {
        throw RecordNotFoundException(recordId);
      }
    });

    return (await getById(recordId))!;
  }

  Future<void> softDelete(String recordId) async {
    final deletedAt = _clock().toUtc().millisecondsSinceEpoch;
    final affected =
        await (_database.update(_database.records)..where(
              (record) =>
                  record.id.equals(recordId) &
                  record.type.equals(RecordType.expense.databaseValue) &
                  record.deletedAt.isNull(),
            ))
            .write(
              RecordsCompanion(
                updatedAt: Value(deletedAt),
                deletedAt: Value(deletedAt),
              ),
            );
    if (affected != 1) throw RecordNotFoundException(recordId);
  }

  Selectable<TypedResult> _activeExpenseQuery(String recordId) {
    return (_database.select(_database.records).join([
      innerJoin(
        _database.expenses,
        _database.expenses.recordId.equalsExp(_database.records.id),
      ),
    ])..where(
      _database.records.id.equals(recordId) &
          _database.records.type.equals(RecordType.expense.databaseValue) &
          _database.records.deletedAt.isNull(),
    ));
  }

  ExpenseDraft _normalizeAndValidate(ExpenseDraft draft) {
    if (draft.amount <= 0) {
      throw const ExpenseValidationException('0원보다 큰 금액을 입력해주세요.');
    }
    final minutes = draft.eventTimeMinutes;
    if (minutes != null && (minutes < 0 || minutes > 1439)) {
      throw const ExpenseValidationException('시간 값이 올바르지 않습니다.');
    }
    return ExpenseDraft(
      amount: draft.amount,
      category: draft.category,
      paymentMethod: draft.paymentMethod,
      memo: _nullableTrim(draft.memo),
      title: _nullableTrim(draft.title),
      eventDate: draft.eventDate,
      eventTimeMinutes: minutes,
    );
  }

  String? _nullableTrim(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

extension on TypedResult {
  ExpenseRecord toDomain(AppDatabase database) {
    final record = readTable(database.records);
    final expense = readTable(database.expenses);
    return ExpenseRecord(
      id: expense.id,
      record: record.toDomain(),
      amount: expense.amount,
      category: ExpenseCategory.fromDatabase(expense.category),
      paymentMethod: PaymentMethod.fromDatabase(expense.paymentMethod),
      memo: expense.memo,
    );
  }
}
