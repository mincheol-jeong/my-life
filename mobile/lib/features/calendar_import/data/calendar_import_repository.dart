import 'dart:convert';

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
                sourceSnapshot: Value(_eventSnapshot(event)),
              ),
            );
        imported++;
      }
    });

    return CalendarImportResult(imported: imported, skipped: skipped);
  }

  Future<CalendarImportResult> synchronize({
    required List<CalendarEventImportDraft> events,
    required Set<String> calendarIds,
    required String startDate,
    required String endDate,
  }) => _database.transaction(() async {
    // Do not reconcile removals unless the caller completed an authoritative
    // OS read for exactly these visible calendars and dates.
    if (calendarIds.isEmpty) {
      return const CalendarImportResult(imported: 0, skipped: 0);
    }
    final scoped = events
        .where(
          (e) =>
              calendarIds.contains(e.calendarId) &&
              e.eventDate.toIso8601String().compareTo(startDate) >= 0 &&
              e.eventDate.toIso8601String().compareTo(endDate) <= 0,
        )
        .toList();
    var updated = 0;
    var removed = 0;
    var protected = 0;
    final now = _clock().toUtc().millisecondsSinceEpoch;
    final existing = await (_database.select(
      _database.calendarImports,
    )..where((m) => m.calendarId.isIn(calendarIds))).get();
    for (final mapping in existing) {
      final record = await (_database.select(
        _database.records,
      )..where((r) => r.id.equals(mapping.recordId))).getSingle();
      if (record.deletedAt != null) continue;
      final editable = mapping.sourceSnapshot == null
          ? record.updatedAt == mapping.importedAt
          : mapping.sourceSnapshot == _recordSnapshot(record);
      final matches = scoped.where(
        (e) =>
            e.calendarId == mapping.calendarId &&
            e.externalInstanceId == mapping.externalInstanceId,
      );
      if (matches.isNotEmpty) {
        final event = matches.first;
        final snapshot = _eventSnapshot(event);
        if (!editable) {
          protected++;
          continue;
        }
        if (_nullableTrim(event.title) == null &&
            _nullableTrim(event.description) == null) {
          continue;
        }
        if (snapshot != _recordSnapshot(record)) {
          await (_database.update(
            _database.records,
          )..where((r) => r.id.equals(record.id))).write(
            RecordsCompanion(
              title: Value(_nullableTrim(event.title)),
              content: Value(_nullableTrim(event.description)),
              placeName: Value(_nullableTrim(event.location)),
              eventDate: Value(event.eventDate.toIso8601String()),
              eventTimeMinutes: Value(event.eventTimeMinutes),
              updatedAt: Value(now),
            ),
          );
          updated++;
        }
        await (_database.update(
          _database.calendarImports,
        )..where((m) => m.recordId.equals(record.id))).write(
          CalendarImportsCompanion(
            sourceSnapshot: Value(snapshot),
            importedAt: Value(now),
          ),
        );
      } else if (record.eventDate.compareTo(startDate) >= 0 &&
          record.eventDate.compareTo(endDate) <= 0) {
        if (!editable) {
          protected++;
          continue;
        }
        await (_database.update(
          _database.records,
        )..where((r) => r.id.equals(record.id))).write(
          RecordsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
        removed++;
      }
    }
    final imported = await importEvents(scoped);
    return CalendarImportResult(
      imported: imported.imported,
      skipped: imported.skipped,
      updated: updated,
      removed: removed,
      protected: protected,
    );
  });

  String _eventSnapshot(CalendarEventImportDraft event) => jsonEncode([
    _nullableTrim(event.title),
    _nullableTrim(event.description),
    event.eventDate.toIso8601String(),
    event.eventTimeMinutes,
    _nullableTrim(event.location),
  ]);

  String _recordSnapshot(RecordRow record) => jsonEncode([
    record.title,
    record.content,
    record.eventDate,
    record.eventTimeMinutes,
    record.placeName,
  ]);

  String? _nullableTrim(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
