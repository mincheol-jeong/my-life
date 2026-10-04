import 'package:drift/drift.dart';
import 'package:my_life/core/database/app_database.dart';
import 'package:my_life/features/photo/data/photo_storage.dart';
import 'package:my_life/features/photo/domain/photo_record.dart';
import 'package:my_life/features/record/data/record_repository.dart';
import 'package:my_life/features/record/data/record_row_mapper.dart';
import 'package:my_life/features/record/domain/life_record.dart';
import 'package:uuid/uuid.dart';

class PhotoRepository {
  PhotoRepository(
    this._database,
    this._storage, {
    UtcClock? clock,
    IdGenerator? idGenerator,
  }) : _clock = clock ?? (() => DateTime.now().toUtc()),
       _idGenerator = idGenerator ?? const Uuid().v4;

  final AppDatabase _database;
  final PhotoStorage _storage;
  final UtcClock _clock;
  final IdGenerator _idGenerator;

  Future<PhotoRecord> create(PhotoDraft draft, List<String> sourcePaths) async {
    final normalized = _normalizeAndValidate(draft);
    if (sourcePaths.isEmpty) {
      throw const PhotoValidationException('사진을 한 장 이상 선택해주세요.');
    }
    final recordId = _idGenerator();
    final photoIds = List.generate(sourcePaths.length, (_) => _idGenerator());
    final prepared = await _storage.preparePhotos(
      recordId: recordId,
      photoIds: photoIds,
      sourcePaths: sourcePaths,
    );
    final now = _clock().toUtc().millisecondsSinceEpoch;

    try {
      await _database.transaction(() async {
        await _database
            .into(_database.records)
            .insert(
              RecordsCompanion.insert(
                id: recordId,
                type: RecordType.photo.databaseValue,
                title: Value(normalized.title),
                content: const Value(null),
                eventDate: normalized.eventDate.toIso8601String(),
                eventTimeMinutes: Value(normalized.eventTimeMinutes),
                placeName: Value(normalized.placeName),
                createdAt: now,
                updatedAt: now,
              ),
            );
        for (var index = 0; index < prepared.length; index++) {
          final photo = prepared[index];
          await _database
              .into(_database.photos)
              .insert(
                PhotosCompanion.insert(
                  id: photo.id,
                  recordId: recordId,
                  filePath: photo.filePath,
                  thumbnailPath: Value(photo.thumbnailPath),
                  width: Value(photo.width),
                  height: Value(photo.height),
                  sortOrder: index,
                ),
              );
        }
      });
    } catch (_) {
      await _storage.deleteRecordFiles(recordId);
      rethrow;
    }
    return (await getById(recordId))!;
  }

  Future<PhotoRecord?> getById(String recordId) async {
    return _mapRows(await _activePhotoQuery(recordId).get());
  }

  Stream<PhotoRecord?> watchById(String recordId) {
    return _activePhotoQuery(recordId).watch().map(_mapRows);
  }

  Future<PhotoRecord> updateMetadata(String recordId, PhotoDraft draft) async {
    final normalized = _normalizeAndValidate(draft);
    final updatedAt = _clock().toUtc().millisecondsSinceEpoch;
    final affected =
        await (_database.update(_database.records)..where(
              (record) =>
                  record.id.equals(recordId) &
                  record.type.equals(RecordType.photo.databaseValue) &
                  record.deletedAt.isNull(),
            ))
            .write(
              RecordsCompanion(
                title: Value(normalized.title),
                eventDate: Value(normalized.eventDate.toIso8601String()),
                eventTimeMinutes: Value(normalized.eventTimeMinutes),
                placeName: Value(normalized.placeName),
                updatedAt: Value(updatedAt),
              ),
            );
    if (affected != 1) throw RecordNotFoundException(recordId);
    return (await getById(recordId))!;
  }

  Future<void> deletePhoto(String recordId, String photoId) async {
    final record = await getById(recordId);
    if (record == null) throw RecordNotFoundException(recordId);
    if (record.photos.length <= 1) throw const LastPhotoDeletionException();
    final photo = record.photos.where((item) => item.id == photoId).firstOrNull;
    if (photo == null) throw RecordNotFoundException(photoId);
    final staged = await _storage.stageDeletion([
      photo.filePath,
      photo.thumbnailPath,
    ]);

    try {
      await _database.transaction(() async {
        final removed = await (_database.delete(
          _database.photos,
        )..where((row) => row.id.equals(photoId))).go();
        if (removed != 1) throw RecordNotFoundException(photoId);

        final remaining =
            await (_database.select(_database.photos)
                  ..where((row) => row.recordId.equals(recordId))
                  ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]))
                .get();
        for (var index = 0; index < remaining.length; index++) {
          await (_database.update(_database.photos)
                ..where((row) => row.id.equals(remaining[index].id)))
              .write(PhotosCompanion(sortOrder: Value(index)));
        }
        await _touchRecord(recordId);
      });
    } catch (_) {
      await staged.rollback();
      rethrow;
    }
    await staged.commit();
  }

  Future<void> deleteRecord(String recordId) async {
    final record = await getById(recordId);
    if (record == null) throw RecordNotFoundException(recordId);
    final staged = await _storage.stageDeletion(
      record.photos.expand((photo) => [photo.filePath, photo.thumbnailPath]),
    );
    final deletedAt = _clock().toUtc().millisecondsSinceEpoch;
    try {
      await _database.transaction(() async {
        final affected =
            await (_database.update(_database.records)..where(
                  (row) =>
                      row.id.equals(recordId) &
                      row.type.equals(RecordType.photo.databaseValue) &
                      row.deletedAt.isNull(),
                ))
                .write(
                  RecordsCompanion(
                    updatedAt: Value(deletedAt),
                    deletedAt: Value(deletedAt),
                  ),
                );
        if (affected != 1) throw RecordNotFoundException(recordId);
        await (_database.delete(
          _database.photos,
        )..where((row) => row.recordId.equals(recordId))).go();
      });
    } catch (_) {
      await staged.rollback();
      rethrow;
    }
    await staged.commit();
    await _storage.deleteRecordFiles(recordId);
  }

  Selectable<TypedResult> _activePhotoQuery(String recordId) {
    return (_database.select(_database.records).join([
        innerJoin(
          _database.photos,
          _database.photos.recordId.equalsExp(_database.records.id),
        ),
      ])..where(
        _database.records.id.equals(recordId) &
            _database.records.type.equals(RecordType.photo.databaseValue) &
            _database.records.deletedAt.isNull(),
      ))
      ..orderBy([OrderingTerm.asc(_database.photos.sortOrder)]);
  }

  PhotoRecord? _mapRows(List<TypedResult> rows) {
    if (rows.isEmpty) return null;
    final record = rows.first.readTable(_database.records).toDomain();
    final photos = rows
        .map((row) => row.readTable(_database.photos))
        .map(
          (photo) => StoredPhoto(
            id: photo.id,
            recordId: photo.recordId,
            filePath: photo.filePath,
            thumbnailPath: photo.thumbnailPath,
            width: photo.width,
            height: photo.height,
            sortOrder: photo.sortOrder,
          ),
        )
        .toList(growable: false);
    return PhotoRecord(record: record, photos: photos);
  }

  PhotoDraft _normalizeAndValidate(PhotoDraft draft) {
    final title = draft.title?.trim();
    final minutes = draft.eventTimeMinutes;
    if (minutes != null && (minutes < 0 || minutes > 1439)) {
      throw const PhotoValidationException('시간 값이 올바르지 않습니다.');
    }
    return PhotoDraft(
      title: title == null || title.isEmpty ? null : title,
      eventDate: draft.eventDate,
      eventTimeMinutes: minutes,
      placeName: _nullableTrim(draft.placeName),
    );
  }

  String? _nullableTrim(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _touchRecord(String recordId) async {
    final affected =
        await (_database.update(
              _database.records,
            )..where((row) => row.id.equals(recordId) & row.deletedAt.isNull()))
            .write(
              RecordsCompanion(
                updatedAt: Value(_clock().toUtc().millisecondsSinceEpoch),
              ),
            );
    if (affected != 1) throw RecordNotFoundException(recordId);
  }
}
