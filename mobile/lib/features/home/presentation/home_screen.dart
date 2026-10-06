import 'package:my_life/shared/formatting/display_formatters.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_life/core/localization/app_strings.dart';
import 'package:my_life/features/home/application/home_providers.dart';
import 'package:my_life/features/record/application/local_date_provider.dart';
import 'package:my_life/features/photo/application/photo_providers.dart';
import 'package:my_life/features/record/domain/life_record.dart';
import 'package:my_life/features/record/domain/local_date.dart';
import 'package:my_life/features/timeline/domain/timeline_entry.dart';
import 'package:my_life/features/record/presentation/record_entry_labels.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final today = ref.watch(todayProvider);
    final recent = ref.watch(homeRecentRecordsProvider);
    final expense = ref.watch(homeMonthlyExpenseProvider);
    final photos = ref.watch(homeRecentPhotosProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('MY LIFE')),
      body: SafeArea(
        child: ListView(
          key: const Key('home-list'),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            Text(
              _date(today),
              key: const Key('home-today'),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            _Section(
              title: strings.get('homeMonthlyExpense'),
              child: expense.when(
                loading: () => const _Loading(section: 'expense'),
                error: (_, _) => _SectionError(
                  section: 'expense',
                  onRetry: () => ref.invalidate(homeMonthlyExpenseProvider),
                ),
                data: (total) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatWon(total),
                      key: const Key('home-expense-total'),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    if (total == 0) ...[
                      const SizedBox(height: 6),
                      Text(strings.get('homeExpenseEmpty')),
                    ],
                  ],
                ),
              ),
            ),
            _Section(
              title: strings.get('homeRecentRecords'),
              child: recent.when(
                loading: () => const _Loading(section: 'records'),
                error: (_, _) => _SectionError(
                  section: 'records',
                  onRetry: () => ref.invalidate(homeRecentRecordsProvider),
                ),
                data: (items) => items.isEmpty
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(strings.get('timelineEmptyTitle')),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            key: const Key('home-create-record'),
                            onPressed: () => context.push('/record'),
                            child: Text(strings.get('record')),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          for (final entry in items) _RecordRow(entry: entry),
                        ],
                      ),
              ),
            ),
            _Section(
              title: strings.get('homeRecentPhotos'),
              child: photos.when(
                loading: () => const _Loading(section: 'photos'),
                error: (_, _) => _SectionError(
                  section: 'photos',
                  onRetry: () => ref.invalidate(homeRecentPhotosProvider),
                ),
                data: (items) => items.isEmpty
                    ? Text(strings.get('homePhotosEmpty'))
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final entry in items)
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: _PhotoPreview(entry: entry),
                              ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.entry});
  final TimelineEntry entry;

  @override
  Widget build(BuildContext context) {
    final record = entry.record;
    final icon = switch (record.type) {
      RecordType.memo => Icons.notes_rounded,
      RecordType.expense => Icons.receipt_long_outlined,
      RecordType.photo => Icons.photo_outlined,
    };
    return ListTile(
      key: Key('home-record-${record.id}'),
      contentPadding: EdgeInsets.zero,
      minVerticalPadding: 10,
      leading: Icon(icon),
      title: Text(
        recordEntryLabel(entry, context.strings),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          _date(record.eventDate),
          if (entry.expenseAmount != null) formatWon(entry.expenseAmount!),
        ].join(' · '),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: () => context.push(recordDetailPath(record)),
    );
  }
}

class _PhotoPreview extends ConsumerWidget {
  const _PhotoPreview({required this.entry});
  final TimelineEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = entry.photos.first;
    final path = ref.watch(
      photoPathProvider(photo.thumbnailPath ?? photo.filePath),
    );
    final label = recordEntryLabel(entry, context.strings);
    return Semantics(
      label: '$label, ${_date(entry.record.eventDate)}',
      button: true,
      child: InkWell(
        key: Key('home-photo-${entry.record.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(recordDetailPath(entry.record)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox.square(
            dimension: 104,
            child: path.when(
              data: (absolutePath) => Image.file(
                File(absolutePath),
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => const _MissingPhoto(),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const _MissingPhoto(),
            ),
          ),
        ),
      ),
    );
  }
}

class _MissingPhoto extends StatelessWidget {
  const _MissingPhoto();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainer,
    child: Center(
      child: Tooltip(
        message: context.strings.get('homePhotoUnavailable'),
        child: const Icon(Icons.broken_image_outlined),
      ),
    ),
  );
}

class _Loading extends StatelessWidget {
  const _Loading({required this.section});
  final String section;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: SizedBox.square(
      dimension: 24,
      child: CircularProgressIndicator(key: Key('home-$section-loading')),
    ),
  );
}

class _SectionError extends StatelessWidget {
  const _SectionError({required this.section, required this.onRetry});
  final String section;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(context.strings.get('homeLoadError')),
      TextButton(
        key: Key('home-$section-retry'),
        onPressed: onRetry,
        child: Text(context.strings.get('retry')),
      ),
    ],
  );
}

String _date(LocalDate date) => date.toIso8601String().replaceAll('-', '.');
