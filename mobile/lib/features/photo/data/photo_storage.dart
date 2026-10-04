import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as image_lib;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

typedef AppDirectoryLoader = Future<Directory> Function();

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
  PhotoStorage({AppDirectoryLoader? directoryLoader})
    : _directoryLoader = directoryLoader ?? getApplicationDocumentsDirectory;

  final AppDirectoryLoader _directoryLoader;

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
        await source.copy(original.path);

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
    return path.join(root.path, relativePath);
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
      var index = 0;
      for (final relativePath in relativePaths.whereType<String>()) {
        final original = File(path.join(root.path, relativePath));
        if (!await original.exists()) continue;
        final staged = File(
          path.join(trash.path, '${index++}_${path.basename(original.path)}'),
        );
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
    final directory = Directory(path.join(root.path, 'records', recordId));
    if (await directory.exists()) await directory.delete(recursive: true);
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
