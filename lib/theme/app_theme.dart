// Theme-Verwaltung für PerfusionCalc: Light / Dark / System
// =============================================================
// ThemeNotifier hält den gewählten ThemeMode (system/light/dark) und
// persistiert ihn in SharedPreferences - Architektur bewusst analog zu
// LocaleNotifier in i18n/app_strings.dart.
//
// Warum kein reines Theme.of(context)? Ein Großteil der App verwendet
// globale Farb-Konstanten (kGold, kCardColor, ...) aus widgets/common.dart,
// die auch außerhalb eines BuildContext gebraucht werden (z.B. als
// Default-Werte oder in statischen Helper-Methoden). ThemeNotifier.isDark
// ist daher ein einfacher globaler Schalter, den diese Konstanten (als
// Getter statt const) live abfragen. Die eigentlichen ThemeData-Objekte
// unten werden zusätzlich ganz normal an MaterialApp.theme/darkTheme
// übergeben, damit auch Standard-Material-Widgets (TextField-Cursor,
// Ripple-Farben, Dialog-Formen, ...) korrekt reagieren.

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  static const _prefsKey = 'app_theme_mode';
  static final ThemeNotifier instance = ThemeNotifier._();
  ThemeNotifier._();

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  /// Aufgelöster Hell/Dunkel-Zustand. Bei ThemeMode.system wird die
  /// aktuelle Plattform-Helligkeit abgefragt (Betriebssystem-Einstellung).
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

  /// Lädt den gespeicherten Modus aus SharedPreferences.
  /// Falls noch keiner gespeichert: Default "system".
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
      // SharedPreferences nicht verfügbar (z.B. Test) -> Default.
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
      // Auswahl gilt dann nur für die aktuelle Session.
    }
  }

  /// Wird von einem WidgetsBindingObserver in main.dart aufgerufen, wenn
  /// sich die System-Helligkeit ändert während mode == system aktiv ist,
  /// damit die globalen Farb-Getter (kGold, kCardColor, ...) synchron
  /// bleiben und einen Rebuild auslösen.
  void handlePlatformBrightnessChanged() {
    if (_mode == ThemeMode.system) notifyListeners();
  }
}

// ── ThemeData für MaterialApp (theme:/darkTheme:) ──────────────────────────
// Dieselben Hex-Werte wie die Getter in widgets/common.dart (kCardColor,
// kBg, ...), damit App-Chrome (Scaffold/AppBar via ThemeData) und die
// manuell gesetzten Widget-Farben exakt übereinstimmen.
const Color kGoldConst = Color(0xFFFFA500);

ThemeData buildAppTheme({required bool dark}) {
  final scaffoldBg = dark ? const Color(0xFF2C2C2C) : const Color(0xFFF1F1F1);
  final surface = dark ? const Color(0xFF1C1C1C) : const Color(0xFFFFFFFF);
  final onSurface = dark ? Colors.white : const Color(0xFF1A1A1A);
  return ThemeData(
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
