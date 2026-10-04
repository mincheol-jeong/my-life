import 'package:my_life/features/record/domain/local_date.dart';

enum RecordType {
  memo('MEMO'),
  expense('EXPENSE'),
  photo('PHOTO');

  const RecordType(this.databaseValue);

  final String databaseValue;

  static RecordType fromDatabase(String value) {
    return RecordType.values.firstWhere(
      (type) => type.databaseValue == value,
      orElse: () => throw FormatException('Unknown record type', value),
    );
  }
}

class LifeRecord {
  const LifeRecord({
    required this.id,
    required this.type,
    required this.eventDate,
    required this.createdAt,
    required this.updatedAt,
    this.title,
    this.content,
    this.eventTimeMinutes,
    this.placeName,
    this.deletedAt,
  });

  final String id;
  final RecordType type;
  final String? title;
  final String? content;
  final LocalDate eventDate;
  final int? eventTimeMinutes;
  final String? placeName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  String get displayLabel {
    final normalizedTitle = title?.trim();
    if (normalizedTitle != null && normalizedTitle.isNotEmpty) {
      return normalizedTitle;
    }

    if (type == RecordType.memo) {
      String? firstLine;
      for (final line in content?.split('\n') ?? const <String>[]) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          firstLine = trimmed;
          break;
        }
      }
      return firstLine ?? '메모';
    }

    return switch (type) {
      RecordType.memo => '메모',
      RecordType.expense => '지출',
      RecordType.photo => '사진',
    };
  }
}

class MemoDraft {
  const MemoDraft({
    required this.eventDate,
    this.title,
    this.content,
    this.eventTimeMinutes,
    this.placeName,
  });

  final String? title;
  final String? content;
  final LocalDate eventDate;
  final int? eventTimeMinutes;
  final String? placeName;
}

class MemoValidationException implements Exception {
  const MemoValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RecordNotFoundException implements Exception {
  const RecordNotFoundException(this.id);

  final String id;

  @override
  String toString() => 'Record not found: $id';
}
