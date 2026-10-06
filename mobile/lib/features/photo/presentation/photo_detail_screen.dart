import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_life/core/localization/app_strings.dart';
import 'package:my_life/features/record/presentation/record_detail_back_button.dart';
import 'package:my_life/features/photo/application/photo_providers.dart';
import 'package:my_life/features/photo/domain/photo_record.dart';

class PhotoDetailScreen extends ConsumerWidget {
  const PhotoDetailScreen({required this.recordId, super.key});

  final String recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(photoDetailProvider(recordId))
        .when(
          data: (record) => record == null
              ? _MissingDetail(onClose: () => context.go('/'))
              : _PhotoDetail(record: record),
          loading: () => Scaffold(
            appBar: AppBar(
              leading: const RecordDetailBackButton(
                key: Key('photo-detail-back-button'),
              ),
              title: Text(context.strings.get('photo')),
            ),
            body: const Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Scaffold(
            appBar: AppBar(
              leading: const RecordDetailBackButton(
                key: Key('photo-detail-back-button'),
              ),
              title: Text(context.strings.get('photo')),
            ),
            body: Center(child: Text(context.strings.get('loadError'))),
          ),
        );
  }
}

class _PhotoDetail extends ConsumerWidget {
  const _PhotoDetail({required this.record});

  final PhotoRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBusy = ref.watch(photoControllerProvider).isLoading;
    return Scaffold(
      appBar: AppBar(
        leading: const RecordDetailBackButton(
          key: Key('photo-detail-back-button'),
        ),
        title: Text(context.strings.get('photo')),
        actions: [
          IconButton(
            key: const Key('edit-photo-button'),
            tooltip: context.strings.get('edit'),
            onPressed: isBusy
                ? null
                : () => context.push('/photos/${record.record.id}/edit'),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            key: const Key('delete-photo-record-button'),
            tooltip: context.strings.get('delete'),
            onPressed: isBusy ? null : () => _confirmDeleteRecord(context, ref),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            Text(
              record.record.title?.trim().isNotEmpty == true
                  ? record.record.title!.trim()
                  : record.photos.length == 1
                  ? context.strings.get('photo')
                  : context.strings.get(
                      'photosCount',
                      values: {'count': record.photos.length},
                    ),
              key: const Key('photo-detail-title'),
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _metadata(record, context.strings),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: record.photos.length,
              itemBuilder: (context, index) {
                final photo = record.photos[index];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    _StoredImage(
                      relativePath: photo.thumbnailPath ?? photo.filePath,
                      onTap: () => _showOriginal(context, ref, photo),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton.filledTonal(
                        key: Key('delete-photo-${photo.id}'),
                        tooltip: context.strings.get('photoDelete'),
                        onPressed: isBusy
                            ? null
                            : () => _confirmDeletePhoto(context, ref, photo),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showOriginal(
    BuildContext context,
    WidgetRef ref,
    StoredPhoto photo,
  ) async {
    final path = await ref.read(photoPathProvider(photo.filePath).future);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: InteractiveViewer(
            minScale: 0.8,
            maxScale: 5,
            child: Center(child: Image.file(File(path))),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeletePhoto(
    BuildContext context,
    WidgetRef ref,
    StoredPhoto photo,
  ) async {
    if (record.photos.length == 1) {
      await _confirmDeleteRecord(context, ref, lastPhoto: true);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.strings.get('photoDeleteTitle')),
        content: Text(context.strings.get('photoDeleteBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.strings.get('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.strings.get('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final deleted = await ref
        .read(photoControllerProvider.notifier)
        .deletePhoto(record.record.id, photo.id);
    if (!context.mounted || deleted) return;
    _showDeleteError(context);
  }

  Future<void> _confirmDeleteRecord(
    BuildContext context,
    WidgetRef ref, {
    bool lastPhoto = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          context.strings.get(
            lastPhoto ? 'lastPhotoDeleteTitle' : 'photoRecordDeleteTitle',
          ),
        ),
        content: Text(
          context.strings.get(
            lastPhoto ? 'lastPhotoDeleteBody' : 'photoRecordDeleteBody',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.strings.get('cancel')),
          ),
          FilledButton(
            key: const Key('confirm-delete-photo-record-button'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.strings.get('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final deleted = await ref
        .read(photoControllerProvider.notifier)
        .deleteRecord(record.record.id);
    if (!context.mounted) return;
    if (deleted) {
      context.go('/');
    } else {
      _showDeleteError(context);
    }
  }

  void _showDeleteError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.strings.get('photoDeleteError'))),
    );
  }
}

class _StoredImage extends ConsumerWidget {
  const _StoredImage({required this.relativePath, required this.onTap});

  final String relativePath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(photoPathProvider(relativePath))
        .when(
          data: (path) => ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Ink.image(
              image: FileImage(File(path)),
              fit: BoxFit.cover,
              child: InkWell(onTap: onTap),
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              const Center(child: Icon(Icons.broken_image_outlined)),
        );
  }
}

class _MissingDetail extends StatelessWidget {
  const _MissingDetail({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const RecordDetailBackButton(
        key: Key('photo-detail-back-button'),
      ),
      title: Text(context.strings.get('photo')),
    ),
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

String _metadata(PhotoRecord record, AppStrings strings) {
  final date = record.record.eventDate;
  final buffer = StringBuffer(
    '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}',
  );
  final minutes = record.record.eventTimeMinutes;
  if (minutes != null) {
    buffer.write(
      '  ${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}',
    );
  }
  final place = record.record.placeName?.trim();
  if (place != null && place.isNotEmpty) {
    buffer.write('  ·  $place');
  }
  final count = strings.get(
    'photosCount',
    values: {'count': record.photos.length},
  );
  return '$buffer  ·  $count';
}
