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
    'source':                 {AppLocale.en: 'Source',  AppLocale.de: 'Quelle'},
    'sources':                {AppLocale.en: 'Sources', AppLocale.de: 'Quellen'},

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

    // ── O2 Delivery Screen ────────────────────────────────────────────────
    'o2_bsa':                 {AppLocale.en: 'BSA', AppLocale.de: 'KOF'},
    'o2_art_hb':              {AppLocale.en: 'art. Hb', AppLocale.de: 'art. Hb'},
    'o2_ven_hb':              {AppLocale.en: 'ven. Hb', AppLocale.de: 'ven. Hb'},
    'o2_min_co':              {AppLocale.en: 'Min. cardiac output',
                               AppLocale.de: 'Min. HZV'},
    'o2_min_hb':              {AppLocale.en: 'Min. Hb', AppLocale.de: 'Min. Hb'},
    'o2_min_at':              {AppLocale.en: 'at 272 ml/min/m\u00b2 DO\u2082i',
                               AppLocale.de: 'bei 272 ml/min/m\u00b2 DO\u2082i'},
    'o2_chart':               {AppLocale.en: 'Chart', AppLocale.de: 'Diagramm'},
    'o2_chart_title':         {AppLocale.en: 'Oxygen Delivery Calculation Chart',
                               AppLocale.de: 'Sauerstoffversorgungs-Berechnungsdiagramm'},
    'o2_co_label':            {AppLocale.en: 'Cardiac output', AppLocale.de: 'Herzzeitvolumen'},
    'o2_ci_label':            {AppLocale.en: 'Cardiac index', AppLocale.de: 'Herzindex'},
    'o2_enter_value':         {AppLocale.en: 'Enter value', AppLocale.de: 'Wert eingeben'},

    // ── Resistances Screen ────────────────────────────────────────────────
    'res_co_for_svr':         {AppLocale.en: 'Cardiac output (for SVR)',
                               AppLocale.de: 'Herzzeitvolumen (für SVR)'},
    'res_co_for_pvr':         {AppLocale.en: 'Cardiac output (for PVR)',
                               AppLocale.de: 'Herzzeitvolumen (für PVR)'},

    // ── Electrolytes Screen ───────────────────────────────────────────────
    'elec_section_sodium':    {AppLocale.en: 'Sodium', AppLocale.de: 'Natrium'},
    'elec_section_potassium': {AppLocale.en: 'Potassium', AppLocale.de: 'Kalium'},
    'elec_section_calcium':   {AppLocale.en: 'Calcium', AppLocale.de: 'Calcium'},
    'elec_section_buffer':    {AppLocale.en: 'Buffer', AppLocale.de: 'Puffer'},
    'elec_sodium_current':    {AppLocale.en: 'Sodium current',  AppLocale.de: 'Natrium aktuell'},
    'elec_sodium_target':     {AppLocale.en: 'Sodium target',   AppLocale.de: 'Natrium Ziel'},
    'elec_sodium_need':       {AppLocale.en: 'Sodium need',     AppLocale.de: 'Natrium-Bedarf'},
    'elec_potassium_current': {AppLocale.en: 'Potassium current',
                               AppLocale.de: 'Kalium aktuell'},
    'elec_potassium_target':  {AppLocale.en: 'Potassium target', AppLocale.de: 'Kalium Ziel'},
    'elec_potassium_need':    {AppLocale.en: 'Potassium need',   AppLocale.de: 'Kalium-Bedarf'},
    'elec_calcium_current':   {AppLocale.en: 'Calcium current',  AppLocale.de: 'Calcium aktuell'},
    'elec_calcium_target':    {AppLocale.en: 'Calcium target',   AppLocale.de: 'Calcium Ziel'},
    'elec_calcium_need':      {AppLocale.en: 'Calcium need',     AppLocale.de: 'Calcium-Bedarf'},
    'elec_base_excess':       {AppLocale.en: 'Base Excess',      AppLocale.de: 'Base Excess'},

    // ── Tube Volume Screen ────────────────────────────────────────────────
    'tube_length':            {AppLocale.en: 'Tube length', AppLocale.de: 'Schlauchlänge'},
    'tube_section_fill':      {AppLocale.en: 'Fill volume per cm \u00d7 length (ml)',
                               AppLocale.de: 'Füllvolumen pro cm \u00d7 Länge (ml)'},

    // ── Flow / Drainage Screen ────────────────────────────────────────────
    'flow_title':             {AppLocale.en: 'Flow / Drainage Rate',
                               AppLocale.de: 'Fluss / Drainagerate'},
    'flow_col_tube':          {AppLocale.en: 'Tube', AppLocale.de: 'Schlauch'},
    'flow_col_max_flow':      {AppLocale.en: 'Max. Flow',  AppLocale.de: 'Max. Fluss'},
    'flow_col_max_drainage':  {AppLocale.en: 'Max. Drainage',
                               AppLocale.de: 'Max. Drainage'},

    // ── Zoll / Charrière Screen ───────────────────────────────────────────
    'zoll_title_diameter':    {AppLocale.en: 'Tube Diameter Reference',
                               AppLocale.de: 'Schlauchdurchmesser-Referenz'},
    'zoll_col_size':          {AppLocale.en: 'Size',       AppLocale.de: 'Größe'},
    'zoll_col_diameter':      {AppLocale.en: 'Diameter',   AppLocale.de: 'Durchmesser'},
    'zoll_col_charriere':     {AppLocale.en: 'Charriere',  AppLocale.de: 'Charrière'},
    'zoll_converter_title':   {AppLocale.en: 'Charriere Converter',
                               AppLocale.de: 'Charrière-Umrechner'},
    'zoll_ch_to_mm':          {AppLocale.en: 'Charriere to millimeter',
                               AppLocale.de: 'Charrière zu Millimeter'},
    'zoll_mm_to_ch':          {AppLocale.en: 'Millimeter to Charriere',
                               AppLocale.de: 'Millimeter zu Charrière'},
    'zoll_result_mm':         {AppLocale.en: 'Millimeter', AppLocale.de: 'Millimeter'},
    'zoll_result_ch':         {AppLocale.en: 'Charriere',  AppLocale.de: 'Charrière'},

    // ── Hypothermia Screen ────────────────────────────────────────────────
    'hypo_title_levels':      {AppLocale.en: 'Hypothermia Levels',
                               AppLocale.de: 'Hypothermie-Stufen'},
    'hypo_title_bga':         {AppLocale.en: 'BGA Temperature Correction',
                               AppLocale.de: 'BGA-Temperaturkorrektur'},
    'hypo_col_level':         {AppLocale.en: 'Level',          AppLocale.de: 'Stufe'},
    'hypo_col_range':         {AppLocale.en: 'Range',          AppLocale.de: 'Bereich'},
    'hypo_col_arrest':        {AppLocale.en: 'Circ. arrest',   AppLocale.de: 'Kreisl.-Stillstand'},
    'hypo_col_o2req':         {AppLocale.en: 'O\u2082 req.',   AppLocale.de: 'O\u2082-Bedarf'},
    'hypo_lvl_light':         {AppLocale.en: 'Light (mild)',   AppLocale.de: 'Leicht'},
    'hypo_lvl_moderate':      {AppLocale.en: 'Moderate',       AppLocale.de: 'Mittel'},
    'hypo_lvl_deep':          {AppLocale.en: 'Deep',           AppLocale.de: 'Tief'},
    'hypo_lvl_profound':      {AppLocale.en: 'Profound',       AppLocale.de: 'Sehr tief'},
    'hypo_temp':              {AppLocale.en: 'Patient temperature',
                               AppLocale.de: 'Patiententemperatur'},
    'hypo_pao2':              {AppLocale.en: 'PaO\u2082 (measured at 37 °C)',
                               AppLocale.de: 'PaO\u2082 (gemessen bei 37 °C)'},
    'hypo_paco2':             {AppLocale.en: 'PaCO\u2082 (measured at 37 °C)',
                               AppLocale.de: 'PaCO\u2082 (gemessen bei 37 °C)'},
    'hypo_ph':                {AppLocale.en: 'pH (measured at 37 °C)',
                               AppLocale.de: 'pH (gemessen bei 37 °C)'},
    'hypo_hint_enter':        {AppLocale.en: 'Enter patient temperature and at least one BGA value',
                               AppLocale.de: 'Patiententemperatur und mindestens einen BGA-Wert eingeben'},
    'hypo_section_corrected': {AppLocale.en: 'Corrected values at patient temperature',
                               AppLocale.de: 'Korrigierte Werte bei Patiententemperatur'},
    'hypo_corr_pao2':         {AppLocale.en: 'PaO\u2082 (T-corrected)',
                               AppLocale.de: 'PaO\u2082 (T-korrigiert)'},
    'hypo_corr_paco2':        {AppLocale.en: 'PaCO\u2082 (T-corrected)',
                               AppLocale.de: 'PaCO\u2082 (T-korrigiert)'},
    'hypo_corr_ph':           {AppLocale.en: 'pH (T-corrected)',
                               AppLocale.de: 'pH (T-korrigiert)'},
    'hypo_hco3':              {AppLocale.en: 'HCO\u2083\u207b (Henderson-Hasselbalch)',
                               AppLocale.de: 'HCO\u2083\u207b (Henderson-Hasselbalch)'},
    'hypo_sat':               {AppLocale.en: 'SaO\u2082 (O\u2082 dissociation curve)',
                               AppLocale.de: 'SaO\u2082 (O\u2082-Dissoziationskurve)'},
    'hypo_temp_coeff':        {AppLocale.en: 'Temperature coefficient',
                               AppLocale.de: 'Temperaturkoeffizient'},
    'hypo_temp_coeff_note':   {AppLocale.en: 'Varies: ~7.4 %/°C at low, ~1.3 %/°C at high saturation',
                               AppLocale.de: 'Variiert: ~7.4 %/°C bei niedriger, ~1.3 %/°C bei hoher Sättigung'},
    'hypo_section_thumb':     {AppLocale.en: 'Clinical thumb rules (per 1 °C below 37 °C)',
                               AppLocale.de: 'Klinische Faustregeln (pro 1 °C unter 37 °C)'},
    'hypo_col_param':         {AppLocale.en: 'Parameter', AppLocale.de: 'Parameter'},
    'hypo_col_rule':          {AppLocale.en: 'Rule',      AppLocale.de: 'Regel'},
    'hypo_col_dtotal':        {AppLocale.en: '\u0394 total', AppLocale.de: '\u0394 gesamt'},
    'hypo_col_unit':          {AppLocale.en: 'Unit',      AppLocale.de: 'Einheit'},

    // ── Pediatric Screen ──────────────────────────────────────────────────
    'ped_title_tube':         {AppLocale.en: 'Tube diameter (Darling et al. 2000)',
                               AppLocale.de: 'Schlauchdurchmesser (Darling et al. 2000)'},
    'ped_title_perfusion':    {AppLocale.en: 'Perfusion rate (Tschaut 2020)',
                               AppLocale.de: 'Perfusionsrate (Tschaut 2020)'},
    'ped_title_va':           {AppLocale.en: 'V-A cannula size (Finck 2020)',
                               AppLocale.de: 'V-A Kanülengröße (Finck 2020)'},
    'ped_title_vv':           {AppLocale.en: 'V-V cannula size (Finck 2020)',
                               AppLocale.de: 'V-V Kanülengröße (Finck 2020)'},
    'ped_title_bv':           {AppLocale.en: 'Pediatric blood volume',
                               AppLocale.de: 'Pädiatrisches Blutvolumen'},
    'ped_title_transfusion':  {AppLocale.en: 'Transfusion volume',
                               AppLocale.de: 'Transfusionsvolumen'},
    'ped_col_weight':         {AppLocale.en: 'Weight (kg)', AppLocale.de: 'Gewicht (kg)'},
    'ped_col_art_line':       {AppLocale.en: 'Art. Line',   AppLocale.de: 'Art. Linie'},
    'ped_col_ven_line':       {AppLocale.en: 'Ven. Line',   AppLocale.de: 'Ven. Linie'},
    'ped_col_flow':           {AppLocale.en: 'Flow (ml/kg/min)',
                               AppLocale.de: 'Fluss (ml/kg/min)'},
    'ped_bv_premature':       {AppLocale.en: 'Premature infants', AppLocale.de: 'Frühgeborene'},
    'ped_bv_babies':          {AppLocale.en: 'Babies < 3 months',
                               AppLocale.de: 'Säuglinge < 3 Monate'},
    'ped_bv_children':        {AppLocale.en: 'Children \u2265 3 months',
                               AppLocale.de: 'Kinder \u2265 3 Monate'},
    'ped_bv_male':            {AppLocale.en: 'Male adolescents',
                               AppLocale.de: 'Männliche Jugendliche'},
    'ped_bv_female':          {AppLocale.en: 'Female adolescents',
                               AppLocale.de: 'Weibliche Jugendliche'},
    'ped_desired_hb':         {AppLocale.en: 'Desired Hb increase',
                               AppLocale.de: 'Gewünschter Hb-Anstieg'},
    'ped_transfusion_vol':    {AppLocale.en: 'Transfusion volume',
                               AppLocale.de: 'Transfusionsvolumen'},
    'ped_hct_in_ek':          {AppLocale.en: 'Hct in EK = 55%',
                               AppLocale.de: 'Hkt in EK = 55%'},

    // ── Reference Pressure Screen ─────────────────────────────────────────
    'ref_section_arterial':   {AppLocale.en: 'Arterial pressure (AP)',
                               AppLocale.de: 'Arterieller Druck (AP)'},
    'ref_section_lv':         {AppLocale.en: 'Left Ventricle (LV)',
                               AppLocale.de: 'Linker Ventrikel (LV)'},
    'ref_section_la':         {AppLocale.en: 'Left Atrium (LA)',
                               AppLocale.de: 'Linker Vorhof (LA)'},
    'ref_section_ra':         {AppLocale.en: 'Right Atrium (RA)',
                               AppLocale.de: 'Rechter Vorhof (RA)'},
    'ref_section_rv':         {AppLocale.en: 'Right Ventricle (RV)',
                               AppLocale.de: 'Rechter Ventrikel (RV)'},
    'ref_section_pcwp':       {AppLocale.en: 'Pulmonary Capillary Pressure (PCWP)',
                               AppLocale.de: 'Pulmonalkapillärer Druck (PCWP)'},
    'ref_section_pap':        {AppLocale.en: 'Pulmonary Artery (PAP)',
                               AppLocale.de: 'Pulmonalarterie (PAP)'},
    'ref_section_cvp':        {AppLocale.en: 'Central Venous Pressure',
                               AppLocale.de: 'Zentralvenöser Druck'},
    'ref_systolic':           {AppLocale.en: 'Systolic',      AppLocale.de: 'Systolisch'},
    'ref_diastolic':          {AppLocale.en: 'Diastolic',     AppLocale.de: 'Diastolisch'},
    'ref_mean':               {AppLocale.en: 'Mean pressure', AppLocale.de: 'Mitteldruck'},
    'ref_col_normal':         {AppLocale.en: 'Normal',        AppLocale.de: 'Normal'},
    'ref_col_range':          {AppLocale.en: 'Range',         AppLocale.de: 'Bereich'},
    'ref_title_main':         {AppLocale.en: 'Reference Values – Pressure',
                               AppLocale.de: 'Referenzwerte – Druck'},
    'ref_spontaneous':        {AppLocale.en: 'Spontaneous breathing',
                               AppLocale.de: 'Spontanatmung'},

    // ── Heart Anatomy Screen ──────────────────────────────────────────────
    'anat_coronary_ant':      {AppLocale.en: 'Coronary Circulation (Anterior)',
                               AppLocale.de: 'Koronarkreislauf (Vorderseite)'},
    'anat_coronary_post':     {AppLocale.en: 'Coronary Circulation (Posterior)',
                               AppLocale.de: 'Koronarkreislauf (Rückseite)'},
    'anat_cross_section':     {AppLocale.en: 'Heart Cross-Section',
                               AppLocale.de: 'Herzquerschnitt'},
    'anat_coronary_arteries': {AppLocale.en: 'Coronary Arteries – Schematic',
                               AppLocale.de: 'Koronararterien – Schema'},
    'anat_desc_ant':          {AppLocale.en: 'Anterior view of the coronary circulation showing left and right coronary arteries, circumflex artery, anterior interventricular artery, marginal artery, and cardiac veins.',
                               AppLocale.de: 'Ansicht des Koronarkreislaufs von vorne mit linker und rechter Koronararterie, Ramus circumflexus, vorderer interventrikulärer Arterie, Randarterie und Herzvenen.'},
    'anat_desc_post':         {AppLocale.en: 'Posterior view showing the right coronary artery, posterior interventricular artery, coronary sinus, and cardiac veins.',
                               AppLocale.de: 'Rückansicht mit rechter Koronararterie, hinterer interventrikulärer Arterie, Sinus coronarius und Herzvenen.'},
    'anat_desc_cross':        {AppLocale.en: 'Cross-sectional view of the heart showing the four chambers (right/left atrium, right/left ventricle), four valves (tricuspid, pulmonary, mitral, aortic), and the great vessels.',
                               AppLocale.de: 'Querschnittsansicht des Herzens mit den vier Kammern (rechter/linker Vorhof, rechter/linker Ventrikel), vier Klappen (Trikuspidal-, Pulmonal-, Mitral-, Aortenklappe) und den großen Gefäßen.'},
    'anat_desc_schema':       {AppLocale.en: 'Schematic diagram of the coronary arteries including left main, LAD, circumflex, and right coronary artery with their main branches.',
                               AppLocale.de: 'Schematisches Diagramm der Koronararterien mit Hauptstamm, RIVA (LAD), Ramus circumflexus und rechter Koronararterie samt ihren Hauptästen.'},
    'anat_pinch_zoom':        {AppLocale.en: 'Pinch to zoom · Drag to pan',
                               AppLocale.de: 'Zoom durch Pinch · Verschieben durch Ziehen'},
    // ── Heart Anatomy launcher (external HTML page) ───────────────────────
    'anat_open_description':  {AppLocale.en: 'View the heart anatomy diagrams in a separate page for the best experience and full browser compatibility.',
                               AppLocale.de: 'Die Herzanatomie-Diagramme in einer separaten Seite ansehen – für beste Darstellung und volle Browser-Kompatibilität.'},
    'anat_open_button':       {AppLocale.en: 'Open Heart Anatomy',
                               AppLocale.de: 'Herzanatomie öffnen'},
    'anat_compatibility_note':{AppLocale.en: 'Anatomy diagrams are shown on a dedicated page so they display reliably in every browser, including privacy-focused browsers without WebGL.',
                               AppLocale.de: 'Die Anatomie-Diagramme werden auf einer eigenen Seite angezeigt, damit sie in jedem Browser zuverlässig dargestellt werden – auch in Privacy-Browsern ohne WebGL.'},
    'anat_web_only_hint':     {AppLocale.en: 'Available in web version only',
                               AppLocale.de: 'Nur in der Web-Version verfügbar'},
    // ── Pediatric cannula sizes launcher ──────────────────────────────────
    'ped_cannula_section_title':{AppLocale.en: 'V-A & V-V cannula size tables (Finck 2020)',
                                 AppLocale.de: 'V-A & V-V Kanülengröße-Tabellen (Finck 2020)'},
    'ped_cannula_section_desc':{AppLocale.en: 'Detailed tables for selecting V-A and V-V cannula sizes by patient weight.',
                                AppLocale.de: 'Detaillierte Tabellen zur Auswahl von V-A und V-V Kanülengrößen nach Patientengewicht.'},
    'ped_cannula_open_button':{AppLocale.en: 'Open cannula size tables',
                               AppLocale.de: 'Kanülengröße-Tabellen öffnen'},
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
