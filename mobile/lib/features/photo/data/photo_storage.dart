import 'dart:io';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as image_lib;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

typedef AppDirectoryLoader = Future<Directory> Function();
typedef PhotoFileCopier = Future<void> Function(File source, File target);

class PreparedPhotoFile {
  const PreparedPhotoFile({
    required this.id,
    required this.filePath,
    this.thumbnailPath,
    this.width,
    this.height,
  });

  final String id;
  final String filePath;
  final String? thumbnailPath;
  final int? width;
  final int? height;
}

class PhotoStorage {
  PhotoStorage({
    AppDirectoryLoader? directoryLoader,
    PhotoFileCopier? fileCopier,
  }) : _directoryLoader = directoryLoader ?? getApplicationDocumentsDirectory,
       _fileCopier =
           fileCopier ??
           ((source, target) async {
             await source.copy(target.path);
           });

  final AppDirectoryLoader _directoryLoader;
  final PhotoFileCopier _fileCopier;

  Future<List<PreparedPhotoFile>> preparePhotos({
    required String recordId,
    required List<String> photoIds,
    required List<String> sourcePaths,
  }) async {
    if (photoIds.length != sourcePaths.length) {
      throw ArgumentError('Photo ids and sources must have the same length.');
    }
    final root = await _rootDirectory();
    final originalDirectory = Directory(
      path.join(root.path, 'records', recordId, 'originals'),
    );
    final thumbnailDirectory = Directory(
      path.join(root.path, 'records', recordId, 'thumbnails'),
    );
    await originalDirectory.create(recursive: true);
    await thumbnailDirectory.create(recursive: true);

    final prepared = <PreparedPhotoFile>[];
    try {
      for (var index = 0; index < sourcePaths.length; index++) {
        final source = File(sourcePaths[index]);
        if (!await source.exists()) {
          throw FileSystemException('Selected photo does not exist.');
        }
        final id = photoIds[index];
        final extension = path.extension(source.path).toLowerCase();
        final safeExtension = extension.isEmpty ? '.jpg' : extension;
        final originalRelative = path.join(
          'records',
          recordId,
          'originals',
          '$id$safeExtension',
        );
        final original = File(path.join(root.path, originalRelative));
        await _fileCopier(source, original);

        String? thumbnailRelative;
        int? width;
        int? height;
        final sourceBytes = await source.readAsBytes();
        final thumbnail = await Isolate.run(
          () => _createThumbnail(sourceBytes),
        );
        if (thumbnail != null) {
          width = thumbnail.width;
          height = thumbnail.height;
          thumbnailRelative = path.join(
            'records',
            recordId,
            'thumbnails',
            '$id.jpg',
          );
          await File(path.join(root.path, thumbnailRelative))
              .writeAsBytes(thumbnail.bytes);
        }

        prepared.add(
          PreparedPhotoFile(
            id: id,
            filePath: originalRelative,
            thumbnailPath: thumbnailRelative,
            width: width,
            height: height,
          ),
        );
      }
      return prepared;
    } catch (_) {
      await deleteRecordFiles(recordId);
      rethrow;
    }
  }

  Future<String> absolutePath(String relativePath) async {
    final root = await _rootDirectory();
    return _managedPath(root, relativePath);
  }

  Future<StagedPhotoDeletion> stageDeletion(
    Iterable<String?> relativePaths,
  ) async {
    final root = await _rootDirectory();
    final token = const Uuid().v4();
    final trash = Directory(path.join(root.path, '.trash', token));
    await trash.create(recursive: true);
    final moved = <_MovedFile>[];
    try {
      final planned = <Map<String, String>>[];
      var index = 0;
      for (final relativePath in relativePaths.whereType<String>().toSet()) {
        final original = File(_managedPath(root, relativePath));
        if (!await original.exists()) continue;
        planned.add({
          'original': relativePath,
          'staged': '${index++}_${path.basename(original.path)}',
        });
      }
      // Persist all intentions before the first rename; recovery uses current DB references.
      await File(path.join(trash.path, 'manifest.json'))
          .writeAsString(jsonEncode(planned), flush: true);
      for (final entry in planned) {
        final original = File(_managedPath(root, entry['original']!));
        final staged = File(path.join(trash.path, entry['staged']!));
        await original.rename(staged.path);
        moved.add(_MovedFile(original: original, staged: staged));
      }
      return StagedPhotoDeletion._(trash, moved);
    } catch (_) {
      await _restoreMovedFiles(moved);
      if (await trash.exists()) await trash.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> deleteRecordFiles(String recordId) async {
    final root = await _rootDirectory();
    if (recordId.isEmpty ||
        path.basename(recordId) != recordId ||
        recordId == '.' ||
        recordId == '..') {
      throw ArgumentError('Invalid record storage identifier');
    }
    final directory = Directory(
      _managedPath(root, path.join('records', recordId)),
    );
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  /// Run once before photo access/writes, not concurrently with new file operations.
  Future<void> recoverInterruptedOperations({
    required Set<String> activePaths,
    required Set<String> activeRecordIds,
  }) async {
    final root = await _rootDirectory();
    final trashRoot = Directory(path.join(root.path, '.trash'));
    if (await trashRoot.exists()) {
      await for (final entity in trashRoot.list(followLinks: false)) {
        if (entity is! Directory) continue;
        final manifest = File(path.join(entity.path, 'manifest.json'));
        // Legacy/unrecognised staging directories are preserved, never guessed away.
        if (!await manifest.exists()) continue;
        final entries =
            jsonDecode(await manifest.readAsString()) as List<dynamic>;
        for (final value in entries) {
          final entry = Map<String, dynamic>.from(value as Map);
          final relative = entry['original'] as String;
          final stagedName = entry['staged'] as String;
          if (path.basename(stagedName) != stagedName ||
              stagedName == '.' ||
              stagedName == '..') {
            throw const FormatException('Invalid staged file path');
          }
          final original = File(_managedPath(root, relative));
          final staged = File(path.join(entity.path, stagedName));
          if (!await staged.exists()) continue;
          if (activePaths.contains(relative)) {
            if (await original.exists()) {
              throw const FileSystemException(
                'Recovery would overwrite an existing photo',
              );
            }
            await original.parent.create(recursive: true);
            await staged.rename(original.path);
          } else {
            await staged.delete();
          }
        }
        await entity.delete(recursive: true);
      }
    }
    final recordsRoot = Directory(path.join(root.path, 'records'));
    if (await recordsRoot.exists()) {
      await for (final entity in recordsRoot.list(followLinks: false)) {
        if (entity is Directory &&
            !activeRecordIds.contains(path.basename(entity.path))) {
          // Only app-owned copies of a never-committed or deleted Record are removed.
          await entity.delete(recursive: true);
        }
      }
    }
  }

  String _managedPath(Directory root, String relative) {
    final target = path.normalize(path.join(root.path, relative));
    if (path.isAbsolute(relative) || !path.isWithin(root.path, target)) {
      throw ArgumentError('Path must stay inside app photo storage');
    }
    return target;
  }

  Future<Directory> _rootDirectory() async {
    final appDirectory = await _directoryLoader();
    final root = Directory(path.join(appDirectory.path, 'my_life', 'photos'));
    await root.create(recursive: true);
    return root;
  }
}

class StagedPhotoDeletion {
  StagedPhotoDeletion._(this._trash, this._moved);

  final Directory _trash;
  final List<_MovedFile> _moved;

  Future<void> rollback() async {
    await _restoreMovedFiles(_moved);
    if (await _trash.exists()) await _trash.delete(recursive: true);
  }

  Future<void> commit() async {
    if (await _trash.exists()) await _trash.delete(recursive: true);
  }
}

class _MovedFile {
  const _MovedFile({required this.original, required this.staged});

  final File original;
  final File staged;
}

Future<void> _restoreMovedFiles(List<_MovedFile> moved) async {
  for (final file in moved.reversed) {
    if (!await file.staged.exists()) continue;
    await file.original.parent.create(recursive: true);
    await file.staged.rename(file.original.path);
  }
}

_ThumbnailData? _createThumbnail(Uint8List bytes) {
  final decoded = image_lib.decodeImage(bytes);
  if (decoded == null) return null;
  final oriented = image_lib.bakeOrientation(decoded);
  final thumbnail = oriented.width > 480
      ? image_lib.copyResize(oriented, width: 480)
      : oriented;
  return _ThumbnailData(
    width: oriented.width,
    height: oriented.height,
    bytes: image_lib.encodeJpg(thumbnail, quality: 82),
  );
}

class _ThumbnailData {
  const _ThumbnailData({
    required this.width,
    required this.height,
    required this.bytes,
  });

  final int width;
  final int height;
  final List<int> bytes;
}
