import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_life/core/database/app_database_provider.dart';
import 'package:my_life/features/expense/data/expense_repository.dart';
import 'package:my_life/features/expense/domain/expense_record.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref.watch(appDatabaseProvider));
});

final expenseDetailProvider = StreamProvider.autoDispose
    .family<ExpenseRecord?, String>(
      (ref, id) => ref.watch(expenseRepositoryProvider).watchById(id),
    );

final expenseControllerProvider =
    AsyncNotifierProvider.autoDispose<ExpenseController, void>(
      ExpenseController.new,
    );

class ExpenseController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<ExpenseRecord?> create(ExpenseDraft draft) {
    return _perform(() => ref.read(expenseRepositoryProvider).create(draft));
  }

  Future<ExpenseRecord?> saveEdit(String id, ExpenseDraft draft) {
    return _perform(
      () => ref.read(expenseRepositoryProvider).update(id, draft),
    );
  }

  Future<bool> delete(String id) async {
    if (state.isLoading) return false;
    final keepAlive = ref.keepAlive();
    state = const AsyncLoading();
    try {
      final result = await AsyncValue.guard(
        () => ref.read(expenseRepositoryProvider).softDelete(id),
      );
      if (ref.mounted) state = result;
      return !result.hasError;
    } finally {
      keepAlive.close();
    }
  }

  Future<ExpenseRecord?> _perform(
    Future<ExpenseRecord> Function() operation,
  ) async {
    if (state.isLoading) return null;
    final keepAlive = ref.keepAlive();
    state = const AsyncLoading();
    try {
      final result = await AsyncValue.guard(operation);
      if (ref.mounted) state = result.whenData((_) {});
      return result.value;
    } finally {
      keepAlive.close();
    }
  }
}
