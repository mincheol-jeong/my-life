import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_life/core/database/app_database.dart';
import 'package:my_life/features/calendar_import/data/calendar_import_repository.dart';
import 'package:my_life/features/calendar_import/domain/calendar_import_models.dart';
import 'package:my_life/features/record/data/record_repository.dart';
import 'package:my_life/features/record/domain/local_date.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('imports calendar events as memo records', () async {
    final ids = ['record-1', 'record-2'].iterator;
    final repository = CalendarImportRepository(
      database,
      clock: () => DateTime.utc(2026, 9, 30),
      idGenerator: () {
        ids.moveNext();
        return ids.current;
      },
    );

    final result = await repository.importEvents([
      CalendarEventImportDraft(
        calendarId: 'work',
        externalInstanceId: 'event-1@2026-09-30',
        title: 'Design review',
        description: 'Review the first draft',
        location: 'Seoul',
        eventDate: LocalDate(2026, 9, 30),
        isAllDay: false,
        eventTimeMinutes: 14 * 60,
      ),
      CalendarEventImportDraft(
        calendarId: 'personal',
        externalInstanceId: 'event-2@2026-10-01',
        title: 'Holiday',
        eventDate: LocalDate(2026, 10, 1),
        isAllDay: true,
      ),
    ]);

    expect(result.imported, 2);
    expect(result.skipped, 0);
    final first = await RecordRepository(database).getById('record-1');
    expect(first?.title, 'Design review');
    expect(first?.content, 'Review the first draft');
    expect(first?.placeName, 'Seoul');
    expect(first?.eventTimeMinutes, 840);
    final second = await RecordRepository(database).getById('record-2');
    expect(second?.eventTimeMinutes, isNull);
  });

  test('skips a previously imported occurrence and an empty event', () async {
    final repository = CalendarImportRepository(
      database,
      idGenerator: () => 'record-1',
    );
    final event = CalendarEventImportDraft(
      calendarId: 'work',
      externalInstanceId: 'recurring@2026-09-30',
      title: 'Standup',
      eventDate: LocalDate(2026, 9, 30),
      isAllDay: false,
      eventTimeMinutes: 600,
    );

    expect((await repository.importEvents([event])).imported, 1);
    final secondResult = await repository.importEvents([
      event,
      CalendarEventImportDraft(
        calendarId: 'work',
        externalInstanceId: 'empty',
        title: '   ',
        eventDate: LocalDate(2026, 9, 30),
        isAllDay: true,
      ),
    ]);

    expect(secondResult.imported, 0);
    expect(secondResult.skipped, 2);
    expect(await database.select(database.records).get(), hasLength(1));
    expect(await database.select(database.calendarImports).get(), hasLength(1));
  });
}
