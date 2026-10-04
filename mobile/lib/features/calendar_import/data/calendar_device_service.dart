import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:my_life/features/calendar_import/domain/calendar_import_models.dart';
import 'package:my_life/features/record/domain/local_date.dart';

class CalendarDeviceService {
  CalendarDeviceService({DeviceCalendar? calendar})
    : _calendar = calendar ?? DeviceCalendar.instance;

  final DeviceCalendar _calendar;

  Future<CalendarAccessState> checkAccess() async {
    return _mapAccess(await _calendar.hasPermissions());
  }

  Future<CalendarAccessState> requestAccess() async {
    return _mapAccess(await _calendar.requestPermissions());
  }

  Future<void> openSettings() => _calendar.openAppSettings();

  Future<List<DeviceCalendarInfo>> listCalendars() async {
    final calendars = await _calendar.listCalendars();
    return calendars
        .where((calendar) => !calendar.hidden)
        .map(
          (calendar) => DeviceCalendarInfo(
            id: calendar.id,
            name: calendar.name,
            isPrimary: calendar.isPrimary,
          ),
        )
        .toList(growable: false);
  }

  Future<List<CalendarEventImportDraft>> listEvents({
    required DateTime start,
    required DateTime inclusiveEnd,
    required Set<String> calendarIds,
  }) async {
    final events = await _calendar.listEvents(
      DateTime(start.year, start.month, start.day),
      DateTime(
        inclusiveEnd.year,
        inclusiveEnd.month,
        inclusiveEnd.day,
      ).add(const Duration(days: 1)),
      calendarIds: calendarIds.toList(growable: false),
    );
    return events
        .where((event) => event.status != EventStatus.canceled)
        .map((event) {
          final localStart = event.startDate.toLocal();
          return CalendarEventImportDraft(
            calendarId: event.calendarId,
            externalInstanceId: event.instanceId,
            title: event.title,
            description: event.description,
            location: event.location,
            eventDate: LocalDate.fromDateTime(localStart),
            isAllDay: event.isAllDay,
            eventTimeMinutes: event.isAllDay
                ? null
                : localStart.hour * 60 + localStart.minute,
          );
        })
        .toList(growable: false);
  }

  CalendarAccessState _mapAccess(CalendarPermissionStatus status) {
    return switch (status) {
      CalendarPermissionStatus.granted => CalendarAccessState.granted,
      CalendarPermissionStatus.denied ||
      CalendarPermissionStatus.writeOnly => CalendarAccessState.denied,
      CalendarPermissionStatus.restricted => CalendarAccessState.restricted,
      CalendarPermissionStatus.notDetermined =>
        CalendarAccessState.notDetermined,
    };
  }
}
