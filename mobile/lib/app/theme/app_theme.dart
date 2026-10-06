import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _seedColor = Color(0xFF8A6F5A);
  static const _background = Color(0xFFFBF8F4);
  static const _inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(20)),
  );
  static final _colors = ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: Brightness.light,
    surface: _background,
  );

  static final light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: _colors,
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
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: const Color(0xFFFFFCF8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: _inputBorder,
      enabledBorder: _inputBorder.copyWith(
        borderSide: BorderSide(color: _colors.outlineVariant),
      ),
      focusedBorder: _inputBorder.copyWith(
        borderSide: BorderSide(color: _colors.primary, width: 2),
      ),
      errorBorder: _inputBorder.copyWith(
        borderSide: BorderSide(color: _colors.error),
      ),
      focusedErrorBorder: _inputBorder.copyWith(
        borderSide: BorderSide(color: _colors.error, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const StadiumBorder(),
        minimumSize: const Size(48, 48),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        minimumSize: const Size(48, 48),
      ),
    ),
    chipTheme: const ChipThemeData(shape: StadiumBorder()),
    cardTheme: const CardThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
    ),
    dialogTheme: const DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
    ),
  );
}
