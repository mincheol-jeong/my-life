import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_life/core/localization/app_strings.dart';
import 'package:my_life/features/expense/application/expense_providers.dart';
import 'package:my_life/features/expense/domain/expense_record.dart';
import 'package:my_life/features/record/domain/local_date.dart';

class ExpenseFormScreen extends ConsumerWidget {
  const ExpenseFormScreen({this.recordId, super.key});

  final String? recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = recordId;
    if (id == null) return const _ExpenseEditor();

    return ref
        .watch(expenseDetailProvider(id))
        .when(
          data: (expense) => expense == null
              ? const _MissingExpenseScreen()
              : _ExpenseEditor(
                  key: ValueKey(expense.record.updatedAt),
                  expense: expense,
                ),
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, _) => const _LoadErrorScreen(),
        );
  }
}

class _ExpenseEditor extends ConsumerStatefulWidget {
  const _ExpenseEditor({this.expense, super.key});

  final ExpenseRecord? expense;

  @override
  ConsumerState<_ExpenseEditor> createState() => _ExpenseEditorState();
}

class _ExpenseEditorState extends ConsumerState<_ExpenseEditor> {
  late final TextEditingController _amountController;
  late final TextEditingController _memoController;
  late final TextEditingController _titleController;
  late ExpenseCategory _category;
  late PaymentMethod _paymentMethod;
  late LocalDate _date;
  int? _timeMinutes;
  String? _validationMessage;

  bool get _isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    _amountController = TextEditingController(
      text: expense?.amount.toString() ?? '',
    );
    _memoController = TextEditingController(text: expense?.memo);
    _titleController = TextEditingController(text: expense?.record.title);
    _category = expense?.category ?? ExpenseCategory.food;
    _paymentMethod = expense?.paymentMethod ?? PaymentMethod.card;
    _date = expense?.record.eventDate ?? LocalDate.fromDateTime(DateTime.now());
    _timeMinutes = expense?.record.eventTimeMinutes;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _memoController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(expenseControllerProvider).isLoading;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          key: const Key('expense-form-back-button'),
          onPressed: () => _closeForm(context),
        ),
        title: Text(
          context.strings.get(_isEditing ? 'expenseEdit' : 'expense'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            TextField(
              key: const Key('expense-amount-field'),
              controller: _amountController,
              autofocus: !_isEditing,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: context.strings.get('amount'),
                prefixText: '₩ ',
                suffixText: context.strings.get('won'),
                border: const OutlineInputBorder(),
              ),
            ),
            if (_validationMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _validationMessage!,
                key: const Key('expense-validation-message'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<ExpenseCategory>(
              key: const Key('expense-category-field'),
              initialValue: _category,
              decoration: InputDecoration(
                labelText: context.strings.get('category'),
                border: const OutlineInputBorder(),
              ),
              items: ExpenseCategory.values
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(context.strings.expenseCategory(category)),
                    ),
                  )
                  .toList(),
              onChanged: isSaving
                  ? null
                  : (value) {
                      if (value != null) setState(() => _category = value);
                    },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PaymentMethod>(
              key: const Key('expense-payment-field'),
              initialValue: _paymentMethod,
              decoration: InputDecoration(
                labelText: context.strings.get('paymentMethod'),
                border: const OutlineInputBorder(),
              ),
              items: PaymentMethod.values
                  .map(
                    (method) => DropdownMenuItem(
                      value: method,
                      child: Text(context.strings.paymentMethod(method)),
                    ),
                  )
                  .toList(),
              onChanged: isSaving
                  ? null
                  : (value) {
                      if (value != null) setState(() => _paymentMethod = value);
                    },
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('expense-memo-field'),
              controller: _memoController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: context.strings.get('memoOptional'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('expense-title-field'),
              controller: _titleController,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: context.strings.get('titleOptional'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            _ValueTile(
              icon: Icons.calendar_today_outlined,
              label: context.strings.get('date'),
              value: _formatDate(_date),
              onTap: _pickDate,
            ),
            _ValueTile(
              icon: Icons.schedule_outlined,
              label: context.strings.get('time'),
              value: _timeMinutes == null
                  ? context.strings.get('notSelected')
                  : _formatTime(_timeMinutes!),
              onTap: _pickTime,
              onClear: _timeMinutes == null
                  ? null
                  : () => setState(() => _timeMinutes = null),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('save-expense-button'),
              onPressed: isSaving ? null : _save,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: isSaving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.strings.get('save')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date.toDateTime(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (selected != null && mounted) {
      setState(() => _date = LocalDate.fromDateTime(selected));
    }
  }

  Future<void> _pickTime() async {
    final current = _timeMinutes;
    final selected = await showTimePicker(
      context: context,
      initialTime: current == null
          ? TimeOfDay.now()
          : TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (selected != null && mounted) {
      setState(() => _timeMinutes = selected.hour * 60 + selected.minute);
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final amount = int.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(
        () => _validationMessage = context.strings.get('amountRequired'),
      );
      return;
    }
    setState(() => _validationMessage = null);

    final draft = ExpenseDraft(
      amount: amount,
      category: _category,
      paymentMethod: _paymentMethod,
      memo: _memoController.text,
      title: _titleController.text,
      eventDate: _date,
      eventTimeMinutes: _timeMinutes,
    );
    final controller = ref.read(expenseControllerProvider.notifier);
    final expense = _isEditing
        ? await controller.saveEdit(widget.expense!.record.id, draft)
        : await controller.create(draft);
    if (!mounted) return;

    if (expense != null) {
      context.go('/expenses/${expense.record.id}');
      return;
    }
    final error = ref.read(expenseControllerProvider).error;
    if (error is ExpenseValidationException) {
      setState(
        () => _validationMessage = context.strings.get('amountRequired'),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.get('expenseSaveError'))),
      );
    }
  }
}

void _closeForm(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/');
  }
}

class _ValueTile extends StatelessWidget {
  const _ValueTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(label),
    subtitle: Text(value),
    onTap: onTap,
    trailing: onClear == null
        ? const Icon(Icons.chevron_right_rounded)
        : IconButton(
            tooltip: context.strings.get('clearSelection'),
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded),
          ),
  );
}

class _MissingExpenseScreen extends StatelessWidget {
  const _MissingExpenseScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.strings.get('expense'))),
    body: Center(child: Text(context.strings.get('notFound'))),
  );
}

class _LoadErrorScreen extends StatelessWidget {
  const _LoadErrorScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.strings.get('expense'))),
    body: Center(child: Text(context.strings.get('loadError'))),
  );
}

String _formatDate(LocalDate date) =>
    '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

String _formatTime(int minutes) {
  final hour = (minutes ~/ 60).toString().padLeft(2, '0');
  final minute = (minutes % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}
