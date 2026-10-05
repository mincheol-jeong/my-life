import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_life/app/app.dart';
import 'package:my_life/core/database/app_database.dart';
import 'package:my_life/core/database/app_database_provider.dart';
import 'package:my_life/features/home/application/home_providers.dart';
import 'package:my_life/features/photo/application/photo_providers.dart';
import 'package:my_life/features/record/domain/local_date.dart';
import 'package:my_life/features/timeline/domain/timeline_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('empty Home shows local date, zero expenses and record entry', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          homeClockProvider.overrideWithValue(() => DateTime(2026, 10, 5)),
        ],
        child: const MyLifeApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2026.10.05'), findsOneWidget);
    expect(find.text('₩0'), findsOneWidget);
    expect(find.text('아직 기록이 없어요'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('home-list')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.text('아직 사진 기록이 없어요.'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('home-create-record')));
    await tester.tap(find.byKey(const Key('home-create-record')));
    await tester.pumpAndSettle();
    expect(find.text('무엇을 기록할까요?'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('Home reacts to expense changes and opens each record detail', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    for (final type in ['MEMO', 'EXPENSE', 'PHOTO']) {
      await database
          .into(database.records)
          .insert(
            RecordsCompanion.insert(
              id: type,
              type: type,
              title: Value('Home $type'),
              eventDate: '2026-10-05',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
    }
    await database
        .into(database.expenses)
        .insert(
          ExpensesCompanion.insert(
            id: 'e',
            recordId: 'EXPENSE',
            amount: 12345,
            category: 'FOOD',
            paymentMethod: 'CARD',
          ),
        );
    await database
        .into(database.photos)
        .insert(
          PhotosCompanion.insert(
            id: 'p',
            recordId: 'PHOTO',
            filePath: 'photos/p.jpg',
            sortOrder: 0,
          ),
        );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          homeClockProvider.overrideWithValue(() => DateTime(2026, 10, 5)),
          photoPathProvider.overrideWith((ref, path) async => '/missing/$path'),
        ],
        child: const MyLifeApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-expense-total')), findsOneWidget);
    expect(find.text('₩12,345'), findsOneWidget);
    await (database.update(database.expenses)..where((e) => e.id.equals('e')))
        .write(const ExpensesCompanion(amount: Value(20000)));
    await tester.pumpAndSettle();
    expect(find.text('₩20,000'), findsOneWidget);

    for (final pair in [
      ('MEMO', 'memo'),
      ('EXPENSE', 'expense'),
      ('PHOTO', 'photo'),
    ]) {
      final row = find.byKey(Key('home-record-${pair.$1}'));
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byKey(Key('${pair.$2}-detail-title')), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
    }
    final thumbnail = find.byKey(const Key('home-photo-PHOTO'));
    await tester.ensureVisible(thumbnail);
    await tester.tap(thumbnail);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('photo-detail-title')), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await (database.update(database.records)
          ..where((r) => r.id.equals('EXPENSE')))
        .write(const RecordsCompanion(deletedAt: Value(2)));
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(const Key('home-list')), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(find.text('₩0'), findsOneWidget);
    expect(find.byKey(const Key('home-record-EXPENSE')), findsNothing);
    await _dispose(tester);
  });

  testWidgets(
    'section failures keep other sections visible and retry recovers',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      var attempts = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            homeClockProvider.overrideWithValue(() => DateTime(2026, 10, 5)),
            homeRecentRecordsProvider.overrideWith((ref) {
              attempts++;
              return attempts == 1
                  ? Stream<List<TimelineEntry>>.error(
                      StateError('private DB error'),
                    )
                  : Stream.value(<TimelineEntry>[]);
            }),
          ],
          child: const MyLifeApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('₩0'), findsOneWidget);
      expect(find.text('private DB error'), findsNothing);
      expect(find.byKey(const Key('home-records-retry')), findsOneWidget);
      await tester.tap(find.byKey(const Key('home-records-retry')));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.text('아직 기록이 없어요'), findsOneWidget);
      await _dispose(tester);
    },
  );

  testWidgets('English section labels and section loading are independent', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'app_language': 'en'});
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final records = StreamController<List<TimelineEntry>>();
    addTearDown(records.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          homeClockProvider.overrideWithValue(() => DateTime(2026, 10, 5)),
          homeRecentRecordsProvider.overrideWith((ref) => records.stream),
        ],
        child: const MyLifeApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Recent records'), findsOneWidget);
    expect(find.byKey(const Key('home-records-loading')), findsOneWidget);
    expect(find.text('₩0'), findsOneWidget);
    records.add([]);
    await tester.pumpAndSettle();
    expect(find.text('No records yet'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('Home refreshes date and monthly total after resume', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    var now = DateTime(2026, 10, 31, 23, 59);
    await database
        .into(database.records)
        .insert(
          RecordsCompanion.insert(
            id: 'nov',
            type: 'EXPENSE',
            eventDate: '2026-11-01',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await database
        .into(database.expenses)
        .insert(
          ExpensesCompanion.insert(
            id: 'e',
            recordId: 'nov',
            amount: 3000,
            category: 'FOOD',
            paymentMethod: 'CARD',
          ),
        );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          homeClockProvider.overrideWithValue(() => now),
        ],
        child: const MyLifeApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2026.10.31'), findsOneWidget);
    expect(find.text('₩0'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = DateTime(2026, 11, 1, 8);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('2026.11.01'), findsOneWidget);
    expect(find.text('₩3,000'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('local day provider advances at midnight', (tester) async {
    var now = DateTime(2026, 12, 31, 23, 59, 59);
    final container = ProviderContainer(
      overrides: [homeClockProvider.overrideWithValue(() => now)],
    );
    final listener = container.listen(homeTodayProvider, (_, _) {});
    expect(container.read(homeTodayProvider), LocalDate(2026, 12, 31));
    now = DateTime(2027, 1, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(container.read(homeTodayProvider), LocalDate(2027, 1, 1));
    listener.close();
    container.dispose();
  });
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}
