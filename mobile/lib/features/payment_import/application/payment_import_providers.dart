import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_life/core/database/app_database.dart';
import 'package:my_life/core/database/app_database_provider.dart';
import 'package:my_life/features/expense/domain/expense_record.dart';
import 'package:my_life/features/payment_import/data/payment_device_service.dart';
import 'package:my_life/features/payment_import/data/payment_import_repository.dart';
import 'package:my_life/features/payment_import/domain/payment_message.dart';

final paymentDeviceServiceProvider = Provider((ref) => PaymentDeviceService());
final paymentImportRepositoryProvider = Provider(
  (ref) => PaymentImportRepository(ref.watch(appDatabaseProvider)),
);
final paymentPendingProvider = StreamProvider(
  (ref) => ref.watch(paymentImportRepositoryProvider).watchPending(),
);
final paymentDeviceStateProvider = FutureProvider(
  (ref) => ref.watch(paymentDeviceServiceProvider).status(),
);
final paymentReviewProvider = FutureProvider.autoDispose
    .family<PaymentImportRow?, String>(
      (ref, id) => ref.watch(paymentImportRepositoryProvider).getPending(id),
    );
final paymentSuggestionProvider = Provider.autoDispose
    .family<ExpenseDraft?, PaymentImportRow>(
      (ref, row) => PaymentImportRepository.parser.parse(
        PaymentMessage(
          source: row.source,
          externalId: row.externalId,
          text: row.rawText,
          receivedAt: DateTime.fromMillisecondsSinceEpoch(
            row.receivedAt,
            isUtc: true,
          ),
        ),
      ),
    );
final paymentImportControllerProvider =
    AsyncNotifierProvider<PaymentImportController, void>(
      PaymentImportController.new,
    );

class PaymentImportController extends AsyncNotifier<void> {
  bool _collecting = false;
  @override
  void build() {}

  Future<void> collect() async {
    if (_collecting) return;
    _collecting = true;
    try {
      final service = ref.read(paymentDeviceServiceProvider);
      final messages = await service.pending();
      if (state.hasError) state = const AsyncData(null);
      if (messages.isEmpty) return;
      await ref.read(paymentImportRepositoryProvider).ingest(messages);
      await service.acknowledge(messages.map((m) => m.externalId).toList());
      ref.invalidate(paymentDeviceStateProvider);
    } catch (error, stack) {
      state = AsyncError(error, stack);
    } finally {
      _collecting = false;
    }
  }

  Future<ExpenseRecord?> save(String id, ExpenseDraft draft) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(paymentImportRepositoryProvider).save(id, draft),
    );
    state = result.whenData((_) {});
    return result.value;
  }

  Future<void> dismiss(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(paymentImportRepositoryProvider).dismiss(id),
    );
  }

  Future<void> configure(bool enabled, List<String> selected) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(paymentDeviceServiceProvider).configure(enabled, selected),
    );
    ref.invalidate(paymentDeviceStateProvider);
  }
}
