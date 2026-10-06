import 'package:my_life/features/record/application/local_date_provider.dart';

import 'dart:async';

import 'package:drift/native.dart';
import 'package:my_life/app/device_import_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_life/app/app.dart';
import 'package:my_life/core/database/app_database.dart';
import 'package:my_life/core/database/app_database_provider.dart';
import 'package:my_life/core/localization/locale_controller.dart';
import 'package:my_life/features/expense/data/expense_repository.dart';
import 'package:my_life/features/expense/domain/expense_record.dart';
import 'package:my_life/features/finance/application/finance_providers.dart';
import 'package:my_life/features/finance/domain/finance_summary.dart';
import 'package:my_life/features/finance/presentation/finance_screen.dart';
import 'package:my_life/features/record/domain/local_date.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Finance tab opens empty current month without demo data', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          localClockProvider.overrideWithValue(() => DateTime(2026, 10, 5)),
        ],
        child: const MyLifeApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('재정'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('finance-month')), findsOneWidget);
    expect(find.text('₩0'), findsOneWidget);
    expect(find.text('선택한 달에는 아직 지출 기록이 없어요.'), findsOneWidget);
    expect(find.text('카테고리별 지출'), findsNothing);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FinanceScreen)),
    );
    await container
        .read(localeControllerProvider.notifier)
        .setLanguage(AppLanguage.english);
    await tester.pumpAndSettle();
    expect(find.text('Total expenses'), findsOneWidget);
    expect(
      find.text('No expenses recorded for this month yet.'),
      findsOneWidget,
    );
    await dispose(tester);
  });

  testWidgets(
    'month navigation and live Expense edits update every breakdown',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final expenses = ExpenseRepository(db);
      final record = await expenses.create(draft('2026-10-05', 1000));
      await expenses.create(draft('2026-09-30', 2000));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            localClockProvider.overrideWithValue(() => DateTime(2026, 10, 5)),
          ],
          child: app(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('₩1,000'), findsNWidgets(3));
      expect(find.text('식비'), findsOneWidget);
      expect(find.text('10.05'), findsOneWidget);
      await expenses.update(
        record.record.id,
        draft('2026-10-06', 3000, ExpenseCategory.transport),
      );
      await tester.pumpAndSettle();
      expect(find.text('₩3,000'), findsNWidgets(3));
      expect(find.text('교통'), findsOneWidget);
      expect(find.text('10.05'), findsNothing);
      expect(find.text('10.06'), findsOneWidget);
      await tester.tap(find.byKey(const Key('finance-previous-month')));
      await tester.pumpAndSettle();
      expect(find.text('₩2,000'), findsNWidgets(3));
      expect(find.text('09.30'), findsOneWidget);
      await tester.tap(find.byKey(const Key('finance-next-month')));
      await tester.pumpAndSettle();
      expect(find.text('₩3,000'), findsNWidgets(3));
      await expenses.softDelete(record.record.id);
      await tester.pumpAndSettle();
      expect(find.text('₩0'), findsOneWidget);
      expect(find.text('교통'), findsNothing);
      await dispose(tester);
    },
  );

  testWidgets(
    'loading a different month never displays previous month totals',
    (tester) async {
      final nextMonth = StreamController<FinanceSummary>();
      addTearDown(nextMonth.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localClockProvider.overrideWithValue(() => DateTime(2026, 10, 5)),
            financeSummaryProvider.overrideWith(
              (ref) => ref.watch(financeMonthProvider).month == 10
                  ? Stream.value(
                      FinanceSummary(total: 1000, categories: [], days: []),
                    )
                  : nextMonth.stream,
            ),
          ],
          child: app(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('₩1,000'), findsOneWidget);
      await tester.tap(find.byKey(const Key('finance-next-month')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('finance-loading')), findsOneWidget);
      expect(find.text('₩1,000'), findsNothing);
      nextMonth.add(FinanceSummary(total: 0, categories: [], days: []));
      await tester.pumpAndSettle();
      expect(find.text('₩0'), findsOneWidget);
      await tester.tap(find.byKey(const Key('finance-current-month')));
      await tester.pumpAndSettle();
      expect(find.text('₩1,000'), findsOneWidget);
      await dispose(tester);
    },
  );

  testWidgets(
    'error is localized and retry recovers without exposing exception',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localClockProvider.overrideWithValue(() => DateTime(2026, 10, 5)),
            financeSummaryProvider.overrideWith((ref) {
              attempts++;
              return attempts == 1
                  ? Stream<FinanceSummary>.error(StateError('private SQL data'))
                  : Stream.value(
                      FinanceSummary(total: 0, categories: [], days: []),
                    );
            }),
          ],
          child: app(locale: const Locale('en')),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Could not load expenses. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('private SQL'), findsNothing);
      await tester.tap(find.byKey(const Key('finance-retry')));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.text('₩0'), findsOneWidget);
      await dispose(tester);
    },
  );

  testWidgets(
    'resume updates default month and preserves an explicitly browsed month',
    (tester) async {
      var now = DateTime(2026, 10, 31, 23, 59);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localClockProvider.overrideWithValue(() => now),
            financeSummaryProvider.overrideWith(
              (ref) => Stream.value(
                FinanceSummary(
                  total: ref.watch(financeMonthProvider).month,
                  categories: [],
                  days: [],
                ),
              ),
            ),
          ],
          child: app(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('₩10'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = DateTime(2026, 11, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('₩11'), findsOneWidget);
      await tester.tap(find.byKey(const Key('finance-previous-month')));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = DateTime(2026, 12, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('₩10'), findsOneWidget);
      await tester.tap(find.byKey(const Key('finance-current-month')));
      await tester.pumpAndSettle();
      expect(find.text('₩12'), findsOneWidget);
      await dispose(tester);
    },
  );

  testWidgets('English categories and large text fit a narrow mobile screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localClockProvider.overrideWithValue(() => DateTime(2026, 10, 5)),
          financeSummaryProvider.overrideWith(
            (ref) => Stream.value(
              FinanceSummary(
                total: 123456789000,
                categories: [
                  const CategoryExpenseTotal(
                    ExpenseCategory.entertainment,
                    123456789000,
                  ),
                ],
                days: [DailyExpenseTotal(LocalDate(2026, 10, 5), 123456789000)],
              ),
            ),
          ),
        ],
        child: app(locale: const Locale('en'), scale: 2),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Entertainment'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('finance-list')),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    expect(find.text('Daily expenses'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await dispose(tester);
  });
}

Widget app({Locale locale = const Locale('ko'), double scale = 1}) =>
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('ko'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: const DeviceImportSync(child: FinanceScreen()),
    );

ExpenseDraft draft(
  String date,
  int amount, [
  ExpenseCategory category = ExpenseCategory.food,
]) => ExpenseDraft(
  amount: amount,
  category: category,
  paymentMethod: PaymentMethod.card,
  eventDate: LocalDate.parse(date),
);

Future<void> dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}
