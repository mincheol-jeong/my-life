import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_life/core/database/app_database.dart';
import 'package:my_life/features/expense/domain/expense_record.dart';
import 'package:my_life/features/payment_import/data/payment_import_repository.dart';
import 'package:my_life/features/payment_import/domain/payment_message.dart';
import 'package:my_life/features/record/domain/local_date.dart';

PaymentMessage _message(
  String text, {
  String id = 'event-1',
  String source = 'test-card',
}) => PaymentMessage(
  source: source,
  externalId: id,
  text: text,
  receivedAt: DateTime(2026, 10, 5, 13),
);

void main() {
  const parser = PaymentMessageParser();
  test('suggests KRW amount, local timestamp and conservative category', () {
    final result = parser.parse(
      _message('삼성카드 승인\n12,300원\n10/05 12:34\n커피 매장\n누적 500,000원'),
    )!;
    expect(result.amount, 12300);
    expect(result.category, ExpenseCategory.other);
    expect(result.paymentMethod, PaymentMethod.card);
    expect(result.eventDate, LocalDate(2026, 10, 5));
    expect(result.eventTimeMinutes, 754);
    expect(result.title, isNull);
  });
  for (final text in [
    '카드 결제 취소 10,000원',
    '환불 승인 10,000원',
    '온통대전 충전 10,000원',
    '카드대금 청구 10,000원',
    '카카오뱅크 이체 10,000원',
    '입금 승인 10,000원',
    '카드 승인 10.50원',
    '카드 승인 0원',
    '카드 승인 -10,000원',
    '카드 승인 - 10,000원',
    '카드 승인 −10,000원',
    '카드 승인 +10,000원',
    '카드 승인 USD 10',
    '승인 10,000원\n사용금액 20,000원',
    '인증번호 123456 승인',
    '승인 10,000원 02/30 12:00',
    '승인 10,000원 10/05 25:00',
  ]) {
    test(
      'does not treat this alert as a purchase: $text',
      () => expect(parser.parse(_message(text)), isNull),
    );
  }
  test('uses receipt time when date is absent and handles prior December', () {
    final fallback = parser.parse(_message('카드 승인 5,000원'))!;
    expect(fallback.eventDate, LocalDate(2026, 10, 5));
    final yearEnd = parser.parse(
      PaymentMessage(
        source: 'card',
        externalId: 'new-year',
        text: '승인 1,000원 12/31 23:59',
        receivedAt: DateTime(2027, 1, 1, 0, 1),
      ),
    )!;
    expect(yearEnd.eventDate, LocalDate(2026, 12, 31));
  });

  group('repository', () {
    late AppDatabase database;
    late PaymentImportRepository repository;
    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      repository = PaymentImportRepository(database);
    });
    tearDown(() => database.close());
    test(
      'deduplicates handoffs without creating expenses until confirmation',
      () async {
        final message = _message('카드 승인 12,000원');
        await repository.ingest([message, message]);
        expect(await repository.watchPending().first, hasLength(1));
        expect(await database.select(database.records).get(), isEmpty);
        await repository.ingest([_message('취소 12,000원', id: 'cancel')]);
        expect(await repository.watchPending().first, hasLength(1));
      },
    );
    test(
      'saves once in a transaction and clears original alert text',
      () async {
        final message = _message('승인 12,000원');
        await repository.ingest([message]);
        final id = (await repository.watchPending().first).single.id;
        final expense = await repository.save(id, parser.parse(message)!);
        expect(expense.amount, 12000);
        expect(await repository.watchPending().first, isEmpty);
        expect(
          (await database.select(database.paymentImports).get()).single.rawText,
          '',
        );
        await expectLater(
          repository.save(id, parser.parse(message)!),
          throwsStateError,
        );
        await repository.ingest([message]);
        expect(await repository.watchPending().first, isEmpty);
        expect(await database.select(database.expenses).get(), hasLength(1));
      },
    );
    test(
      'failed save leaves the pending alert and no partial record',
      () async {
        await repository.ingest([_message('결제 100원')]);
        final id = (await repository.watchPending().first).single.id;
        await expectLater(
          repository.save(
            id,
            ExpenseDraft(
              amount: 0,
              category: ExpenseCategory.other,
              paymentMethod: PaymentMethod.card,
              eventDate: LocalDate(2026, 10, 5),
            ),
          ),
          throwsA(isA<ExpenseValidationException>()),
        );
        expect(await repository.watchPending().first, hasLength(1));
        expect(await database.select(database.records).get(), isEmpty);
      },
    );
    test(
      'dismissal clears text and prevents the same handoff reappearing',
      () async {
        final message = _message('결제 100원');
        await repository.ingest([message]);
        await repository.dismiss(
          (await repository.watchPending().first).single.id,
        );
        await repository.ingest([message]);
        expect(await repository.watchPending().first, isEmpty);
        expect(
          (await database.select(database.paymentImports).get()).single.rawText,
          '',
        );
      },
    );
    test(
      'distinct source IDs remain separate legitimate transactions',
      () async {
        await repository.ingest([
          _message('승인 100원'),
          _message('승인 100원', id: 'event-2'),
        ]);
        expect(await repository.watchPending().first, hasLength(2));
      },
    );
  });
}
