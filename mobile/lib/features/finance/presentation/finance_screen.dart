import 'package:my_life/shared/formatting/display_formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_life/core/localization/app_strings.dart';
import 'package:my_life/features/finance/application/finance_providers.dart';
import 'package:my_life/features/finance/domain/finance_summary.dart';
import 'package:my_life/features/record/domain/local_date.dart';

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final month = ref.watch(financeMonthProvider);
    final selection = ref.read(financeSelectionProvider.notifier);
    final summary = ref.watch(financeSummaryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(strings.get('finance'))),
      body: SafeArea(
        child: ListView(
          key: const Key('finance-list'),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            Row(
              children: [
                IconButton(
                  key: const Key('finance-previous-month'),
                  tooltip: strings.get('previousMonth'),
                  onPressed: month.year == 1 && month.month == 1
                      ? null
                      : () => selection.move(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    MaterialLocalizations.of(context)
                        .formatMonthYear(month.toDateTime()),
                    key: const Key('finance-month'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  key: const Key('finance-next-month'),
                  tooltip: strings.get('nextMonth'),
                  onPressed: month.year == 9999 && month.month == 12
                      ? null
                      : () => selection.move(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                key: const Key('finance-current-month'),
                onPressed: selection.currentMonth,
                child: Text(strings.get('currentMonth')),
              ),
            ),
            const SizedBox(height: 24),
            summary.when(
              skipLoadingOnReload: false,
              skipLoadingOnRefresh: false,
              loading: () => const Center(
                child: CircularProgressIndicator(key: Key('finance-loading')),
              ),
              error: (_, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(strings.get('financeLoadError')),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: const Key('finance-retry'),
                    onPressed: () => ref.invalidate(financeSummaryProvider),
                    child: Text(strings.get('retry')),
                  ),
                ],
              ),
              data: (value) => _Summary(summary: value),
            ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.summary});
  final FinanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.get('financeTotal'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Text(
          formatWon(summary.total),
          key: const Key('finance-total'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        if (summary.days.isEmpty) ...[
          const SizedBox(height: 12),
          Text(strings.get('financeEmpty')),
        ] else ...[
          const SizedBox(height: 28),
          Text(
            strings.get('financeCategories'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          for (final entry in summary.categories)
            _AmountRow(
              key: Key('finance-category-${entry.category.name}'),
              label: strings.expenseCategory(entry.category),
              amount: entry.amount,
            ),
          const SizedBox(height: 28),
          Text(
            strings.get('financeDays'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          for (final entry in summary.days)
            _AmountRow(
              key: Key('finance-day-${entry.date.toIso8601String()}'),
              label: _date(entry.date),
              amount: entry.amount,
            ),
        ],
      ],
    );
  }

  String _date(LocalDate date) =>
      '${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({super.key, required this.label, required this.amount});
  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 16,
        runSpacing: 4,
        children: [Text(label), Text(formatWon(amount))],
      ),
    ),
  );
}
