import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_life/core/localization/app_strings.dart';
import 'package:my_life/features/expense/application/expense_providers.dart';
import 'package:my_life/features/expense/domain/expense_record.dart';

class ExpenseDetailScreen extends ConsumerWidget {
  const ExpenseDetailScreen({required this.recordId, super.key});

  final String recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(expenseDetailProvider(recordId))
        .when(
          data: (expense) => expense == null
              ? _MissingDetail(onClose: () => context.go('/'))
              : _ExpenseDetail(expense: expense),
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, _) => Scaffold(
            appBar: AppBar(title: Text(context.strings.get('expense'))),
            body: Center(child: Text(context.strings.get('loadError'))),
          ),
        );
  }
}

class _ExpenseDetail extends ConsumerWidget {
  const _ExpenseDetail({required this.expense});

  final ExpenseRecord expense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.strings.get('expense')),
        actions: [
          IconButton(
            key: const Key('edit-expense-button'),
            tooltip: context.strings.get('edit'),
            onPressed: () =>
                context.push('/expenses/${expense.record.id}/edit'),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            key: const Key('delete-expense-button'),
            tooltip: context.strings.get('delete'),
            onPressed: () => _confirmDelete(context, ref),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          children: [
            Text(
              expense.displayLabelFor(
                context.strings.expenseCategory(expense.category),
              ),
              key: const Key('expense-detail-title'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              '₩${_formatAmount(expense.amount)}',
              key: const Key('expense-detail-amount'),
              style: Theme.of(context).textTheme.displaySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 28),
            _DetailRow(
              label: context.strings.get('category'),
              value: context.strings.expenseCategory(expense.category),
            ),
            _DetailRow(
              label: context.strings.get('paymentMethod'),
              value: context.strings.paymentMethod(expense.paymentMethod),
            ),
            _DetailRow(
              label: context.strings.get('date'),
              value: _metadata(expense),
            ),
            if (expense.memo != null) ...[
              const SizedBox(height: 24),
              Text(
                context.strings.get('memo'),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              SelectableText(
                expense.memo!,
                key: const Key('expense-detail-memo'),
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(height: 1.6),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.strings.get('expenseDeleteTitle')),
        content: Text(context.strings.get('expenseDeleteBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.strings.get('cancel')),
          ),
          FilledButton(
            key: const Key('confirm-delete-expense-button'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.strings.get('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final deleted = await ref
        .read(expenseControllerProvider.notifier)
        .delete(expense.record.id);
    if (!context.mounted) return;
    if (deleted) {
      context.go('/');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.get('expenseDeleteError'))),
      );
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _MissingDetail extends StatelessWidget {
  const _MissingDetail({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.strings.get('expense'))),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.strings.get('notFound')),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onClose,
            child: Text(context.strings.get('goHome')),
          ),
        ],
      ),
    ),
  );
}

String _formatAmount(int amount) {
  final digits = amount.toString();
  final result = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) result.write(',');
    result.write(digits[index]);
  }
  return result.toString();
}

String _metadata(ExpenseRecord expense) {
  final date = expense.record.eventDate;
  final buffer = StringBuffer(
    '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}',
  );
  final minutes = expense.record.eventTimeMinutes;
  if (minutes != null) {
    buffer.write(
      '  ${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}',
    );
  }
  return buffer.toString();
}
