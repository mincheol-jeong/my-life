import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_life/core/localization/app_strings.dart';
import 'package:my_life/features/calendar_import/application/calendar_import_providers.dart';
import 'package:my_life/features/calendar_import/domain/calendar_import_models.dart';
import 'package:my_life/features/calendar_import/application/calendar_sync_controller.dart';

class CalendarImportScreen extends ConsumerWidget {
  const CalendarImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calendarImportControllerProvider);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/me'),
        ),
        title: Text(context.strings.get('calendarImport')),
      ),
      body: SafeArea(
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _ErrorState(
            onRetry: () => ref.invalidate(calendarImportControllerProvider),
          ),
          data: (value) => _Content(state: value),
        ),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.state});

  final CalendarImportState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.access != CalendarAccessState.granted) {
      return _PermissionState(access: state.access);
    }
    final strings = context.strings;
    final sync = ref.watch(calendarSyncControllerProvider);
    final syncResult = ref.watch(calendarSyncResultProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        Text(
          strings.get('calendarImportDescription'),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        SwitchListTile(
          key: const Key('calendar-auto-sync'),
          contentPadding: EdgeInsets.zero,
          title: Text(strings.get('calendarAutoSync')),
          subtitle: Text(strings.get('calendarAutoSyncHint')),
          value: sync.value != null,
          onChanged:
              sync.isLoading ||
                  (sync.value == null && state.selectedCalendarIds.isEmpty)
              ? null
              : (enabled) async {
                  await _configureCalendarSync(
                    context,
                    ref,
                    enabled
                        ? CalendarSyncSettings(
                            ids: state.selectedCalendarIds,
                            start: state.startDate,
                            end: state.endDate,
                          )
                        : null,
                  );
                },
        ),
        if (sync.value != null) ...[
          Text(
            strings.get(
              'calendarSyncRange',
              values: {
                'start': _date(sync.value!.start),
                'end': _date(sync.value!.end),
              },
            ),
          ),
          TextButton(
            onPressed: sync.isLoading || state.selectedCalendarIds.isEmpty
                ? null
                : () => _configureCalendarSync(
                    context,
                    ref,
                    CalendarSyncSettings(
                      ids: state.selectedCalendarIds,
                      start: state.startDate,
                      end: state.endDate,
                    ),
                  ),
            child: Text(strings.get('calendarSyncApply')),
          ),
        ],
        if (syncResult.isLoading) const LinearProgressIndicator(),
        if (syncResult.hasError) Text(strings.get('calendarImportError')),
        if (syncResult.value != null)
          Text(
            strings.get(
              'calendarSyncResult',
              values: {
                'imported': syncResult.value!.imported,
                'updated': syncResult.value!.updated,
                'removed': syncResult.value!.removed,
                'protected': syncResult.value!.protected,
              },
            ),
          ),
        const SizedBox(height: 16),
        Text(
          strings.get('importPeriod'),
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('calendar-import-date-range'),
          onPressed: () => _pickRange(context, ref),
          icon: const Icon(Icons.date_range_outlined),
          label: Text('${_date(state.startDate)} – ${_date(state.endDate)}'),
        ),
        const SizedBox(height: 22),
        Text(
          strings.get('selectCalendars'),
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        if (state.calendars.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(strings.get('noCalendars')),
          )
        else
          ...state.calendars.map(
            (calendar) => CheckboxListTile(
              key: Key('calendar-${calendar.id}'),
              contentPadding: EdgeInsets.zero,
              value: state.selectedCalendarIds.contains(calendar.id),
              title: Text(calendar.name),
              subtitle: calendar.isPrimary
                  ? Text(strings.get('primaryCalendar'))
                  : null,
              onChanged: (selected) => ref
                  .read(calendarImportControllerProvider.notifier)
                  .toggleCalendar(calendar.id, selected ?? false),
            ),
          ),
        if (state.lastResult != null) ...[
          const SizedBox(height: 12),
          Container(
            key: const Key('calendar-import-result'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              strings.get(
                'calendarImportResult',
                values: {
                  'imported': state.lastResult!.imported,
                  'skipped': state.lastResult!.skipped,
                },
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const Key('import-calendar-button'),
          onPressed: state.selectedCalendarIds.isEmpty
              ? null
              : ref
                    .read(calendarImportControllerProvider.notifier)
                    .importSelected,
          icon: const Icon(Icons.download_rounded),
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Text(strings.get('importSelectedEvents')),
          ),
        ),
      ],
    );
  }

  Future<void> _pickRange(BuildContext context, WidgetRef ref) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 10, 12, 31),
      initialDateRange: DateTimeRange(
        start: state.startDate,
        end: state.endDate,
      ),
    );
    if (range == null) return;
    ref
        .read(calendarImportControllerProvider.notifier)
        .setDateRange(range.start, range.end);
  }
}

class _PermissionState extends ConsumerWidget {
  const _PermissionState({required this.access});

  final CalendarAccessState access;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final denied = access == CalendarAccessState.denied;
    final restricted = access == CalendarAccessState.restricted;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month_outlined, size: 48),
            const SizedBox(height: 16),
            Text(
              context.strings.get('calendarPermissionTitle'),
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.strings.get(
                restricted
                    ? 'calendarPermissionRestricted'
                    : 'calendarPermissionBody',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (ref.watch(calendarSyncControllerProvider).value != null)
              TextButton(
                onPressed: ref.watch(calendarSyncControllerProvider).isLoading
                    ? null
                    : () => _configureCalendarSync(context, ref, null),
                child: Text(context.strings.get('calendarSyncDisable')),
              ),
            if (!restricted)
              FilledButton(
                key: const Key('request-calendar-permission'),
                onPressed: ref
                    .read(calendarImportControllerProvider.notifier)
                    .requestAccess,
                child: Text(context.strings.get('allowCalendarAccess')),
              ),
            if (denied) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: ref
                    .read(calendarImportControllerProvider.notifier)
                    .openSettings,
                child: Text(context.strings.get('openSettings')),
              ),
            ],
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
          Text(context.strings.get('calendarImportError')),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onRetry,
            child: Text(context.strings.get('retry')),
          ),
        ],
      ),
    );
  }
}

String _date(DateTime value) {
  return '${value.year}.${value.month.toString().padLeft(2, '0')}.'
      '${value.day.toString().padLeft(2, '0')}';
}

Future<void> _configureCalendarSync(
  BuildContext context,
  WidgetRef ref,
  CalendarSyncSettings? settings,
) async {
  final saved = await ref
      .read(calendarSyncControllerProvider.notifier)
      .configure(settings);
  if (!saved && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.strings.get('calendarSettingsSaveError'))),
    );
  }
}
