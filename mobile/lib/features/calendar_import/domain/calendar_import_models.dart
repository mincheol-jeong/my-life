import 'package:my_life/features/record/domain/local_date.dart';

enum CalendarAccessState { granted, denied, restricted, notDetermined }

class DeviceCalendarInfo {
  const DeviceCalendarInfo({
    required this.id,
    required this.name,
    required this.isPrimary,
  });

  final String id;
  final String name;
  final bool isPrimary;
}

class CalendarEventImportDraft {
  const CalendarEventImportDraft({
    required this.calendarId,
    required this.externalInstanceId,
    required this.title,
    required this.eventDate,
    required this.isAllDay,
    this.description,
    this.location,
    this.eventTimeMinutes,
  });

  final String calendarId;
  final String externalInstanceId;
  final String title;
  final String? description;
  final String? location;
  final LocalDate eventDate;
  final bool isAllDay;
  final int? eventTimeMinutes;
}

class CalendarImportResult {
  const CalendarImportResult({required this.imported, required this.skipped});

  final int imported;
  final int skipped;
}
