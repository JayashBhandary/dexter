import 'package:flutter/material.dart';

class AppTheme {
  static const Color defaultSeed = Color(0xFF3D5AFE);

  static ThemeData light({Color seed = defaultSeed, bool compact = true}) =>
      _build(Brightness.light, seed, compact);

  static ThemeData dark({Color seed = defaultSeed, bool compact = true}) =>
      _build(Brightness.dark, seed, compact);

  static ThemeData _build(Brightness b, Color seed, bool compact) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: b);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity:
          compact ? VisualDensity.compact : VisualDensity.standard,
      scaffoldBackgroundColor: scheme.surface,
    );
  }
}
