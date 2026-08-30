import 'package:flutter/material.dart';

abstract final class FitColors {
  static const paper = Color(0xFFF3F2ED);
  static const ink = Color(0xFF25282C);
  static const black = Color(0xFF17181A);
  static const coral = Color(0xFFC75A49);
  static const coralDark = Color(0xFFA74235);
  static const muted = Color(0xFF70716F);
  static const line = Color(0xFFB8B8B2);
  static const white = Color(0xFFFAF9F5);
}

ThemeData fitTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: FitColors.coral,
    brightness: Brightness.light,
    surface: FitColors.paper,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: FitColors.paper,
    fontFamily: 'Helvetica Neue',
    dividerColor: FitColors.line,
    appBarTheme: const AppBarTheme(
      backgroundColor: FitColors.paper,
      foregroundColor: FitColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: FitColors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: FitColors.ink),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: FitColors.ink),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: FitColors.coral, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: FitColors.coral,
        foregroundColor: FitColors.white,
        shape: const RoundedRectangleBorder(),
        minimumSize: const Size(48, 52),
        textStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: const RoundedRectangleBorder(),
        side: const BorderSide(color: FitColors.ink),
        minimumSize: const Size(48, 52),
        textStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    ),
  );
}
