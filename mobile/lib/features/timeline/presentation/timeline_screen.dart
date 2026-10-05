import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_life/core/localization/app_strings.dart';
import 'package:my_life/features/photo/application/photo_providers.dart';
import 'package:my_life/features/record/domain/life_record.dart';
import 'package:my_life/features/record/domain/local_date.dart';
import 'package:my_life/features/timeline/application/timeline_providers.dart';
import 'package:my_life/features/timeline/domain/timeline_entry.dart';
import 'package:my_life/features/timeline/presentation/timeline_entry_labels.dart';

class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(timelineFilterProvider);
    final entries = ref.watch(timelineEntriesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.strings.get('timeline'))),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Filters(filter: filter),
            Expanded(
              child: entries.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    key: Key('timeline-loading'),
                  ),
                ),
                error: (_, _) => _ErrorState(
                  onRetry: () => ref.invalidate(timelineEntriesProvider),
                ),
                data: (items) => items.isEmpty
                    ? const _EmptyState()
                    : _TimelineList(entries: items),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Filters extends ConsumerWidget {
  const _Filters({required this.filter});

  final TimelineFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _TypeChip(
                  key: const Key('timeline-filter-all'),
                  label: strings.get('filterAll'),
                  selected: filter.type == null,
                  onSelected: () =>
                      ref.read(timelineFilterProvider.notifier).setType(null),
                ),
                const SizedBox(width: 8),
                for (final type in RecordType.values) ...[
                  _TypeChip(
                    key: Key('timeline-filter-${type.name}'),
                    label: strings.get(type.name),
                    selected: filter.type == type,
                    onSelected: () =>
                        ref.read(timelineFilterProvider.notifier).setType(type),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                key: const Key('timeline-date-range'),
                onPressed: () => _pickDateRange(context, ref),
                icon: const Icon(Icons.date_range_outlined, size: 19),
                label: Text(
                  filter.hasDateRange
                      ? '${_shortDate(filter.startDate!)} – '
                            '${_shortDate(filter.endDate!)}'
                      : strings.get('dateRange'),
                ),
              ),
              if (filter.hasDateRange) ...[
                const SizedBox(width: 4),
                IconButton(
                  key: const Key('timeline-clear-date-range'),
                  tooltip: strings.get('clearDateRange'),
                  onPressed: ref
                      .read(timelineFilterProvider.notifier)
                      .clearDateRange,
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateRange(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 10, 12, 31),
      initialDateRange: filter.hasDateRange
          ? DateTimeRange(
              start: filter.startDate!.toDateTime(),
              end: filter.endDate!.toDateTime(),
            )
          : null,
    );
    if (result == null) return;
    ref
        .read(timelineFilterProvider.notifier)
        .setDateRange(
          LocalDate.fromDateTime(result.start),
          LocalDate.fromDateTime(result.end),
        );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _TimelineList extends StatelessWidget {
  const _TimelineList({required this.entries});

  final List<TimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    LocalDate? previousDate;
    final children = <Widget>[];
    for (final entry in entries) {
      if (entry.record.eventDate != previousDate) {
        previousDate = entry.record.eventDate;
        children.add(
          Padding(
            padding: EdgeInsets.fromLTRB(4, children.isEmpty ? 4 : 20, 4, 8),
            child: Text(
              _longDate(entry.record.eventDate),
              key: Key(
                'timeline-date-${entry.record.eventDate.toIso8601String()}',
              ),
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        );
      }
      children.add(_TimelineCard(entry: entry));
    }

    return ListView(
      key: const Key('timeline-list'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: children,
    );
  }
}

class _TimelineCard extends ConsumerWidget {
  const _TimelineCard({required this.entry});

  final TimelineEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = entry.record;
    final strings = context.strings;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: Key('timeline-entry-${record.id}'),
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push(recordDetailPath(record)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Leading(entry: entry),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              recordEntryLabel(entry, strings),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (record.eventTimeMinutes != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              _time(record.eventTimeMinutes!),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _subtitle(entry, strings),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Leading extends ConsumerWidget {
  const _Leading({required this.entry});

  final TimelineEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (entry.record.type == RecordType.photo && entry.photos.isNotEmpty) {
      final photo = entry.photos.first;
      final path = photo.thumbnailPath ?? photo.filePath;
      return SizedBox(
        width: 54,
        height: 54,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ref
              .watch(photoPathProvider(path))
              .when(
                data: (absolutePath) => Image.file(
                  File(absolutePath),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _TypeIcon(type: entry.record.type),
                ),
                loading: () => const ColoredBox(
                  color: Color(0xFFEDE7E1),
                  child: Center(
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                error: (_, _) => _TypeIcon(type: entry.record.type),
              ),
        ),
      );
    }
    return SizedBox(
      width: 54,
      height: 54,
      child: _TypeIcon(type: entry.record.type),
    );
  }
}

class _TypeIcon extends StatelessWidget {
  const _TypeIcon({required this.type});

  final RecordType type;

  @override
  Widget build(BuildContext context) {
    final icon = switch (type) {
      RecordType.memo => Icons.notes_rounded,
      RecordType.expense => Icons.receipt_long_outlined,
      RecordType.photo => Icons.photo_outlined,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: Theme.of(context).colorScheme.onSecondaryContainer,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_stories_outlined, size: 42),
            const SizedBox(height: 14),
            Text(
              context.strings.get('timelineEmptyTitle'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              context.strings.get('timelineEmptyBody'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.strings.get('timelineLoadError')),
          const SizedBox(height: 10),
          OutlinedButton(
            key: const Key('timeline-retry'),
            onPressed: onRetry,
            child: Text(context.strings.get('retry')),
          ),
        ],
      ),
    );
  }
}

String _subtitle(TimelineEntry entry, AppStrings strings) {
  return switch (entry.record.type) {
    RecordType.memo =>
      entry.record.placeName?.trim().isNotEmpty == true
          ? entry.record.placeName!.trim()
          : strings.get('memo'),
    RecordType.expense => [
      if (entry.expenseAmount != null) formatWon(entry.expenseAmount!),
      if (entry.expenseCategory != null)
        strings.expenseCategory(entry.expenseCategory!),
    ].join(' · '),
    RecordType.photo => strings.get(
      'photosCount',
      values: {'count': entry.photos.length},
    ),
  };
}

String _time(int minutes) {
  final hour = (minutes ~/ 60).toString().padLeft(2, '0');
  final minute = (minutes % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _shortDate(LocalDate date) {
  return '${date.year}.${date.month.toString().padLeft(2, '0')}.'
      '${date.day.toString().padLeft(2, '0')}';
}

String _longDate(LocalDate date) => _shortDate(date);
