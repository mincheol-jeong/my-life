import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_life/app/theme/app_theme.dart';
import 'package:my_life/core/database/app_database.dart';
import 'package:my_life/core/database/app_database_provider.dart';
import 'package:my_life/features/expense/presentation/expense_form_screen.dart';
import 'package:my_life/features/photo/presentation/photo_form_screen.dart';
import 'package:my_life/features/record/presentation/memo_form_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final entry in [
    ('memo', const MemoFormScreen(), 'memo-title-field'),
    ('expense', const ExpenseFormScreen(), 'expense-amount-field'),
    ('photo', const PhotoFormScreen(), 'photo-title-field'),
  ]) {
    testWidgets(
      '${entry.$1} supports narrow screen, large text and keyboard insets',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appDatabaseProvider.overrideWithValue(database)],
            child: MaterialApp(
              theme: AppTheme.light,
              locale: const Locale('en'),
              supportedLocales: const [Locale('ko'), Locale('en')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(2),
                  viewInsets: const EdgeInsets.only(bottom: 220),
                ),
                child: child!,
              ),
              home: entry.$2,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final field = find.byKey(Key(entry.$3));
        await tester.scrollUntilVisible(
          field,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        await tester.enterText(
          field,
          entry.$1 == 'expense' ? '12000' : 'A personal record',
        );
        final save = find.byKey(Key('save-${entry.$1}-button'));
        await tester.scrollUntilVisible(
          save,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        expect(save.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }
}
