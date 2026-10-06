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

final calendarSyncSettingsWriterProvider =
    Provider<Future<bool> Function(String?)>((ref) {
      return (encoded) async {
        final preferences = await SharedPreferences.getInstance();
        return encoded == null
            ? preferences.remove('calendar_sync_settings')
            : preferences.setString('calendar_sync_settings', encoded);
      };
    });
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
  bool _configuring = false;
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

  Future<bool> configure(CalendarSyncSettings? settings) async {
    if (_configuring) return false;
    _configuring = true;
    final previous = state.value;
    state = const AsyncLoading();
    try {
      final saved = await ref.read(calendarSyncSettingsWriterProvider)(
        settings == null
            ? null
            : jsonEncode({
                'ids': settings.ids.toList(),
                'start': settings.start.toIso8601String(),
                'end': settings.end.toIso8601String(),
              }),
      );
      if (!saved) throw StateError('Calendar settings could not be saved');
      if (!ref.mounted) return false;
      state = AsyncData(settings);
      _lastRun = null;
      ref.read(calendarSyncResultProvider.notifier).set(const AsyncData(null));
    } catch (error, stack) {
      if (ref.mounted) {
        state = AsyncData(previous);
        ref
            .read(calendarSyncResultProvider.notifier)
            .set(AsyncError(error, stack));
      }
      return false;
    } finally {
      _configuring = false;
    }
    if (settings != null) await synchronize(force: true);
    return true;
  }

  Future<void> synchronize({bool force = false}) async {
    if (_running || _configuring) return;
    _running = true;
    try {
      final settings = await future;
      if (!ref.mounted ||
          _configuring ||
          settings == null ||
          settings.ids.isEmpty) {
        return;
      }
      final now = DateTime.now();
      if (!force &&
          _lastRun != null &&
          now.difference(_lastRun!) < const Duration(minutes: 5)) {
        return;
      }
      final result = ref.read(calendarSyncResultProvider.notifier);
      result.set(const AsyncLoading());
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
      if (!ref.mounted || _configuring || !identical(state.value, settings)) {
        return;
      }
      final synced = await ref
          .read(calendarImportRepositoryProvider)
          .synchronize(
            events: events,
            calendarIds: ids,
            startDate: _date(settings.start),
            endDate: _date(settings.end),
          );
      if (!ref.mounted || _configuring || !identical(state.value, settings)) {
        return;
      }
      _lastRun = now;
      result.set(AsyncData(synced));
    } catch (error, stack) {
      if (ref.mounted) {
        ref
            .read(calendarSyncResultProvider.notifier)
            .set(AsyncError(error, stack));
      }
    } finally {
      _running = false;
    }
  }

  String _date(DateTime date) => date.toIso8601String().split('T').first;
}
