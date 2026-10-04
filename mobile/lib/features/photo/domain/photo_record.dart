import 'package:my_life/features/record/domain/life_record.dart';
import 'package:my_life/features/record/domain/local_date.dart';

class StoredPhoto {
  const StoredPhoto({
    required this.id,
    required this.recordId,
    required this.filePath,
    required this.sortOrder,
    this.thumbnailPath,
    this.width,
    this.height,
  });

  final String id;
  final String recordId;
  final String filePath;
  final String? thumbnailPath;
  final int? width;
  final int? height;
  final int sortOrder;
}

class PhotoRecord {
  const PhotoRecord({required this.record, required this.photos});

  final LifeRecord record;
  final List<StoredPhoto> photos;

  String get displayLabel {
    final title = record.title?.trim();
    if (title != null && title.isNotEmpty) return title;
    return photos.length == 1 ? '사진' : '사진 ${photos.length}장';
  }
}

class PhotoDraft {
  const PhotoDraft({
    required this.eventDate,
    this.title,
    this.eventTimeMinutes,
    this.placeName,
  });

  final String? title;
  final LocalDate eventDate;
  final int? eventTimeMinutes;
  final String? placeName;
}

class PhotoValidationException implements Exception {
  const PhotoValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LastPhotoDeletionException implements Exception {
  const LastPhotoDeletionException();
}
