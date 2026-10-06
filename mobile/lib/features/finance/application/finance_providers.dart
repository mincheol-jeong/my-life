import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_life/core/database/app_database_provider.dart';
import 'package:my_life/features/finance/data/finance_repository.dart';
import 'package:my_life/features/finance/domain/finance_summary.dart';
import 'package:my_life/features/record/domain/local_date.dart';
import 'package:my_life/features/record/application/local_date_provider.dart';

// Null follows the current month; browsing explicitly selects a fixed month.
final financeSelectionProvider =
    NotifierProvider.autoDispose<FinanceSelection, LocalDate?>(
      FinanceSelection.new,
    );

class FinanceSelection extends Notifier<LocalDate?> {
  @override
  LocalDate? build() => null;

  void move(int offset) {
    final today = ref.read(todayProvider);
    final month = state ?? LocalDate(today.year, today.month, 1);
    final next = DateTime.utc(month.year, month.month + offset, 1);
    if (next.year < 1 || next.year > 9999) return;
    state = LocalDate.fromDateTime(next);
  }

  void currentMonth() => state = null;
}

final financeMonthProvider = Provider.autoDispose<LocalDate>((ref) {
  final selected = ref.watch(financeSelectionProvider);
  final today = ref.watch(todayProvider);
  return selected ?? LocalDate(today.year, today.month, 1);
});

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository(ref.watch(appDatabaseProvider));
});

final financeSummaryProvider = StreamProvider.autoDispose<FinanceSummary>((
  ref,
) {
  return ref
      .watch(financeRepositoryProvider)
      .watchMonth(ref.watch(financeMonthProvider));
});
