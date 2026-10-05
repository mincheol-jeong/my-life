import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_life/core/database/app_database.dart';
import 'package:my_life/core/database/app_database_provider.dart';
import 'package:my_life/features/calendar_import/application/calendar_import_providers.dart';
import 'package:my_life/features/calendar_import/application/calendar_sync_controller.dart';
import 'package:my_life/features/calendar_import/data/calendar_device_service.dart';
import 'package:my_life/features/calendar_import/data/calendar_import_repository.dart';
import 'package:my_life/features/calendar_import/domain/calendar_import_models.dart';
import 'package:my_life/features/record/data/record_repository.dart';
import 'package:my_life/features/record/domain/life_record.dart';
import 'package:my_life/features/record/domain/local_date.dart';
import 'package:shared_preferences/shared_preferences.dart';

CalendarEventImportDraft _event(
  String id,
  String title, {
  String calendar = 'personal',
}) => CalendarEventImportDraft(
  calendarId: calendar,
  externalInstanceId: id,
  title: title,
  eventDate: LocalDate(2026, 10, 5),
  isAllDay: false,
  eventTimeMinutes: 720,
);

void main() {
  late AppDatabase database;
  late CalendarImportRepository repository;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase(NativeDatabase.memory());
    repository = CalendarImportRepository(database);
  });
  tearDown(() => database.close());
  Future<CalendarImportResult> sync(
    List<CalendarEventImportDraft> events, {
    Set<String> ids = const {'personal'},
  }) => repository.synchronize(
    events: events,
    calendarIds: ids,
    startDate: '2026-10-01',
    endDate: '2026-10-31',
  );

  test(
    'reflects source additions, edits and removals without duplicate records',
    () async {
      expect((await sync([_event('one', 'First')])).imported, 1);
      expect((await sync([_event('one', 'Edited')])).updated, 1);
      expect(
        (await database.select(database.records).get()).single.title,
        'Edited',
      );
      expect((await sync([_event('one', 'Edited')])).updated, 0);
      expect((await sync([])).removed, 1);
      expect(
        (await database.select(database.records).get()).single.deletedAt,
        isNotNull,
      );
      expect((await sync([_event('one', 'Restored')])).imported, 0);
    },
  );
  test('protects local edits and local deletions', () async {
    await sync([_event('one', 'Original')]);
    final record = (await database.select(database.records).get()).single;
    await RecordRepository(database).updateMemo(
      record.id,
      MemoDraft(title: 'My edit', eventDate: LocalDate(2026, 10, 5)),
    );
    expect((await sync([_event('one', 'Remote edit')])).protected, 1);
    expect((await sync([])).protected, 1);
    expect(
      (await database.select(database.records).get()).single.title,
      'My edit',
    );
    await RecordRepository(database).softDelete(record.id);
    await sync([_event('one', 'Another edit')]);
    expect(await RecordRepository(database).getById(record.id), isNull);
  });
  test(
    'does not remove records from other calendars or outside range',
    () async {
      await repository.importEvents([
        _event('one', 'Other', calendar: 'work'),
        CalendarEventImportDraft(
          calendarId: 'personal',
          externalInstanceId: 'past',
          title: 'Past',
          eventDate: LocalDate(2026, 9, 30),
          isAllDay: true,
        ),
      ]);
      expect((await sync([])).removed, 0);
      expect((await sync([], ids: {})).removed, 0);
    },
  );
  test('automatic controller does nothing until explicit opt-in and persists settings', () async {
    final device = _FakeCalendar();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        calendarDeviceServiceProvider.overrideWithValue(device),
      ],
    );
    addTearDown(container.dispose);
    await container.read(calendarSyncControllerProvider.future);
    final controller = container.read(calendarSyncControllerProvider.notifier);
    await controller.synchronize(force: true);
    expect(device.reads, 0);
    await controller.configure(
      CalendarSyncSettings(
        ids: {'personal'},
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 31),
      ),
    );
    expect(device.reads, 1);
    expect(
      (await database.select(database.records).get()).single.title,
      'Source',
    );
    expect(
      (await SharedPreferences.getInstance()).getString(
        'calendar_sync_settings',
      ),
      isNotNull,
    );
    await controller.configure(null);
    await controller.synchronize(force: true);
    expect(device.reads, 1);
    expect(
      (await SharedPreferences.getInstance()).getString(
        'calendar_sync_settings',
      ),
      isNull,
    );
  });
  test(
    'OS read failure or revoked permission preserves previously synced records',
    () async {
      final device = _FakeCalendar();
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          calendarDeviceServiceProvider.overrideWithValue(device),
        ],
      );
      addTearDown(container.dispose);
      await container.read(calendarSyncControllerProvider.future);
      final controller = container.read(
        calendarSyncControllerProvider.notifier,
      );
      await controller.configure(
        CalendarSyncSettings(
          ids: {'personal'},
          start: DateTime(2026, 10, 1),
          end: DateTime(2026, 10, 31),
        ),
      );
      device.fail = true;
      await controller.synchronize(force: true);
      expect(container.read(calendarSyncResultProvider).hasError, isTrue);
      expect(
        (await database.select(database.records).get()).single.deletedAt,
        isNull,
      );
      device.fail = false;
      device.access = CalendarAccessState.denied;
      await controller.synchronize(force: true);
      expect(
        (await database.select(database.records).get()).single.deletedAt,
        isNull,
      );
    },
  );
}

class _FakeCalendar extends CalendarDeviceService {
  int reads = 0;
  bool fail = false;
  CalendarAccessState access = CalendarAccessState.granted;
  @override
  Future<CalendarAccessState> checkAccess() async => access;
  @override
  Future<List<DeviceCalendarInfo>> listCalendars() async => [
    const DeviceCalendarInfo(id: 'personal', name: 'Personal', isPrimary: true),
  ];
  @override
  Future<List<CalendarEventImportDraft>> listEvents({
    required DateTime start,
    required DateTime inclusiveEnd,
    required Set<String> calendarIds,
  }) async {
    reads++;
    if (fail) throw StateError('OS calendar failed');
    return [_event('source', 'Source')];
  }
}
