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

final languageSaverProvider = Provider<Future<bool> Function(String)>((ref) {
  return (code) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.setString('app_language', code);
  };
});

class LocaleController extends AsyncNotifier<Locale> {
  static const _preferenceKey = 'app_language';

  @override
  FutureOr<Locale> build() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_preferenceKey);
    return Locale(saved == AppLanguage.english.languageCode ? 'en' : 'ko');
  }

  Future<bool> setLanguage(AppLanguage language) async {
    final previous = state.value ?? const Locale('ko');
    final locale = Locale(language.languageCode);
    state = AsyncData(locale);
    try {
      final saved = await ref.read(languageSaverProvider)(
        language.languageCode,
      );
      if (saved) return true;
    } catch (_) {
      // Keep the last persisted language if local preferences are unavailable.
    }
    state = AsyncData(previous);
    return false;
  }
}
