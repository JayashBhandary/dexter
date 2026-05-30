import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_settings.dart';
import 'providers.dart';

/// Holds [AppSettings] in memory, seeded with defaults and replaced once the
/// persisted file loads. Every mutation persists immediately.
class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(this._ref) : super(const AppSettings()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    state = await _ref.read(settingsRepoProvider).load();
  }

  Future<void> _update(AppSettings next) async {
    state = next;
    await _ref.read(settingsRepoProvider).save(next);
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _update(state.copyWith(themeMode: mode));

  Future<void> setSeedColor(int argb) =>
      _update(state.copyWith(seedColor: argb));

  Future<void> setCompactDensity(bool v) =>
      _update(state.copyWith(compactDensity: v));

  Future<void> setPageSize(int v) => _update(state.copyWith(pageSize: v));

  Future<void> setConfirmDeletes(bool v) =>
      _update(state.copyWith(confirmDeletes: v));

  Future<void> reset() => _update(const AppSettings());
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
