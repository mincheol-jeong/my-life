import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  korean('ko'),
  english('en');

  const AppLanguage(this.languageCode);

  final String languageCode;
}

final localeControllerProvider =
    AsyncNotifierProvider<LocaleController, Locale>(LocaleController.new);

class LocaleController extends AsyncNotifier<Locale> {
  static const _preferenceKey = 'app_language';

  @override
  FutureOr<Locale> build() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_preferenceKey);
    return Locale(saved == AppLanguage.english.languageCode ? 'en' : 'ko');
  }

  Future<void> setLanguage(AppLanguage language) async {
    final locale = Locale(language.languageCode);
    state = AsyncData(locale);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, language.languageCode);
  }
}
