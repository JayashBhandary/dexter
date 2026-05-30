import 'dart:convert';

import 'package:flutter/material.dart';

/// User-configurable application settings, persisted as JSON.
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.seedColor = 0xFF3D5AFE,
    this.compactDensity = true,
    this.pageSize = 100,
    this.confirmDeletes = true,
  });

  final ThemeMode themeMode;

  /// Accent / seed color as a 32-bit ARGB int.
  final int seedColor;

  /// Compact vs comfortable visual density.
  final bool compactDensity;

  /// Default rows-per-page when browsing tabular data.
  final int pageSize;

  /// Ask for confirmation before destructive actions.
  final bool confirmDeletes;

  Color get seed => Color(seedColor);

  AppSettings copyWith({
    ThemeMode? themeMode,
    int? seedColor,
    bool? compactDensity,
    int? pageSize,
    bool? confirmDeletes,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        seedColor: seedColor ?? this.seedColor,
        compactDensity: compactDensity ?? this.compactDensity,
        pageSize: pageSize ?? this.pageSize,
        confirmDeletes: confirmDeletes ?? this.confirmDeletes,
      );

  Map<String, Object?> toJson() => {
        'themeMode': themeMode.name,
        'seedColor': seedColor,
        'compactDensity': compactDensity,
        'pageSize': pageSize,
        'confirmDeletes': confirmDeletes,
      };

  static AppSettings fromJson(Map<String, Object?> j) => AppSettings(
        themeMode: ThemeMode.values.firstWhere(
          (m) => m.name == j['themeMode'],
          orElse: () => ThemeMode.system,
        ),
        seedColor: (j['seedColor'] as num?)?.toInt() ?? 0xFF3D5AFE,
        compactDensity: j['compactDensity'] as bool? ?? true,
        pageSize: (j['pageSize'] as num?)?.toInt() ?? 100,
        confirmDeletes: j['confirmDeletes'] as bool? ?? true,
      );

  String encode() => jsonEncode(toJson());

  static AppSettings decode(String raw) =>
      fromJson(jsonDecode(raw) as Map<String, Object?>);
}
