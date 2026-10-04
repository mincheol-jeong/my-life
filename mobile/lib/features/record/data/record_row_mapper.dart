import 'package:my_life/core/database/app_database.dart';
import 'package:my_life/features/record/domain/life_record.dart';
import 'package:my_life/features/record/domain/local_date.dart';

extension RecordRowMapper on RecordRow {
  LifeRecord toDomain() {
    return LifeRecord(
      id: id,
      type: RecordType.fromDatabase(type),
      title: title,
      content: content,
      eventDate: LocalDate.parse(eventDate),
      eventTimeMinutes: eventTimeMinutes,
      placeName: placeName,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt, isUtc: true),
      deletedAt: deletedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(deletedAt!, isUtc: true),
    );
  }
}
