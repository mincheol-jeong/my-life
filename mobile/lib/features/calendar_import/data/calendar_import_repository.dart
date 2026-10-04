import 'package:drift/drift.dart';
import 'package:my_life/core/database/app_database.dart';
import 'package:my_life/features/calendar_import/domain/calendar_import_models.dart';
import 'package:my_life/features/record/data/record_repository.dart';
import 'package:my_life/features/record/domain/life_record.dart';
import 'package:uuid/uuid.dart';

class CalendarImportRepository {
  CalendarImportRepository(
    this._database, {
    UtcClock? clock,
    IdGenerator? idGenerator,
  }) : _clock = clock ?? (() => DateTime.now().toUtc()),
       _idGenerator = idGenerator ?? const Uuid().v4;

  final AppDatabase _database;
  final UtcClock _clock;
  final IdGenerator _idGenerator;

  Future<CalendarImportResult> importEvents(
    List<CalendarEventImportDraft> events,
  ) async {
    var imported = 0;
    var skipped = 0;
    final now = _clock().toUtc().millisecondsSinceEpoch;

    await _database.transaction(() async {
      for (final event in events) {
        final existing =
            await (_database.select(_database.calendarImports)..where(
                  (row) =>
                      row.calendarId.equals(event.calendarId) &
                      row.externalInstanceId.equals(event.externalInstanceId),
                ))
                .getSingleOrNull();
        if (existing != null) {
          skipped++;
          continue;
        }

        final title = _nullableTrim(event.title);
        final description = _nullableTrim(event.description);
        if (title == null && description == null) {
          skipped++;
          continue;
        }

        final recordId = _idGenerator();
        await _database
            .into(_database.records)
            .insert(
              RecordsCompanion.insert(
                id: recordId,
                type: RecordType.memo.databaseValue,
                title: Value(title),
                content: Value(description),
                eventDate: event.eventDate.toIso8601String(),
                eventTimeMinutes: Value(event.eventTimeMinutes),
                placeName: Value(_nullableTrim(event.location)),
                createdAt: now,
                updatedAt: now,
              ),
            );
        await _database
            .into(_database.calendarImports)
            .insert(
              CalendarImportsCompanion.insert(
                recordId: recordId,
                calendarId: event.calendarId,
                externalInstanceId: event.externalInstanceId,
                importedAt: now,
              ),
            );
        imported++;
      }
    });

    return CalendarImportResult(imported: imported, skipped: skipped);
  }

  String? _nullableTrim(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
