// Theme management for PerfusionCalc: Light / Dark / System
// =============================================================
// ThemeNotifier holds the chosen ThemeMode (system/light/dark) and
// persists it in SharedPreferences - architecture deliberately analogous
// to LocaleNotifier in i18n/app_strings.dart.
//
// Why not plain Theme.of(context)? A large part of the app uses global
// color constants (kGold, kCardColor, ...) from widgets/common.dart,
// which are also needed outside a BuildContext (e.g. as default values
// or in static helper methods). ThemeNotifier.isDark is therefore a
// simple global switch that these constants (as getters instead of
// const) read live. The actual ThemeData objects below are additionally
// passed to MaterialApp.theme/darkTheme as usual, so standard Material
// widgets (TextField cursor, ripple colors, dialog shapes, ...) react
// correctly too.

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  static const _prefsKey = 'app_theme_mode';
  static final ThemeNotifier instance = ThemeNotifier._();
  ThemeNotifier._();

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  /// Resolved light/dark state. For ThemeMode.system, the current
  /// platform brightness (OS setting) is queried.
  bool get isDark {
    switch (_mode) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
      case ThemeMode.system:
        return ui.PlatformDispatcher.instance.platformBrightness == Brightness.dark;
    }
  }

  /// Loads the saved mode from SharedPreferences.
  /// If none is saved yet: defaults to "system".
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      _mode = switch (saved) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (_) {
      // SharedPreferences unavailable (e.g. in tests) -> default.
      _mode = ThemeMode.system;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
      await prefs.setString(_prefsKey, value);
    } catch (_) {
      // Save failed -> selection only applies for the current session.
    }
  }

  /// Called by a WidgetsBindingObserver in main.dart when the system
  /// brightness changes while mode == system is active, so the global
  /// color getters (kGold, kCardColor, ...) stay in sync and trigger a
  /// rebuild.
  void handlePlatformBrightnessChanged() {
    if (_mode == ThemeMode.system) notifyListeners();
  }
}

// ── ThemeData for MaterialApp (theme:/darkTheme:) ───────────────────────────
// Same hex values as the getters in widgets/common.dart (kCardColor,
// kBg, ...), so app chrome (Scaffold/AppBar via ThemeData) and the
// manually set widget colors match exactly.
const Color kGoldConst = Color(0xFFFFA500);

ThemeData buildAppTheme({required bool dark}) {
  final scaffoldBg = dark ? const Color(0xFF2C2C2C) : const Color(0xFFF1F1F1);
  final surface = dark ? const Color(0xFF1C1C1C) : const Color(0xFFFFFFFF);
  final onSurface = dark ? Colors.white : const Color(0xFF1A1A1A);
  return ThemeData(
    // Die in pubspec.yaml gebuendelte Roboto-Familie, nicht die, die
    // CanvasKit sonst von fonts.gstatic.com nachlaedt. Ohne diese Zeile
    // haengt jede Beschriftung der App an einem Netzabruf - im Web an der
    // CSP, in der Offline-Distribution an gar nichts.
    fontFamily: 'Roboto',
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: dark
        ? const ColorScheme.dark(primary: kGoldConst, surface: Color(0xFF1C1C1C))
        : ColorScheme.light(primary: kGoldConst, surface: Colors.white, onSurface: onSurface),
    scaffoldBackgroundColor: scaffoldBg,
    appBarTheme: AppBarTheme(backgroundColor: surface, foregroundColor: onSurface, elevation: 0),
    dividerColor: dark ? Colors.white12 : const Color(0xFFDDDDDD),
    useMaterial3: true,
  );
}
