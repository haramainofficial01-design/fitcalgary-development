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
  return _fitTheme(Brightness.light);
}

ThemeData fitDarkTheme() => _fitTheme(Brightness.dark);

ThemeData _fitTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final paper = dark ? const Color(0xFF111315) : FitColors.paper;
  final surface = dark ? const Color(0xFF1D2024) : FitColors.white;
  final ink = dark ? const Color(0xFFF5F3ED) : FitColors.ink;
  final muted = dark ? const Color(0xFFB9B8B2) : FitColors.muted;
  final line = dark ? const Color(0xFF4A4D50) : FitColors.line;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: FitColors.coral,
        brightness: brightness,
        surface: surface,
      ).copyWith(
        onSurface: ink,
        onSurfaceVariant: muted,
        outline: line,
        outlineVariant: line.withValues(alpha: .65),
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    scaffoldBackgroundColor: paper,
    fontFamily: 'Helvetica Neue',
    dividerColor: line,
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shadowColor: FitColors.black.withValues(alpha: .15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: line.withValues(alpha: .45)),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: paper,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: ink),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: ink),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: FitColors.coral, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: FitColors.coral,
        foregroundColor: FitColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: ink),
        foregroundColor: ink,
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

extension FitThemeColors on BuildContext {
  Color get fitInk => Theme.of(this).colorScheme.onSurface;
  Color get fitMuted => Theme.of(this).colorScheme.onSurfaceVariant;
  Color get fitLine => Theme.of(this).colorScheme.outlineVariant;
  Color get fitSurface => Theme.of(this).colorScheme.surface;
}
