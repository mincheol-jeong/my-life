import 'package:drift/drift.dart';
import 'package:my_life/core/database/app_database.dart';
import 'package:my_life/features/record/data/record_row_mapper.dart';
import 'package:my_life/features/record/domain/life_record.dart';
import 'package:uuid/uuid.dart';

typedef UtcClock = DateTime Function();
typedef IdGenerator = String Function();

class RecordRepository {
  RecordRepository(this._database, {UtcClock? clock, IdGenerator? idGenerator})
    : _clock = clock ?? (() => DateTime.now().toUtc()),
      _idGenerator = idGenerator ?? const Uuid().v4;

  final AppDatabase _database;
  final UtcClock _clock;
  final IdGenerator _idGenerator;

  Future<LifeRecord> createMemo(MemoDraft draft) async {
    final normalized = _normalizeAndValidate(draft);
    final now = _clock().toUtc();
    final id = _idGenerator();

    await _database
        .into(_database.records)
        .insert(
          RecordsCompanion.insert(
            id: id,
            type: RecordType.memo.databaseValue,
            title: Value(normalized.title),
            content: Value(normalized.content),
            eventDate: normalized.eventDate.toIso8601String(),
            eventTimeMinutes: Value(normalized.eventTimeMinutes),
            placeName: Value(normalized.placeName),
            createdAt: now.millisecondsSinceEpoch,
            updatedAt: now.millisecondsSinceEpoch,
          ),
        );

    return (await getById(id))!;
  }

  Future<LifeRecord?> getById(String id) async {
    final query = _database.select(_database.records)
      ..where((record) => record.id.equals(id) & record.deletedAt.isNull());
    return (await query.getSingleOrNull())?.toDomain();
  }

  Stream<LifeRecord?> watchById(String id) {
    final query = _database.select(_database.records)
      ..where((record) => record.id.equals(id) & record.deletedAt.isNull());
    return query.watchSingleOrNull().map((row) => row?.toDomain());
  }

  Future<LifeRecord> updateMemo(String id, MemoDraft draft) async {
    final existing = await getById(id);
    if (existing == null || existing.type != RecordType.memo) {
      throw RecordNotFoundException(id);
    }

    final normalized = _normalizeAndValidate(draft);
    final updatedAt = _clock().toUtc();
    final affected =
        await (_database.update(_database.records)..where(
              (record) => record.id.equals(id) & record.deletedAt.isNull(),
            ))
            .write(
              RecordsCompanion(
                title: Value(normalized.title),
                content: Value(normalized.content),
                eventDate: Value(normalized.eventDate.toIso8601String()),
                eventTimeMinutes: Value(normalized.eventTimeMinutes),
                placeName: Value(normalized.placeName),
                updatedAt: Value(updatedAt.millisecondsSinceEpoch),
              ),
            );

    if (affected != 1) {
      throw RecordNotFoundException(id);
    }
    return (await getById(id))!;
  }

  Future<void> softDelete(String id) async {
    final deletedAt = _clock().toUtc().millisecondsSinceEpoch;
    final affected =
        await (_database.update(_database.records)..where(
              (record) => record.id.equals(id) & record.deletedAt.isNull(),
            ))
            .write(
              RecordsCompanion(
                updatedAt: Value(deletedAt),
                deletedAt: Value(deletedAt),
              ),
            );

    if (affected != 1) {
      throw RecordNotFoundException(id);
    }
  }

  MemoDraft _normalizeAndValidate(MemoDraft draft) {
    final title = _nullableTrim(draft.title);
    final content = _nullableTrim(draft.content);
    final placeName = _nullableTrim(draft.placeName);

    if (title == null && content == null) {
      throw const MemoValidationException('제목 또는 내용을 입력해주세요.');
    }
    final minutes = draft.eventTimeMinutes;
    if (minutes != null && (minutes < 0 || minutes > 1439)) {
      throw const MemoValidationException('시간 값이 올바르지 않습니다.');
    }

    return MemoDraft(
      title: title,
      content: content,
      eventDate: draft.eventDate,
      eventTimeMinutes: minutes,
      placeName: placeName,
    );
  }

  String? _nullableTrim(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
