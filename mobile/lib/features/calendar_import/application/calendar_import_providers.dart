import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_life/core/database/app_database_provider.dart';
import 'package:my_life/features/calendar_import/data/calendar_device_service.dart';
import 'package:my_life/features/calendar_import/data/calendar_import_repository.dart';
import 'package:my_life/features/calendar_import/domain/calendar_import_models.dart';

class CalendarImportState {
  const CalendarImportState({
    required this.access,
    required this.startDate,
    required this.endDate,
    this.calendars = const [],
    this.selectedCalendarIds = const {},
    this.lastResult,
  });

  final CalendarAccessState access;
  final DateTime startDate;
  final DateTime endDate;
  final List<DeviceCalendarInfo> calendars;
  final Set<String> selectedCalendarIds;
  final CalendarImportResult? lastResult;

  CalendarImportState copyWith({
    CalendarAccessState? access,
    DateTime? startDate,
    DateTime? endDate,
    List<DeviceCalendarInfo>? calendars,
    Set<String>? selectedCalendarIds,
    CalendarImportResult? lastResult,
    bool clearResult = false,
  }) {
    return CalendarImportState(
      access: access ?? this.access,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      calendars: calendars ?? this.calendars,
      selectedCalendarIds: selectedCalendarIds ?? this.selectedCalendarIds,
      lastResult: clearResult ? null : lastResult ?? this.lastResult,
    );
  }
}

final calendarDeviceServiceProvider = Provider<CalendarDeviceService>((ref) {
  return CalendarDeviceService();
});

final calendarImportRepositoryProvider = Provider<CalendarImportRepository>((
  ref,
) {
  return CalendarImportRepository(ref.watch(appDatabaseProvider));
});

final calendarImportControllerProvider =
    AsyncNotifierProvider.autoDispose<
      CalendarImportController,
      CalendarImportState
    >(CalendarImportController.new);

class CalendarImportController extends AsyncNotifier<CalendarImportState> {
  @override
  Future<CalendarImportState> build() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final access = await ref.read(calendarDeviceServiceProvider).checkAccess();
    final initial = CalendarImportState(
      access: access,
      startDate: today.subtract(const Duration(days: 30)),
      endDate: today.add(const Duration(days: 90)),
    );
    if (access != CalendarAccessState.granted) return initial;
    return _withCalendars(initial);
  }

  Future<void> requestAccess() async {
    final current = state.value;
    if (current == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final access = await ref
          .read(calendarDeviceServiceProvider)
          .requestAccess();
      final updated = current.copyWith(access: access, clearResult: true);
      return access == CalendarAccessState.granted
          ? _withCalendars(updated)
          : updated;
    });
  }

  Future<void> openSettings() {
    return ref.read(calendarDeviceServiceProvider).openSettings();
  }

  void toggleCalendar(String id, bool selected) {
    final current = state.value;
    if (current == null) return;
    final ids = {...current.selectedCalendarIds};
    selected ? ids.add(id) : ids.remove(id);
    state = AsyncData(
      current.copyWith(selectedCalendarIds: ids, clearResult: true),
    );
  }

  void setDateRange(DateTime start, DateTime end) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(startDate: start, endDate: end, clearResult: true),
    );
  }

  Future<void> importSelected() async {
    final current = state.value;
    if (current == null || current.selectedCalendarIds.isEmpty) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final events = await ref
          .read(calendarDeviceServiceProvider)
          .listEvents(
            start: current.startDate,
            inclusiveEnd: current.endDate,
            calendarIds: current.selectedCalendarIds,
          );
      final result = await ref
          .read(calendarImportRepositoryProvider)
          .importEvents(events);
      return current.copyWith(lastResult: result);
    });
  }

  Future<CalendarImportState> _withCalendars(
    CalendarImportState current,
  ) async {
    final calendars = await ref
        .read(calendarDeviceServiceProvider)
        .listCalendars();
    final selected = calendars
        .where((calendar) => calendar.isPrimary)
        .map((calendar) => calendar.id)
        .toSet();
    return current.copyWith(
      calendars: calendars,
      selectedCalendarIds: selected,
    );
  }
}
