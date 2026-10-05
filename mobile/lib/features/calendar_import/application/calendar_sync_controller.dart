import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_life/features/calendar_import/application/calendar_import_providers.dart';
import 'package:my_life/features/calendar_import/domain/calendar_import_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CalendarSyncSettings {
  const CalendarSyncSettings({
    required this.ids,
    required this.start,
    required this.end,
  });
  final Set<String> ids;
  final DateTime start;
  final DateTime end;
}

final calendarSyncControllerProvider =
    AsyncNotifierProvider<CalendarSyncController, CalendarSyncSettings?>(
      CalendarSyncController.new,
    );
final calendarSyncResultProvider =
    NotifierProvider<
      CalendarSyncResultController,
      AsyncValue<CalendarImportResult?>
    >(CalendarSyncResultController.new);

class CalendarSyncResultController
    extends Notifier<AsyncValue<CalendarImportResult?>> {
  @override
  AsyncValue<CalendarImportResult?> build() => const AsyncData(null);
  void set(AsyncValue<CalendarImportResult?> result) => state = result;
}

class CalendarSyncController extends AsyncNotifier<CalendarSyncSettings?> {
  static const _key = 'calendar_sync_settings';
  bool _running = false;
  DateTime? _lastRun;

  @override
  Future<CalendarSyncSettings?> build() async {
    final saved = (await SharedPreferences.getInstance()).getString(_key);
    if (saved == null) return null;
    final decoded = jsonDecode(saved) as Map<String, dynamic>;
    return CalendarSyncSettings(
      ids: Set<String>.from(decoded['ids'] as List),
      start: DateTime.parse(decoded['start'] as String),
      end: DateTime.parse(decoded['end'] as String),
    );
  }

  Future<void> configure(CalendarSyncSettings? settings) async {
    final preferences = await SharedPreferences.getInstance();
    if (settings == null) {
      await preferences.remove(_key);
    } else {
      await preferences.setString(
        _key,
        jsonEncode({
          'ids': settings.ids.toList(),
          'start': settings.start.toIso8601String(),
          'end': settings.end.toIso8601String(),
        }),
      );
    }
    state = AsyncData(settings);
    _lastRun = null;
    if (settings != null) await synchronize(force: true);
  }

  Future<void> synchronize({bool force = false}) async {
    if (_running) return;
    final settings = await future;
    if (settings == null || settings.ids.isEmpty) return;
    final now = DateTime.now();
    if (!force &&
        _lastRun != null &&
        now.difference(_lastRun!) < const Duration(minutes: 5)) {
      return;
    }
    _running = true;
    final result = ref.read(calendarSyncResultProvider.notifier);
    result.set(const AsyncLoading());
    try {
      final device = ref.read(calendarDeviceServiceProvider);
      if (await device.checkAccess() != CalendarAccessState.granted) {
        throw StateError('Calendar permission missing');
      }
      final available = (await device.listCalendars()).map((c) => c.id).toSet();
      final ids = settings.ids.intersection(available);
      if (ids.isEmpty) throw StateError('Selected calendar unavailable');
      final events = await device.listEvents(
        start: settings.start,
        inclusiveEnd: settings.end,
        calendarIds: ids,
      );
      // Settings may have been disabled or changed while OS reads were pending.
      if (!identical(state.value, settings)) return;
      final synced = await ref
          .read(calendarImportRepositoryProvider)
          .synchronize(
            events: events,
            calendarIds: ids,
            startDate: _date(settings.start),
            endDate: _date(settings.end),
          );
      _lastRun = now;
      result.set(AsyncData(synced));
    } catch (error, stack) {
      result.set(AsyncError(error, stack));
    } finally {
      _running = false;
    }
  }

  String _date(DateTime date) => date.toIso8601String().split('T').first;
}
