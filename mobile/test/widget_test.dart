import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_life/app/app.dart';
import 'package:my_life/core/database/app_database.dart';
import 'package:my_life/core/database/app_database_provider.dart';
import 'package:my_life/features/calendar_import/application/calendar_import_providers.dart';
import 'package:my_life/features/calendar_import/data/calendar_device_service.dart';
import 'package:my_life/features/calendar_import/domain/calendar_import_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders the app shell and navigates between sections', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MyLifeApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MY LIFE'), findsOneWidget);
    expect(find.byTooltip('기록 추가'), findsOneWidget);

    await tester.tap(find.text('타임라인'));
    await tester.pumpAndSettle();
    expect(find.text('아직 기록이 없어요'), findsOneWidget);

    await tester.tap(find.byTooltip('기록 추가'));
    await tester.pumpAndSettle();
    expect(find.text('무엇을 기록할까요?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('create-memo-button')));
    await tester.pumpAndSettle();
    expect(find.text('제목 (선택)'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('memo-content-field')),
      '오늘의 메모',
    );
    await tester.tap(find.byKey(const Key('save-memo-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('memo-detail-title')), findsOneWidget);
    expect(find.text('오늘의 메모'), findsNWidgets(2));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('creates an expense and opens its detail', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MyLifeApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('기록 추가'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-expense-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('expense-amount-field')),
      '45000',
    );
    await tester.enterText(
      find.byKey(const Key('expense-memo-field')),
      '저녁 식사',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final saveButton = find.byKey(const Key('save-expense-button'));
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('expense-detail-title')), findsOneWidget);
    expect(find.text('₩45,000'), findsOneWidget);
    expect(find.text('식비'), findsOneWidget);
    expect(find.text('카드'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('record forms provide an explicit back action', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MyLifeApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('기록 추가'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-memo-button')));
    await tester.pumpAndSettle();

    final backButton = find.byKey(const Key('memo-form-back-button'));
    expect(backButton, findsOneWidget);
    await tester.tap(backButton);
    await tester.pumpAndSettle();

    expect(find.text('MY LIFE'), findsOneWidget);
    expect(find.byKey(const Key('memo-content-field')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('filters timeline records and opens a memo detail', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database
        .into(database.records)
        .insert(
          RecordsCompanion.insert(
            id: 'timeline-memo',
            type: 'MEMO',
            title: const Value('Timeline memo'),
            content: const Value('Memo body'),
            eventDate: '2026-09-30',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await database
        .into(database.records)
        .insert(
          RecordsCompanion.insert(
            id: 'timeline-expense',
            type: 'EXPENSE',
            title: const Value('Timeline expense'),
            eventDate: '2026-09-29',
            createdAt: 2,
            updatedAt: 2,
          ),
        );
    await database
        .into(database.expenses)
        .insert(
          ExpensesCompanion.insert(
            id: 'timeline-expense-row',
            recordId: 'timeline-expense',
            amount: 18000,
            category: 'FOOD',
            paymentMethod: 'CARD',
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MyLifeApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('타임라인'));
    await tester.pumpAndSettle();

    expect(find.text('Timeline memo'), findsOneWidget);
    expect(find.text('Timeline expense'), findsOneWidget);
    expect(find.text('2026.09.30'), findsOneWidget);

    await tester.tap(find.byKey(const Key('timeline-filter-memo')));
    await tester.pumpAndSettle();
    expect(find.text('Timeline memo'), findsOneWidget);
    expect(find.text('Timeline expense'), findsNothing);

    await tester.tap(find.byKey(const Key('timeline-entry-timeline-memo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('memo-detail-title')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('switches the app language to English and persists it', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MyLifeApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('나'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('language-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('영어').last);
    await tester.pumpAndSettle();

    expect(find.text('Language'), findsWidgets);
    expect(find.text('Home'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getString('app_language'),
      'en',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('opens calendar import without requesting permission on entry', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          calendarDeviceServiceProvider.overrideWithValue(
            _FakeCalendarDeviceService(),
          ),
        ],
        child: const MyLifeApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('나'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar-import-entry')));
    await tester.pumpAndSettle();

    expect(find.text('캘린더 접근이 필요해요'), findsOneWidget);
    expect(
      find.byKey(const Key('request-calendar-permission')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

class _FakeCalendarDeviceService extends CalendarDeviceService {
  @override
  Future<CalendarAccessState> checkAccess() async {
    return CalendarAccessState.notDetermined;
  }
}
