import 'package:my_life/features/record/presentation/record_form_widgets.dart';
import 'package:my_life/shared/formatting/display_formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_life/core/localization/app_strings.dart';
import 'package:my_life/features/record/application/record_providers.dart';
import 'package:my_life/features/record/domain/life_record.dart';
import 'package:my_life/features/record/domain/local_date.dart';

class MemoFormScreen extends ConsumerWidget {
  const MemoFormScreen({this.recordId, super.key});

  final String? recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = recordId;
    if (id == null) {
      return const _MemoEditor();
    }

    return ref
        .watch(recordDetailProvider(id))
        .when(
          data: (record) {
            if (record == null || record.type != RecordType.memo) {
              return const _MissingMemoScreen();
            }
            return _MemoEditor(key: ValueKey(record.updatedAt), record: record);
          },
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, _) => const _LoadErrorScreen(),
        );
  }
}

class _MemoEditor extends ConsumerStatefulWidget {
  const _MemoEditor({this.record, super.key});

  final LifeRecord? record;

  @override
  ConsumerState<_MemoEditor> createState() => _MemoEditorState();
}

class _MemoEditorState extends ConsumerState<_MemoEditor> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _placeController;
  late LocalDate _date;
  int? _timeMinutes;
  String? _validationMessage;

  bool get _isEditing => widget.record != null;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    _titleController = TextEditingController(text: record?.title);
    _contentController = TextEditingController(text: record?.content);
    _placeController = TextEditingController(text: record?.placeName);
    _date = record?.eventDate ?? LocalDate.fromDateTime(DateTime.now());
    _timeMinutes = record?.eventTimeMinutes;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _placeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(memoControllerProvider);
    final isSaving = controllerState.isLoading;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          key: const Key('memo-form-back-button'),
          onPressed: () => closeRecordForm(context),
        ),
        title: Text(context.strings.get(_isEditing ? 'memoEdit' : 'memo')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            TextField(
              key: const Key('memo-title-field'),
              controller: _titleController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: context.strings.get('titleOptional'),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('memo-content-field'),
              controller: _contentController,
              minLines: 6,
              maxLines: 12,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: context.strings.get('contentOptional'),
                alignLabelWithHint: true,
              ),
            ),
            if (_validationMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _validationMessage!,
                key: const Key('memo-validation-message'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            RecordValueTile(
              icon: Icons.calendar_today_outlined,
              label: context.strings.get('date'),
              value: formatRecordDate(_date),
              onTap: _pickDate,
            ),
            RecordValueTile(
              icon: Icons.schedule_outlined,
              label: context.strings.get('time'),
              value: _timeMinutes == null
                  ? context.strings.get('notSelected')
                  : formatRecordTime(_timeMinutes!),
              onTap: _pickTime,
              onClear: _timeMinutes == null
                  ? null
                  : () => setState(() => _timeMinutes = null),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('memo-place-field'),
              controller: _placeController,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: context.strings.get('placeOptional'),
                prefixIcon: const Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              key: const Key('save-memo-button'),
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
    final draft = MemoDraft(
      title: _titleController.text,
      content: _contentController.text,
      eventDate: _date,
      eventTimeMinutes: _timeMinutes,
      placeName: _placeController.text,
    );
    final controller = ref.read(memoControllerProvider.notifier);
    final record = _isEditing
        ? await controller.saveEdit(widget.record!.id, draft)
        : await controller.create(draft);
    if (!mounted) return;

    if (record != null) {
      context.go('/records/${record.id}');
      return;
    }

    final error = ref.read(memoControllerProvider).error;
    if (error is MemoValidationException) {
      setState(() => _validationMessage = context.strings.get('memoRequired'));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.get('memoSaveError'))),
      );
    }
  }
}

class _MissingMemoScreen extends StatelessWidget {
  const _MissingMemoScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.strings.get('memo'))),
    body: Center(child: Text(context.strings.get('notFound'))),
  );
}

class _LoadErrorScreen extends StatelessWidget {
  const _LoadErrorScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.strings.get('memo'))),
    body: Center(child: Text(context.strings.get('loadError'))),
  );
}
