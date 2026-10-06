import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_life/core/localization/locale_controller.dart';
import 'package:my_life/features/settings/application/app_info_provider.dart';
import 'package:my_life/features/settings/presentation/me_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'version comes from native build metadata rather than a hardcoded value',
    (tester) async {
      const channel = MethodChannel('com.mincheol.mylife/app_info');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        expect(call.method, 'getAppInfo');
        return {'version': '0.4.2', 'buildNumber': '19'};
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(const ProviderScope(child: _MeApp()));
      await tester.pumpAndSettle();
      expect(find.text('0.4.2+19'), findsOneWidget);
      expect(find.byKey(const Key('local-storage-warning')), findsOneWidget);
      await clear(tester);
    },
  );

  testWidgets('version load failure is localized and retry reloads it', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appInfoProvider.overrideWith((ref) async {
            if (++attempts == 1) {
              throw PlatformException(
                code: 'APP_INFO',
                message: 'internal platform error',
              );
            }
            return const AppInfo(version: '0.1.1', buildNumber: '2');
          }),
        ],
        child: const _MeApp(),
      ),
    );
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const Key('app-info-retry')));
    expect(find.text('앱 정보를 불러오지 못했습니다.'), findsOneWidget);
    expect(find.textContaining('internal platform'), findsNothing);
    await tester.tap(find.byKey(const Key('app-info-retry')));
    await tester.pumpAndSettle();
    expect(find.text('0.1.1+2'), findsOneWidget);
    await clear(tester);
  });

  testWidgets('licenses are accessible and show registered license contents', (
    tester,
  ) async {
    LicenseRegistry.addLicense(
      () => Stream.value(
        const LicenseEntryWithLineBreaks([
          'my-life-test-license',
        ], 'Test license content for the license flow.'),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appInfoProvider.overrideWith(
            (ref) async => const AppInfo(version: '0.1.0', buildNumber: '1'),
          ),
        ],
        child: const _MeApp(),
      ),
    );
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const Key('open-source-licenses')));
    await tester.tap(find.byKey(const Key('open-source-licenses')));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
    await tester.tap(find.text('my-life-test-license'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Test license content'), findsOneWidget);
    await clear(tester);
  });

  testWidgets(
    'failed language persistence restores selection and informs the user',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appInfoProvider.overrideWith(
              (ref) async => const AppInfo(version: '0.1.0', buildNumber: '1'),
            ),
            languageSaverProvider.overrideWithValue((_) async => false),
          ],
          child: const _MeApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('language-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('영어').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('언어 설정을 저장하지 못했습니다.'), findsOneWidget);
      expect(find.text('한국어'), findsOneWidget);
      expect(find.text('Language'), findsNothing);
      await clear(tester);
    },
  );

  test(
    'language storage exception is handled and keeps the previous language',
    () async {
      final container = ProviderContainer(
        overrides: [
          languageSaverProvider.overrideWithValue(
            (_) async => throw StateError('write failed'),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(localeControllerProvider.future);
      expect(
        await container
            .read(localeControllerProvider.notifier)
            .setLanguage(AppLanguage.english),
        false,
      );
      expect(
        container.read(localeControllerProvider).value,
        const Locale('ko'),
      );
    },
  );

  testWidgets('English Me supports large text on a narrow screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'app_language': 'en'});
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appInfoProvider.overrideWith(
            (ref) async => const AppInfo(version: '0.1.0', buildNumber: '1'),
          ),
        ],
        child: const _MeApp(scale: 2),
      ),
    );
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const Key('open-source-licenses')));
    expect(find.text('Open source licenses'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await clear(tester);
  });
}

class _MeApp extends ConsumerWidget {
  const _MeApp({this.scale = 1});
  final double scale;
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    locale: ref.watch(localeControllerProvider).value ?? const Locale('ko'),
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
    home: const MeScreen(),
  );
}

Future<void> clear(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<void> scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}
