import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_life/core/localization/app_strings.dart';
import 'package:my_life/features/record/application/record_providers.dart';
import 'package:my_life/features/record/domain/life_record.dart';

class MemoDetailScreen extends ConsumerWidget {
  const MemoDetailScreen({required this.recordId, super.key});

  final String recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(recordDetailProvider(recordId))
        .when(
          data: (record) => record == null || record.type != RecordType.memo
              ? _MissingDetail(onClose: () => context.go('/'))
              : _MemoDetail(record: record),
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, _) => Scaffold(
            appBar: AppBar(title: Text(context.strings.get('memo'))),
            body: Center(child: Text(context.strings.get('loadError'))),
          ),
        );
  }
}

class _MemoDetail extends ConsumerWidget {
  const _MemoDetail({required this.record});

  final LifeRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.strings.get('memo')),
        actions: [
          IconButton(
            key: const Key('edit-memo-button'),
            tooltip: context.strings.get('edit'),
            onPressed: () => context.push('/records/${record.id}/edit'),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            key: const Key('delete-memo-button'),
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
              record.displayLabel,
              key: const Key('memo-detail-title'),
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              _metadata(record),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (record.placeName != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.place_outlined, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text(record.placeName!)),
                ],
              ),
            ],
            if (record.content != null) ...[
              const SizedBox(height: 28),
              SelectableText(
                record.content!,
                key: const Key('memo-detail-content'),
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
        title: Text(context.strings.get('memoDeleteTitle')),
        content: Text(context.strings.get('memoDeleteBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.strings.get('cancel')),
          ),
          FilledButton(
            key: const Key('confirm-delete-memo-button'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.strings.get('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final deleted = await ref
        .read(memoControllerProvider.notifier)
        .delete(record.id);
    if (!context.mounted) return;
    if (deleted) {
      context.go('/');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.get('memoDeleteError'))),
      );
    }
  }
}

class _MissingDetail extends StatelessWidget {
  const _MissingDetail({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.strings.get('memo'))),
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

String _metadata(LifeRecord record) {
  final date = record.eventDate;
  final buffer = StringBuffer(
    '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}',
  );
  final minutes = record.eventTimeMinutes;
  if (minutes != null) {
    buffer.write(
      '  ${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}',
    );
  }
  return buffer.toString();
}
