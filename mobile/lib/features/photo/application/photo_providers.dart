import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_life/core/database/app_database_provider.dart';
import 'package:my_life/features/photo/data/photo_repository.dart';
import 'package:my_life/features/photo/data/photo_metadata_reader.dart';
import 'package:my_life/features/photo/data/photo_storage.dart';
import 'package:my_life/features/photo/domain/photo_record.dart';

final photoStorageProvider = Provider<PhotoStorage>((ref) => PhotoStorage());
final photoPickerProvider = Provider<ImagePicker>((ref) => ImagePicker());

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

final photoPathProvider = FutureProvider.autoDispose.family<String, String>((
  ref,
  relativePath,
) async {
  final repository = ref.watch(photoRepositoryProvider);
  final storage = ref.watch(photoStorageProvider);
  await repository.recoverInterruptedOperations();
  return storage.absolutePath(relativePath);
});

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
    if (state.isLoading) return null;
    final keepAlive = ref.keepAlive();
    state = const AsyncLoading();
    try {
      final result = await AsyncValue.guard(operation);
      if (ref.mounted) state = result.whenData((_) {});
      return result.value;
    } finally {
      keepAlive.close();
    }
  }

  Future<bool> _performVoid(Future<void> Function() operation) async {
    if (state.isLoading) return false;
    final keepAlive = ref.keepAlive();
    state = const AsyncLoading();
    try {
      final result = await AsyncValue.guard(operation);
      if (ref.mounted) state = result;
      return !result.hasError;
    } finally {
      keepAlive.close();
    }
  }
}
