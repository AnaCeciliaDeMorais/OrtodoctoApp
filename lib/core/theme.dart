import 'package:flutter/material.dart';

class AppTheme {
  static const seed = Color(0xFF0E7C86);
  static const promo = Color(0xFFE4572E);

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(centerTitle: false),
    );
  }
}

/// Preferência de tema guardada só na sessão (claro, escuro ou do sistema).
final themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);
