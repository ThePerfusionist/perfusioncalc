// Internationalisierung (i18n) für PerfusionCalc
// ===============================================
// Eigene, leichtgewichtige Lösung mit zwei Sprachen (EN/DE).
//
// Architektur:
//   - AppLocale: enum mit unterstützten Sprachen
//   - LocaleNotifier: ChangeNotifier, hält die aktive Sprache, persistent
//     in SharedPreferences. Wird in main.dart oben in den Widget-Tree gestellt.
//   - Strings: alle UI-Texte als statische Maps
//   - t(): globaler Helfer, der den aktuellen Wert der LocaleNotifier nutzt
//
// Wissenschaftliche Quellenangaben (DuBois 1916, Severinghaus 1979 etc.)
// werden bewusst NICHT übersetzt - das ist internationale Konvention.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ════════════════════════════════════════════════════════════════════════════
// Locale enum + global notifier
// ════════════════════════════════════════════════════════════════════════════

enum AppLocale { en, de }

extension AppLocaleX on AppLocale {
  String get code => name; // 'en' / 'de'
  String get displayName => switch (this) {
        AppLocale.en => 'English',
        AppLocale.de => 'Deutsch',
      };
  String get flag => switch (this) {
        AppLocale.en => '🇬🇧',
        AppLocale.de => '🇩🇪',
      };
}

/// Singleton: die aktive Sprache der App.
/// Beim App-Start wird in main.dart einmal load() aufgerufen.
class LocaleNotifier extends ChangeNotifier {
  static const _prefsKey = 'app_locale';
  static final LocaleNotifier instance = LocaleNotifier._();
  LocaleNotifier._();

  AppLocale _current = AppLocale.en;
  AppLocale get current => _current;

  /// Lädt die gespeicherte Sprache aus SharedPreferences.
  /// Falls noch keine gespeichert: Default Englisch.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefsKey);
      _current = AppLocale.values.firstWhere(
        (l) => l.code == code,
        orElse: () => AppLocale.en,
      );
      notifyListeners();
    } catch (_) {
      // SharedPreferences nicht verfügbar (z.B. Test) -> Default
      _current = AppLocale.en;
    }
  }

  /// Wechselt die Sprache und speichert sie.
  Future<void> setLocale(AppLocale l) async {
    if (l == _current) return;
    _current = l;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, l.code);
    } catch (_) {
      // Speichern fehlgeschlagen -> wird beim nächsten Start auf Default zurückfallen
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Übersetzungen
// ════════════════════════════════════════════════════════════════════════════
//
// Konvention: snake_case-Keys nach Bedeutung gruppiert. Einmal definiert,
// für beide Sprachen. Wenn ein Key in DE fehlt, wird auf EN zurückgefallen.
// Das verhindert Crashes bei unvollständigen Übersetzungen.

class Strings {
  static const Map<String, Map<AppLocale, String>> _all = {

    // ── App / Navigation ──────────────────────────────────────────────────
    'app_title':              {AppLocale.en: 'PerfusionCalc', AppLocale.de: 'PerfusionCalc'},
    'navigation':             {AppLocale.en: 'Navigation', AppLocale.de: 'Navigation'},
    'language':               {AppLocale.en: 'Language', AppLocale.de: 'Sprache'},

    // ── Tabs ──────────────────────────────────────────────────────────────
    'tab_bsa':                {AppLocale.en: 'BSA/CO/Hb/Hct',
                               AppLocale.de: 'KOF/HZV/Hb/Hkt'},
    'tab_o2':                 {AppLocale.en: 'O\u2082 delivery',
                               AppLocale.de: 'O\u2082-Versorgung'},
    'tab_resistances':        {AppLocale.en: 'Resistances',
                               AppLocale.de: 'Widerstände'},
    'tab_electrolytes':       {AppLocale.en: 'Electrolytes/Buffer',
                               AppLocale.de: 'Elektrolyte/Puffer'},
    'tab_tube_volume':        {AppLocale.en: 'Tube volume',
                               AppLocale.de: 'Schlauchvolumen'},
    'tab_flow':               {AppLocale.en: 'Flow/Drainage rate',
                               AppLocale.de: 'Fluss/Drainagerate'},
    'tab_zoll':               {AppLocale.en: 'Zoll/Chairre',
                               AppLocale.de: 'Zoll/Charrière'},
    'tab_hypothermia':        {AppLocale.en: 'Hypothermia',
                               AppLocale.de: 'Hypothermie'},
    'tab_pediatric':          {AppLocale.en: 'Pediatric',
                               AppLocale.de: 'Pädiatrie'},
    'tab_reference':          {AppLocale.en: 'Reference values pressure',
                               AppLocale.de: 'Referenzwerte Druck'},
    'tab_anatomy':            {AppLocale.en: 'Heart Anatomy',
                               AppLocale.de: 'Herzanatomie'},

    // ── Disclaimer Dialog ─────────────────────────────────────────────────
    'disclaimer_title':       {AppLocale.en: 'Disclaimer',
                               AppLocale.de: 'Haftungsausschluss'},
    'disclaimer_clinical':    {AppLocale.en: 'Not for clinical use!',
                               AppLocale.de: 'Nicht für den klinischen Einsatz!'},
    'disclaimer_education':   {AppLocale.en: 'Only for education!',
                               AppLocale.de: 'Nur zu Ausbildungszwecken!'},
    'disclaimer_personal':    {AppLocale.en: 'Only for personal use!',
                               AppLocale.de: 'Nur zur persönlichen Nutzung!'},
    'disclaimer_noguarantee': {AppLocale.en: 'No guarantee of the results!',
                               AppLocale.de: 'Keine Garantie für die Ergebnisse!'},
    'disclaimer_legal_title': {AppLocale.en: 'Legal Notice',
                               AppLocale.de: 'Rechtlicher Hinweis'},
    'disclaimer_legal_1':     {AppLocale.en: 'All content and tools are for educational use only, are not meant to be a substitute for professional advice and should not be used for medical diagnosis and/or medical treatment.',
                               AppLocale.de: 'Alle Inhalte und Werkzeuge dienen ausschließlich Ausbildungszwecken, sind kein Ersatz für professionelle Beratung und dürfen nicht zur medizinischen Diagnose und/oder Behandlung verwendet werden.'},
    'disclaimer_legal_2':     {AppLocale.en: 'Reliance on or use of any information obtained through this Application is solely at your own risk. We are not responsible or liable for any outcome based on your decision to utilise the information provided through this application.',
                               AppLocale.de: 'Das Vertrauen auf oder die Nutzung von Informationen aus dieser Anwendung erfolgt ausschließlich auf eigenes Risiko. Wir übernehmen keine Verantwortung oder Haftung für Konsequenzen, die sich aus Ihrer Entscheidung ergeben, die in dieser Anwendung bereitgestellten Informationen zu nutzen.'},
    'disclaimer_legal_3':     {AppLocale.en: 'You are encouraged and instructed to confirm any information with other sources.',
                               AppLocale.de: 'Es wird ausdrücklich empfohlen, alle Informationen mit anderen Quellen zu überprüfen.'},
    'disclaimer_understand':  {AppLocale.en: 'I understand', AppLocale.de: 'Ich verstehe'},

    // ── Info Dialog ────────────────────────────────────────────────────────
    'info_title':             {AppLocale.en: 'Info', AppLocale.de: 'Info'},
    'info_version':           {AppLocale.en: 'Version', AppLocale.de: 'Version'},
    'info_license':           {AppLocale.en: 'License', AppLocale.de: 'Lizenz'},
    'info_created':           {AppLocale.en: 'Created', AppLocale.de: 'Erstellt'},
    'info_created_value':     {AppLocale.en: 'with \u{1F916} by ThePerfusionist',
                               AppLocale.de: 'mit \u{1F916} von ThePerfusionist'},
    'info_github':            {AppLocale.en: 'GitHub', AppLocale.de: 'GitHub'},
    'close':                  {AppLocale.en: 'Close', AppLocale.de: 'Schließen'},

    // ── Plausibility-Tooltip (Warnung im InputCard) ───────────────────────
    'plausibility_warning':   {AppLocale.en: 'Unusual value',
                               AppLocale.de: 'Ungewöhnlicher Wert'},
    'plausibility_plausible': {AppLocale.en: 'Plausible',
                               AppLocale.de: 'Plausibel'},

    // ── BSA Screen ─────────────────────────────────────────────────────────
    'bsa_body_height':        {AppLocale.en: 'Body height', AppLocale.de: 'Körpergröße'},
    'bsa_body_weight':        {AppLocale.en: 'Body weight', AppLocale.de: 'Körpergewicht'},
    'bsa_current_hb':         {AppLocale.en: 'Current Hb',  AppLocale.de: 'Aktueller Hb'},
    'bsa_current_hct':        {AppLocale.en: 'Current Hct', AppLocale.de: 'Aktueller Hkt'},
    'bsa_priming_volume':     {AppLocale.en: 'Priming volume',
                               AppLocale.de: 'Primingvolumen'},
    'bsa_cardiac_index':      {AppLocale.en: 'Cardiac index', AppLocale.de: 'Herzindex'},
    'bsa_saved':              {AppLocale.en: 'saved', AppLocale.de: 'gespeichert'},
    'bsa_saved_hint':         {AppLocale.en: 'Default 2.4  ·  Value is saved between sessions',
                               AppLocale.de: 'Standard 2.4  ·  Wert wird zwischen Sitzungen gespeichert'},
    'bsa_result_dubois':      {AppLocale.en: 'BSA (DuBois)', AppLocale.de: 'KOF (DuBois)'},
    'bsa_result_co':          {AppLocale.en: 'Cardiac output', AppLocale.de: 'Herzzeitvolumen'},
    'bsa_result_bv_male':     {AppLocale.en: 'Blood volume man',
                               AppLocale.de: 'Blutvolumen Mann'},
    'bsa_result_bv_female':   {AppLocale.en: 'Blood volume woman',
                               AppLocale.de: 'Blutvolumen Frau'},
    'bsa_section_expected':   {AppLocale.en: 'Expected Hb/Hct after priming',
                               AppLocale.de: 'Erwarteter Hb/Hkt nach Priming'},
    'bsa_expected_hb':        {AppLocale.en: 'Expected Hb',
                               AppLocale.de: 'Erwarteter Hb'},
    'bsa_expected_hct_m':     {AppLocale.en: 'Expected Hct (man)',
                               AppLocale.de: 'Erwarteter Hkt (Mann)'},
    'bsa_expected_hct_f':     {AppLocale.en: 'Expected Hct (woman)',
                               AppLocale.de: 'Erwarteter Hkt (Frau)'},
  };

  /// Übersetze einen Key. Fällt auf EN zurück, wenn DE-Übersetzung fehlt;
  /// gibt den Key selbst zurück, wenn überhaupt nicht definiert (sichtbar
  /// als "Bug-Marker").
  static String of(String key, AppLocale locale) {
    final entry = _all[key];
    if (entry == null) return '⟨$key⟩'; // sichtbar machen, falls vergessen
    return entry[locale] ?? entry[AppLocale.en] ?? '⟨$key⟩';
  }
}

/// Globaler Kurz-Helfer. Verwendung: `t('bsa_body_height')`.
/// Liest die aktuell aktive Sprache aus dem LocaleNotifier-Singleton.
String t(String key) => Strings.of(key, LocaleNotifier.instance.current);
