import 'package:flutter/material.dart';

/// User-chosen text size multiplier (settings screen).
final fontScale = ValueNotifier<double>(1.0);

const _ink = Color(0xFF1E2B28);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF1B7F6E));
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  const h = 1.4; // comfortable line height for Arabic
  final text = base.textTheme
      .copyWith(
        displaySmall: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, height: h),
        headlineMedium: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, height: h),
        headlineSmall: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: h),
        titleLarge: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: h),
        titleMedium: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: h),
        bodyLarge: const TextStyle(fontSize: 22, height: h),
        bodyMedium: const TextStyle(fontSize: 20, height: h),
        bodySmall: const TextStyle(fontSize: 18, height: h),
        labelLarge: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        labelMedium: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      )
      .apply(bodyColor: _ink, displayColor: _ink);
  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));

  return base.copyWith(
    scaffoldBackgroundColor: const Color(0xFFF3F1EA),
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      centerTitle: true,
      titleTextStyle: text.titleLarge?.copyWith(color: scheme.onPrimary),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
          minimumSize: const Size(120, 64), textStyle: text.labelLarge, shape: rounded),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
          minimumSize: const Size(120, 60), textStyle: text.labelLarge, shape: rounded),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 84,
      labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
    ),
    listTileTheme: ListTileThemeData(
      titleTextStyle: text.titleMedium,
      subtitleTextStyle: text.bodySmall?.copyWith(color: Colors.black54),
      minVerticalPadding: 12,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      labelStyle: text.bodyLarge,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
