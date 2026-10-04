import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_life/core/database/app_database_provider.dart';
import 'package:my_life/features/photo/data/photo_repository.dart';
import 'package:my_life/features/photo/data/photo_metadata_reader.dart';
import 'package:my_life/features/photo/data/photo_storage.dart';
import 'package:my_life/features/photo/domain/photo_record.dart';

final photoStorageProvider = Provider<PhotoStorage>((ref) => PhotoStorage());

final photoMetadataReaderProvider = Provider<PhotoMetadataReader>((ref) {
  return const PhotoMetadataReader();
});

final recoveredPhotoPathsProvider =
    AsyncNotifierProvider<RecoveredPhotoPaths, List<String>>(
      RecoveredPhotoPaths.new,
    );

class RecoveredPhotoPaths extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    try {
      final response = await ImagePicker().retrieveLostData();
      if (response.isEmpty) return const [];
      final files =
          response.files ?? [if (response.file != null) response.file!];
      return files.map((file) => file.path).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  List<String> take() {
    final paths = state.value ?? const [];
    state = const AsyncData([]);
    return paths;
  }
}

final photoRepositoryProvider = Provider<PhotoRepository>((ref) {
  return PhotoRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(photoStorageProvider),
  );
});

final photoDetailProvider = StreamProvider.autoDispose
    .family<PhotoRecord?, String>(
      (ref, id) => ref.watch(photoRepositoryProvider).watchById(id),
    );

final photoPathProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, relativePath) =>
      ref.watch(photoStorageProvider).absolutePath(relativePath),
);

final photoControllerProvider =
    AsyncNotifierProvider.autoDispose<PhotoController, void>(
      PhotoController.new,
    );

class PhotoController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<PhotoRecord?> create(PhotoDraft draft, List<String> sourcePaths) {
    return _perform(
      () => ref.read(photoRepositoryProvider).create(draft, sourcePaths),
    );
  }

  Future<PhotoRecord?> saveEdit(String id, PhotoDraft draft) {
    return _perform(
      () => ref.read(photoRepositoryProvider).updateMetadata(id, draft),
    );
  }

  Future<bool> deletePhoto(String recordId, String photoId) {
    return _performVoid(
      () => ref.read(photoRepositoryProvider).deletePhoto(recordId, photoId),
    );
  }

  Future<bool> deleteRecord(String recordId) {
    return _performVoid(
      () => ref.read(photoRepositoryProvider).deleteRecord(recordId),
    );
  }

  Future<PhotoRecord?> _perform(
    Future<PhotoRecord> Function() operation,
  ) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(operation);
    state = result.whenData((_) {});
    return result.value;
  }

  Future<bool> _performVoid(Future<void> Function() operation) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(operation);
    state = result;
    return !result.hasError;
  }
}
