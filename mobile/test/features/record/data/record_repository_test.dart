import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_life/core/database/app_database.dart';
import 'package:my_life/features/record/data/record_repository.dart';
import 'package:my_life/features/record/domain/life_record.dart';
import 'package:my_life/features/record/domain/local_date.dart';

void main() {
  late AppDatabase database;
  late RecordRepository repository;
  var nextId = 0;
  final createdAt = DateTime.utc(2026, 9, 30, 1, 2, 3);

  setUp(() {
    nextId = 0;
    database = AppDatabase(NativeDatabase.memory());
    repository = RecordRepository(
      database,
      clock: () => createdAt,
      idGenerator: () => 'record-${++nextId}',
    );
  });

  tearDown(() => database.close());

  test('creates a normalized memo and reads it back', () async {
    final record = await repository.createMemo(
      MemoDraft(
        title: '  오늘  ',
        content: '  좋은 하루였다.  ',
        eventDate: LocalDate(2026, 9, 30),
        eventTimeMinutes: 13 * 60 + 45,
        placeName: '  서울  ',
      ),
    );

    expect(record.id, 'record-1');
    expect(record.type, RecordType.memo);
    expect(record.title, '오늘');
    expect(record.content, '좋은 하루였다.');
    expect(record.placeName, '서울');
    expect(record.createdAt, createdAt);
    expect(await repository.getById(record.id), isNotNull);
  });

  test('requires either a memo title or content', () async {
    expect(
      () => repository.createMemo(
        MemoDraft(
          title: '   ',
          content: '\n ',
          eventDate: LocalDate(2026, 9, 30),
        ),
      ),
      throwsA(isA<MemoValidationException>()),
    );
  });

  test(
    'updates a memo while preserving its identity and creation time',
    () async {
      final original = await repository.createMemo(
        MemoDraft(content: '처음', eventDate: LocalDate(2026, 9, 30)),
      );
      final updatedAt = createdAt.add(const Duration(hours: 2));
      repository = RecordRepository(
        database,
        clock: () => updatedAt,
        idGenerator: () => 'unused',
      );

      final updated = await repository.updateMemo(
        original.id,
        MemoDraft(title: '수정됨', eventDate: LocalDate(2026, 10, 1)),
      );

      expect(updated.id, original.id);
      expect(updated.createdAt, original.createdAt);
      expect(updated.updatedAt, updatedAt);
      expect(updated.title, '수정됨');
      expect(updated.content, isNull);
    },
  );

  test('soft delete hides the record and keeps the database row', () async {
    final record = await repository.createMemo(
      MemoDraft(content: '삭제할 메모', eventDate: LocalDate(2026, 9, 30)),
    );

    await repository.softDelete(record.id);

    expect(await repository.getById(record.id), isNull);
    final stored = await (database.select(
      database.records,
    )..where((row) => row.id.equals(record.id))).getSingle();
    expect(stored.deletedAt, createdAt.millisecondsSinceEpoch);
  });

  test('uses the first non-empty content line as the fallback label', () async {
    final record = await repository.createMemo(
      MemoDraft(content: '\n  첫 줄  \n둘째 줄', eventDate: LocalDate(2026, 9, 30)),
    );

    expect(record.displayLabel, '첫 줄');
  });
}
