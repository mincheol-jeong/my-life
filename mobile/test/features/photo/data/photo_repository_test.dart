import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
import 'package:my_life/core/database/app_database.dart';
import 'package:my_life/features/photo/data/photo_repository.dart';
import 'package:my_life/features/photo/data/photo_storage.dart';
import 'package:my_life/features/photo/domain/photo_record.dart';
import 'package:my_life/features/record/domain/local_date.dart';

void main() {
  late Directory directory;
  late AppDatabase database;
  late PhotoStorage storage;
  late PhotoRepository repository;
  late List<String> ids;
  final now = DateTime.utc(2026, 10, 1, 2, 3, 4);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('my_life_photos_');
    database = AppDatabase(NativeDatabase.memory());
    storage = PhotoStorage(directoryLoader: () async => directory);
    ids = ['record-1', 'photo-1', 'photo-2', 'record-2', 'photo-3'];
    repository = PhotoRepository(
      database,
      storage,
      clock: () => now,
      idGenerator: () => ids.removeAt(0),
    );
  });

  tearDown(() async {
    await database.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  PhotoDraft draft() => PhotoDraft(
    title: '  주말  ',
    eventDate: LocalDate(2026, 10, 1),
    eventTimeMinutes: 12 * 60,
    placeName: '  Seoul  ',
  );

  Future<File> source(String name, int color) async {
    final image = image_lib.Image(width: 24, height: 16);
    image_lib.fill(image, color: image_lib.ColorRgb8(color, 20, 30));
    final file = File('${directory.path}/$name.png');
    await file.writeAsBytes(image_lib.encodePng(image));
    return file;
  }

  test('concurrent deletes cannot remove the last photo and queue survives rejection', () async {
    final first = await source('first', 100);
    final second = await source('second', 150);
    final record = await repository.create(draft(), [first.path, second.path]);
    final outcomes = await Future.wait([
      for (final photo in record.photos)
        repository
            .deletePhoto(record.record.id, photo.id)
            .then<Object?>((_) => null, onError: (Object error) => error),
    ]);
    expect(outcomes.where((value) => value == null), hasLength(1));
    expect(outcomes.whereType<LastPhotoDeletionException>(), hasLength(1));
    final remaining = (await repository.getById(record.record.id))!;
    expect(remaining.photos, hasLength(1));
    expect(
      await File(await storage.absolutePath(remaining.photos.single.filePath))
          .exists(),
      isTrue,
    );
    expect(await first.exists(), isTrue);
    expect(await second.exists(), isTrue);
    await repository.deleteRecord(record.record.id);
    expect(await repository.getById(record.record.id), isNull);
  });

  test(
    'copies originals, creates thumbnails, and stores ordered rows',
    () async {
      final first = await source('first', 100);
      final second = await source('second', 150);

      final record = await repository.create(draft(), [
        first.path,
        second.path,
      ]);

      expect(record.record.id, 'record-1');
      expect(record.record.title, '주말');
      expect(record.record.placeName, 'Seoul');
      expect(record.photos.map((photo) => photo.sortOrder), [0, 1]);
      expect(record.photos.first.width, 24);
      expect(record.photos.first.height, 16);
      for (final photo in record.photos) {
        expect(
          await File(await storage.absolutePath(photo.filePath)).exists(),
          isTrue,
        );
        expect(
          await File(await storage.absolutePath(photo.thumbnailPath!)).exists(),
          isTrue,
        );
      }
      expect(await first.exists(), isTrue);
      expect(await second.exists(), isTrue);
    },
  );

  test(
    'interrupted deletion before DB commit restores originals on next access',
    () async {
      final first = await source('first', 100);
      final second = await source('second', 150);
      final record = await repository.create(draft(), [
        first.path,
        second.path,
      ]);
      final photo = record.photos.first;
      await storage.stageDeletion([photo.filePath, photo.thumbnailPath]);
      expect(
        await File(await storage.absolutePath(photo.filePath)).exists(),
        false,
      );
      repository = PhotoRepository(database, storage);
      await repository.recoverInterruptedOperations();
      expect(
        await File(await storage.absolutePath(photo.filePath)).exists(),
        true,
      );
      expect(
        await File(await storage.absolutePath(photo.thumbnailPath!)).exists(),
        true,
      );
      expect((await repository.getById(record.record.id))!.photos.length, 2);
      await repository.recoverInterruptedOperations();
      expect(await first.exists(), true);
    },
  );

  test('interrupted deletion after DB commit purges only app copies', () async {
    final original = await source('first', 100);
    final record = await repository.create(draft(), [original.path]);
    await storage.stageDeletion(
      record.photos.expand((p) => [p.filePath, p.thumbnailPath]),
    );
    await database.transaction(() async {
      await (database.update(database.records)
            ..where((r) => r.id.equals(record.record.id)))
          .write(const RecordsCompanion(deletedAt: Value(1)));
      await (database.delete(
        database.photos,
      )..where((p) => p.recordId.equals(record.record.id))).go();
    });
    repository = PhotoRepository(database, storage);
    await repository.recoverInterruptedOperations();
    expect(
      await Directory(
        '${directory.path}/my_life/photos/records/${record.record.id}',
      ).exists(),
      false,
    );
    expect(
      await Directory('${directory.path}/my_life/photos/.trash')
          .list()
          .toList(),
      isEmpty,
    );
    expect(await original.exists(), true);
  });

  test(
    'interrupted creation removes an uncommitted directory, not active photos',
    () async {
      final original = await source('first', 100);
      final record = await repository.create(draft(), [original.path]);
      await storage.preparePhotos(
        recordId: 'not-committed',
        photoIds: ['orphan'],
        sourcePaths: [original.path],
      );
      repository = PhotoRepository(database, storage);
      await repository.recoverInterruptedOperations();
      expect(
        await Directory(
          '${directory.path}/my_life/photos/records/not-committed',
        ).exists(),
        false,
      );
      expect(
        await File(await storage.absolutePath(record.photos.single.filePath))
            .exists(),
        true,
      );
      expect(await original.exists(), true);
    },
  );

  test(
    'simulated disk-full copy rolls back partial managed files and DB writes',
    () async {
      final original = await source('first', 100);
      storage = PhotoStorage(
        directoryLoader: () async => directory,
        fileCopier: (source, target) async {
          await target.writeAsBytes([1, 2, 3]);
          throw const FileSystemException('No space left on device');
        },
      );
      repository = PhotoRepository(
        database,
        storage,
        idGenerator: () => ids.removeAt(0),
      );
      await expectLater(
        repository.create(draft(), [original.path]),
        throwsA(isA<FileSystemException>()),
      );
      expect(await database.select(database.records).get(), isEmpty);
      expect(
        await Directory('${directory.path}/my_life/photos/records/record-1')
            .exists(),
        false,
      );
      expect(await original.exists(), true);
    },
  );

  test(
    'failed delete transaction restores moved files and all photo rows',
    () async {
      final first = await source('first', 100);
      final second = await source('second', 150);
      final record = await repository.create(draft(), [
        first.path,
        second.path,
      ]);
      await database.customStatement(
        "CREATE TRIGGER reject_photo_delete BEFORE DELETE ON photos BEGIN SELECT RAISE(ABORT, 'simulated DB failure'); END",
      );
      await expectLater(
        repository.deletePhoto(record.record.id, record.photos.first.id),
        throwsA(anything),
      );
      expect((await repository.getById(record.record.id))!.photos.length, 2);
      for (final photo in record.photos) {
        expect(
          await File(await storage.absolutePath(photo.filePath)).exists(),
          true,
        );
      }
    },
  );

  test('storage rejects paths outside its managed root', () async {
    await expectLater(
      storage.absolutePath('../../outside.jpg'),
      throwsArgumentError,
    );
    await expectLater(
      storage.deleteRecordFiles('../outside'),
      throwsArgumentError,
    );
    await expectLater(
      storage.stageDeletion(['/absolute/outside.jpg']),
      throwsArgumentError,
    );
  });

  test('requires at least one photo without writing a record', () async {
    await expectLater(
      repository.create(draft(), []),
      throwsA(isA<PhotoValidationException>()),
    );
    expect(await database.select(database.records).get(), isEmpty);
  });

  test('removes one photo, its files, and compacts sort order', () async {
    final first = await source('first', 100);
    final second = await source('second', 150);
    final record = await repository.create(draft(), [first.path, second.path]);
    final removed = record.photos.first;
    final originalPath = await storage.absolutePath(removed.filePath);
    final thumbnailPath = await storage.absolutePath(removed.thumbnailPath!);

    await repository.deletePhoto(record.record.id, removed.id);

    final updated = await repository.getById(record.record.id);
    expect(updated?.photos, hasLength(1));
    expect(updated?.photos.single.sortOrder, 0);
    expect(await File(originalPath).exists(), isFalse);
    expect(await File(thumbnailPath).exists(), isFalse);
    expect(await first.exists(), isTrue);
  });

  test('requires whole-record deletion for the last photo', () async {
    final original = await source('only', 100);
    final record = await repository.create(draft(), [original.path]);

    await expectLater(
      repository.deletePhoto(record.record.id, record.photos.single.id),
      throwsA(isA<LastPhotoDeletionException>()),
    );
    expect(await repository.getById(record.record.id), isNotNull);

    await repository.deleteRecord(record.record.id);
    expect(await repository.getById(record.record.id), isNull);
    expect(await database.select(database.photos).get(), isEmpty);
    expect(await original.exists(), isTrue);
  });

  test('updates photo record metadata without replacing photos', () async {
    final original = await source('only', 100);
    final record = await repository.create(draft(), [original.path]);

    final updated = await repository.updateMetadata(
      record.record.id,
      PhotoDraft(title: '  수정된 제목  ', eventDate: LocalDate(2026, 10, 2)),
    );

    expect(updated.record.title, '수정된 제목');
    expect(updated.record.eventDate, LocalDate(2026, 10, 2));
    expect(updated.photos.single.id, record.photos.single.id);
  });

  test(
    'enforces photo foreign key, order uniqueness, and dimensions',
    () async {
      final original = await source('only', 100);
      final record = await repository.create(draft(), [original.path]);

      await expectLater(
        database
            .into(database.photos)
            .insert(
              PhotosCompanion.insert(
                id: 'orphan',
                recordId: 'missing',
                filePath: 'missing.jpg',
                sortOrder: 0,
              ),
            ),
        throwsA(anything),
      );
      await expectLater(
        database
            .into(database.photos)
            .insert(
              PhotosCompanion.insert(
                id: 'duplicate-order',
                recordId: record.record.id,
                filePath: 'duplicate.jpg',
                sortOrder: 0,
              ),
            ),
        throwsA(anything),
      );
      await expectLater(
        database
            .into(database.photos)
            .insert(
              PhotosCompanion.insert(
                id: 'invalid-width',
                recordId: record.record.id,
                filePath: 'invalid.jpg',
                width: const Value(0),
                sortOrder: 1,
              ),
            ),
        throwsA(anything),
      );
    },
  );

  test('keeps database rows and managed files after reopening', () async {
    await database.close();
    final databaseFile = File('${directory.path}/photo_records.sqlite');
    database = AppDatabase(NativeDatabase(databaseFile));
    ids = ['persistent-record', 'persistent-photo'];
    repository = PhotoRepository(
      database,
      storage,
      clock: () => now,
      idGenerator: () => ids.removeAt(0),
    );
    final original = await source('persistent', 100);
    final created = await repository.create(draft(), [original.path]);
    await database.close();

    database = AppDatabase(NativeDatabase(databaseFile));
    repository = PhotoRepository(database, storage);
    final reopened = await repository.getById(created.record.id);

    expect(reopened?.photos, hasLength(1));
    expect(
      await File(await storage.absolutePath(reopened!.photos.single.filePath))
          .exists(),
      isTrue,
    );
  });

  test(
    'rolls back record and copied files when photo insertion fails',
    () async {
      final existing = await source('existing', 100);
      await repository.create(draft(), [existing.path]);
      final another = await source('another', 150);
      ids
        ..clear()
        ..addAll(['record-2', 'photo-1']);

      await expectLater(
        repository.create(draft(), [another.path]),
        throwsA(anything),
      );

      expect(
        (await database.select(database.records).get()).map((row) => row.id),
        ['record-1'],
      );
      final copiedDirectory = Directory(
        '${directory.path}/my_life/photos/records/record-2',
      );
      expect(await copiedDirectory.exists(), isFalse);
      expect(await another.exists(), isTrue);
    },
  );
}
