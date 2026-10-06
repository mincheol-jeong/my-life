import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_life/core/database/app_database.dart';
import 'package:my_life/features/expense/application/expense_providers.dart';
import 'package:my_life/features/expense/data/expense_repository.dart';
import 'package:my_life/features/expense/domain/expense_record.dart';
import 'package:my_life/features/photo/application/photo_providers.dart';
import 'package:my_life/features/photo/data/photo_repository.dart';
import 'package:my_life/features/photo/data/photo_storage.dart';
import 'package:my_life/features/photo/domain/photo_record.dart';
import 'package:my_life/features/record/application/record_providers.dart';
import 'package:my_life/features/record/data/record_repository.dart';
import 'package:my_life/features/record/domain/life_record.dart';
import 'package:my_life/features/record/domain/local_date.dart';

LifeRecord record(RecordType type) => LifeRecord(
  id: 'record',
  type: type,
  eventDate: LocalDate(2026, 10, 5),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  title: 'Saved',
);

void main() {
  for (final disposeContainer in [false, true]) {
    for (final type in RecordType.values) {
      test(
        '$type save completes after ${disposeContainer ? "container disposal" : "screen listener closes"}',
        () async {
          final db = AppDatabase(NativeDatabase.memory());
          addTearDown(db.close);
          final memo = _DelayedMemo(db);
          final expense = _DelayedExpense(db);
          final photo = _DelayedPhoto(db);
          final container = ProviderContainer(
            overrides: [
              recordRepositoryProvider.overrideWithValue(memo),
              expenseRepositoryProvider.overrideWithValue(expense),
              photoRepositoryProvider.overrideWithValue(photo),
            ],
          );
          Future<Object?> saving;
          void Function() closeListener;
          void Function() complete;
          switch (type) {
            case RecordType.memo:
              final listener = container.listen(
                memoControllerProvider,
                (_, _) {},
              );
              closeListener = listener.close;
              saving = container
                  .read(memoControllerProvider.notifier)
                  .create(
                    MemoDraft(
                      title: 'Saved',
                      eventDate: LocalDate(2026, 10, 5),
                    ),
                  );
              complete = () => memo.pending.complete(record(type));
            case RecordType.expense:
              final listener = container.listen(
                expenseControllerProvider,
                (_, _) {},
              );
              closeListener = listener.close;
              saving = container
                  .read(expenseControllerProvider.notifier)
                  .create(
                    ExpenseDraft(
                      amount: 1000,
                      category: ExpenseCategory.other,
                      paymentMethod: PaymentMethod.card,
                      eventDate: LocalDate(2026, 10, 5),
                    ),
                  );
              complete = () => expense.pending.complete(
                ExpenseRecord(
                  id: 'expense',
                  record: record(type),
                  amount: 1000,
                  category: ExpenseCategory.other,
                  paymentMethod: PaymentMethod.card,
                ),
              );
            case RecordType.photo:
              final listener = container.listen(
                photoControllerProvider,
                (_, _) {},
              );
              closeListener = listener.close;
              saving = container.read(photoControllerProvider.notifier).create(
                PhotoDraft(eventDate: LocalDate(2026, 10, 5)),
                ['source'],
              );
              complete = () => photo.pending.complete(
                PhotoRecord(
                  record: record(type),
                  photos: const [
                    StoredPhoto(
                      id: 'photo',
                      recordId: 'record',
                      filePath: 'file',
                      sortOrder: 0,
                    ),
                  ],
                ),
              );
          }
          closeListener();
          if (disposeContainer) {
            container.dispose();
          } else {
            await container.pump();
          }
          complete();
          expect(await saving, isNotNull);
          if (!disposeContainer) {
            await container.pump();
            container.dispose();
          }
        },
      );
    }
  }
}

class _DelayedMemo extends RecordRepository {
  _DelayedMemo(super.database);
  final pending = Completer<LifeRecord>();
  @override
  Future<LifeRecord> createMemo(MemoDraft draft) => pending.future;
}

class _DelayedExpense extends ExpenseRepository {
  _DelayedExpense(super.database);
  final pending = Completer<ExpenseRecord>();
  @override
  Future<ExpenseRecord> create(ExpenseDraft draft) => pending.future;
}

class _DelayedPhoto extends PhotoRepository {
  _DelayedPhoto(AppDatabase database) : super(database, PhotoStorage());
  final pending = Completer<PhotoRecord>();
  @override
  Future<PhotoRecord> create(PhotoDraft draft, List<String> sourcePaths) =>
      pending.future;
}
