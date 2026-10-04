import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _seedColor = Color(0xFF8A6F5A);
  static const _background = Color(0xFFFBF8F4);

  static final light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
      surface: _background,
    ),
    scaffoldBackgroundColor: _background,
    appBarTheme: const AppBarTheme(
      backgroundColor: _background,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    bottomAppBarTheme: const BottomAppBarThemeData(
      color: Color(0xFFFFFCF8),
      elevation: 2,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      shape: CircleBorder(),
    ),
  );
}
