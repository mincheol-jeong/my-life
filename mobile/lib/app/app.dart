import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_life/app/router.dart';
import 'package:my_life/app/theme/app_theme.dart';
import 'package:my_life/core/database/app_database_provider.dart';
import 'package:my_life/core/localization/locale_controller.dart';
import 'package:my_life/features/photo/application/photo_providers.dart';

class MyLifeApp extends ConsumerWidget {
  const MyLifeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appDatabaseProvider);
    ref.watch(recoveredPhotoPathsProvider);
    final router = ref.watch(appRouterProvider);
    final locale =
        ref.watch(localeControllerProvider).value ?? const Locale('ko');

    return MaterialApp.router(
      title: 'MY LIFE',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: locale,
      supportedLocales: const [Locale('ko'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
