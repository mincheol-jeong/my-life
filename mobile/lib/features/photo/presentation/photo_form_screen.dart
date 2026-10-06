import 'package:my_life/features/record/presentation/record_form_widgets.dart';
import 'package:my_life/shared/formatting/display_formatters.dart';

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_life/core/localization/app_strings.dart';
import 'package:my_life/features/photo/application/photo_providers.dart';
import 'package:my_life/features/photo/domain/photo_record.dart';
import 'package:my_life/features/record/domain/local_date.dart';

class PhotoFormScreen extends ConsumerWidget {
  const PhotoFormScreen({this.recordId, super.key});

  final String? recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = recordId;
    if (id == null) return const _PhotoEditor();
    return ref
        .watch(photoDetailProvider(id))
        .when(
          data: (record) => record == null
              ? const _MissingPhotoScreen()
              : _PhotoEditor(
                  key: ValueKey(record.record.updatedAt),
                  record: record,
                ),
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, _) => const _LoadErrorScreen(),
        );
  }
}

class _PhotoEditor extends ConsumerStatefulWidget {
  const _PhotoEditor({this.record, super.key});

  final PhotoRecord? record;

  @override
  ConsumerState<_PhotoEditor> createState() => _PhotoEditorState();
}

class _PhotoEditorState extends ConsumerState<_PhotoEditor> {
  final _selected = <XFile>[];
  late final TextEditingController _titleController;
  late final TextEditingController _placeController;
  late LocalDate _date;
  int? _timeMinutes;
  String? _validationMessage;
  String? _metadataPhotoPath;
  int _metadataRequest = 0;
  bool _dateEdited = false;
  bool _timeEdited = false;
  bool _placeEdited = false;
  bool _isReadingMetadata = false;

  bool get _isEditing => widget.record != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.record?.record.title);
    _placeController = TextEditingController(
      text: widget.record?.record.placeName,
    );
    _date =
        widget.record?.record.eventDate ??
        LocalDate.fromDateTime(DateTime.now());
    _timeMinutes = widget.record?.record.eventTimeMinutes;
    if (!_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _consumeLostPhotos());
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _placeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(photoControllerProvider).isLoading;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          key: const Key('photo-form-back-button'),
          onPressed: () => closeRecordForm(context),
        ),
        title: Text(context.strings.get(_isEditing ? 'photoEdit' : 'photo')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (!_isEditing) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('pick-gallery-button'),
                      onPressed: isSaving ? null : _pickFromGallery,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(context.strings.get('gallery')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('take-photo-button'),
                      onPressed: isSaving ? null : _takePhoto,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: Text(context.strings.get('camera')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_selected.isEmpty)
                Container(
                  height: 180,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(context.strings.get('photoRequired')),
                )
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _selected.length,
                  onReorderItem: _reorder,
                  itemBuilder: (context, index) {
                    final file = _selected[index];
                    return ListTile(
                      key: ValueKey(file.path),
                      contentPadding: EdgeInsets.zero,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          File(file.path),
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: Text(
                        context.strings.get(
                          'photoNumber',
                          values: {'count': index + 1},
                        ),
                      ),
                      subtitle: Text(context.strings.get('reorderHint')),
                      trailing: IconButton(
                        tooltip: context.strings.get('removeSelection'),
                        onPressed: isSaving
                            ? null
                            : () {
                                setState(() => _selected.removeAt(index));
                                unawaited(_suggestFirstPhoto());
                              },
                        icon: const Icon(Icons.close_rounded),
                      ),
                    );
                  },
                ),
              if (_validationMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _validationMessage!,
                  key: const Key('photo-validation-message'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (_isReadingMetadata) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 20),
            ] else ...[
              Text(
                context.strings.get('photoEditHint'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
            ],
            TextField(
              key: const Key('photo-title-field'),
              controller: _titleController,
              decoration: InputDecoration(
                labelText: context.strings.get('titleOptional'),
              ),
            ),
            const SizedBox(height: 12),
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
                  : () => setState(() {
                      _timeEdited = true;
                      _timeMinutes = null;
                    }),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('photo-place-field'),
              controller: _placeController,
              onChanged: (_) => _placeEdited = true,
              decoration: InputDecoration(
                labelText: context.strings.get('placeOptional'),
                prefixIcon: const Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('save-photo-button'),
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

  Future<void> _pickFromGallery() async {
    try {
      final files = await ref
          .read(photoPickerProvider)
          .pickMultiImage(requestFullMetadata: true);
      if (files.isNotEmpty) await _addSelectedPhotos(files);
    } catch (_) {
      _showPickerError();
    }
  }

  Future<void> _takePhoto() async {
    try {
      final file = await ref
          .read(photoPickerProvider)
          .pickImage(source: ImageSource.camera, requestFullMetadata: true);
      if (file != null) await _addSelectedPhotos([file]);
    } catch (_) {
      _showPickerError();
    }
  }

  Future<void> _consumeLostPhotos() async {
    await ref.read(recoveredPhotoPathsProvider.future);
    if (!mounted) return;
    final paths = ref.read(recoveredPhotoPathsProvider.notifier).take();
    if (paths.isNotEmpty) {
      await _addSelectedPhotos(paths.map(XFile.new).toList());
    }
  }

  Future<void> _addSelectedPhotos(List<XFile> files) async {
    if (!mounted) return;
    setState(() {
      final paths = _selected.map((file) => file.path).toSet();
      _selected.addAll(files.where((file) => paths.add(file.path)));
    });
    await _suggestFirstPhoto();
  }

  Future<void> _suggestFirstPhoto() async {
    if (!mounted) return;
    final path = _selected.isEmpty ? null : _selected.first.path;
    if (path == _metadataPhotoPath) return;
    _metadataPhotoPath = path;
    final request = ++_metadataRequest;
    setState(() => _isReadingMetadata = path != null);
    if (path == null) return;
    final suggestion = await ref
        .read(photoMetadataReaderProvider)
        .read(path, locale: Localizations.localeOf(context));
    if (!mounted || request != _metadataRequest) return;
    setState(() {
      _isReadingMetadata = false;
      final capturedAt = suggestion.capturedAt;
      if (capturedAt != null) {
        if (!_dateEdited) _date = LocalDate.fromDateTime(capturedAt);
        if (!_timeEdited) {
          _timeMinutes = capturedAt.hour * 60 + capturedAt.minute;
        }
      }
      if (!_placeEdited && suggestion.placeName != null) {
        _placeController.text = suggestion.placeName!;
      }
    });
    if (!suggestion.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.get('photoMetadataApplied'))),
      );
    }
  }

  void _showPickerError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.strings.get('photoPickError'))),
    );
  }

  void _reorder(int oldIndex, int newIndex) {
    if (ref.read(photoControllerProvider).isLoading) return;
    setState(() {
      final item = _selected.removeAt(oldIndex);
      _selected.insert(newIndex, item);
    });
    unawaited(_suggestFirstPhoto());
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date.toDateTime(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (selected != null && mounted) {
      setState(() {
        _dateEdited = true;
        _date = LocalDate.fromDateTime(selected);
      });
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
      setState(() {
        _timeEdited = true;
        _timeMinutes = selected.hour * 60 + selected.minute;
      });
    }
  }

  Future<void> _save() async {
    if (!_isEditing && _selected.isEmpty) {
      setState(() => _validationMessage = context.strings.get('photoRequired'));
      return;
    }
    final draft = PhotoDraft(
      title: _titleController.text,
      eventDate: _date,
      eventTimeMinutes: _timeMinutes,
      placeName: _placeController.text,
    );
    _metadataRequest++;
    _metadataPhotoPath = null;
    _isReadingMetadata = false;
    final controller = ref.read(photoControllerProvider.notifier);
    final record = _isEditing
        ? await controller.saveEdit(widget.record!.record.id, draft)
        : await controller.create(
            draft,
            _selected.map((file) => file.path).toList(growable: false),
          );
    if (!mounted) return;
    if (record != null) {
      context.go('/photos/${record.record.id}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.get('photoSaveError'))),
      );
    }
  }
}

class _MissingPhotoScreen extends StatelessWidget {
  const _MissingPhotoScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.strings.get('photo'))),
    body: Center(child: Text(context.strings.get('notFound'))),
  );
}

class _LoadErrorScreen extends StatelessWidget {
  const _LoadErrorScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.strings.get('photo'))),
    body: Center(child: Text(context.strings.get('loadError'))),
  );
}
