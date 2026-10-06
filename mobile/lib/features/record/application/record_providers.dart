import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_life/core/database/app_database_provider.dart';
import 'package:my_life/features/record/data/record_repository.dart';
import 'package:my_life/features/record/domain/life_record.dart';

final recordRepositoryProvider = Provider<RecordRepository>((ref) {
  return RecordRepository(ref.watch(appDatabaseProvider));
});

final recordDetailProvider = StreamProvider.autoDispose
    .family<LifeRecord?, String>(
      (ref, id) => ref.watch(recordRepositoryProvider).watchById(id),
    );

final memoControllerProvider =
    AsyncNotifierProvider.autoDispose<MemoController, void>(MemoController.new);

class MemoController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<LifeRecord?> create(MemoDraft draft) async {
    return _perform(() => ref.read(recordRepositoryProvider).createMemo(draft));
  }

  Future<LifeRecord?> saveEdit(String id, MemoDraft draft) async {
    return _perform(
      () => ref.read(recordRepositoryProvider).updateMemo(id, draft),
    );
  }

  Future<bool> delete(String id) async {
    if (state.isLoading) return false;
    final keepAlive = ref.keepAlive();
    state = const AsyncLoading();
    try {
      final result = await AsyncValue.guard(
        () => ref.read(recordRepositoryProvider).softDelete(id),
      );
      if (ref.mounted) state = result;
      return !result.hasError;
    } finally {
      keepAlive.close();
    }
  }

  Future<LifeRecord?> _perform(Future<LifeRecord> Function() operation) async {
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
