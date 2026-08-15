import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../library/controllers/library_controller.dart';
import '../../library/data/local_storage_service.dart';

class SettingsState {
  final ThemeMode themeMode;
  final double defaultFontSize;
  final String readerThemePreset;
  final double lineHeight;
  final bool keepScreenOn;

  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.defaultFontSize = 18.0,
    this.readerThemePreset = 'paper',
    this.lineHeight = 1.6,
    this.keepScreenOn = true,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    double? defaultFontSize,
    String? readerThemePreset,
    double? lineHeight,
    bool? keepScreenOn,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      defaultFontSize: defaultFontSize ?? this.defaultFontSize,
      readerThemePreset: readerThemePreset ?? this.readerThemePreset,
      lineHeight: lineHeight ?? this.lineHeight,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    );
  }
}

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, SettingsState>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return SettingsController(storage);
});

class SettingsController extends StateNotifier<SettingsState> {
  final LocalStorageService _storage;

  SettingsController(this._storage) : super(const SettingsState()) {
    _loadSettings();
  }

  void _loadSettings() {
    final modeStr = _storage.getThemeMode();
    final themeMode = switch (modeStr) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    final fontSize = _storage.getReaderFontSize();
    final preset = _storage.getReaderThemePreset();

    state = state.copyWith(
      themeMode: themeMode,
      defaultFontSize: fontSize,
      readerThemePreset: preset,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final str = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _storage.setThemeMode(str);
  }

  Future<void> setFontSize(double size) async {
    state = state.copyWith(defaultFontSize: size);
    await _storage.setReaderFontSize(size);
  }

  Future<void> setReaderThemePreset(String preset) async {
    state = state.copyWith(readerThemePreset: preset);
    await _storage.setReaderThemePreset(preset);
  }

  Future<void> setLineHeight(double height) async {
    state = state.copyWith(lineHeight: height);
  }

  Future<void> setKeepScreenOn(bool keepOn) async {
    state = state.copyWith(keepScreenOn: keepOn);
  }
}
