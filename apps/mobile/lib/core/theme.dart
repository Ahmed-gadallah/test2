import 'package:flutter/material.dart';

/// Zaad design tokens (spec §4.1). Primary: Royal Blue #2224C6, secondary: white.
class ZaadColors {
  static const primary = Color(0xFF2224C6);
  static const primaryDark = Color(0xFF16178F);
  static const primarySoft = Color(0xFFE9E9FB);
  static const background = Color(0xFFF5F6FA);
  static const surface = Colors.white;
  static const text = Color(0xFF16172B);
  static const textMuted = Color(0xFF6B6E85);
  static const border = Color(0xFFE3E5EE);
  static const success = Color(0xFF12805C);
  static const successSoft = Color(0xFFE5F5EE);
  static const danger = Color(0xFFC2352B);
  static const dangerSoft = Color(0xFFFBEAE8);
  static const warning = Color(0xFF9A6200);
  static const warningSoft = Color(0xFFFFF4DD);
}

class ZaadSpace {
  static const xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0, xl = 24.0, xxl = 32.0;
  static const radius = 16.0;
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: ZaadColors.primary, primary: ZaadColors.primary, surface: ZaadColors.surface, error: ZaadColors.danger);
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: 'IBMPlexSansArabic', scaffoldBackgroundColor: ZaadColors.background);
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: ZaadColors.text, displayColor: ZaadColors.text),
    appBarTheme: const AppBarTheme(
      backgroundColor: ZaadColors.background,
      foregroundColor: ZaadColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontFamily: 'IBMPlexSansArabic', fontSize: 17, fontWeight: FontWeight.w600, color: ZaadColors.text),
    ),
    cardTheme: CardThemeData(
      color: ZaadColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaadSpace.radius), side: const BorderSide(color: ZaadColors.border)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: shape,
        textStyle: const TextStyle(fontFamily: 'IBMPlexSansArabic', fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: shape,
        side: const BorderSide(color: ZaadColors.border),
        textStyle: const TextStyle(fontFamily: 'IBMPlexSansArabic', fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ZaadColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: ZaadColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: ZaadColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: ZaadColors.primary, width: 1.5)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: ZaadColors.surface,
      indicatorColor: ZaadColors.primarySoft,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(fontFamily: 'IBMPlexSansArabic', fontSize: 12, fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400),
      ),
    ),
    dividerTheme: const DividerThemeData(color: ZaadColors.border, space: 1),
  );
}
