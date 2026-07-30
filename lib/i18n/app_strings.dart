// Internationalization (i18n) for PerfusionCalc
// ================================================
// Custom, lightweight solution with two languages (EN/DE).
//
// Architecture:
//   - AppLocale: enum with supported languages
//   - LocaleNotifier: ChangeNotifier, holds the active language, persisted
//     in SharedPreferences. Placed near the top of the widget tree in main.dart.
//   - Strings: all UI text as static maps
//   - t(): global helper that reads the current value from LocaleNotifier

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

/// Singleton: the app's active language.
/// load() is called once in main.dart on app start.
class LocaleNotifier extends ChangeNotifier {
  static const _prefsKey = 'app_locale';
  static final LocaleNotifier instance = LocaleNotifier._();
  LocaleNotifier._();

  AppLocale _current = AppLocale.en;
  AppLocale get current => _current;

  /// Loads the saved language from SharedPreferences.
  /// If none is saved yet: defaults to English.
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
      // SharedPreferences unavailable (e.g. in tests) -> default
      _current = AppLocale.en;
    }
  }

  /// Switches the language and persists it.
  Future<void> setLocale(AppLocale l) async {
    if (l == _current) return;
    _current = l;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, l.code);
    } catch (_) {
      // Save failed -> will fall back to default on next start
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Translations
// ════════════════════════════════════════════════════════════════════════════
//
// Convention: snake_case keys grouped by meaning. Defined once, for both
// languages. If a key is missing in DE, it falls back to EN. This prevents
// crashes from incomplete translations.

class Strings {
  static const Map<String, Map<AppLocale, String>> _all = {

    // ── App / Navigation ──────────────────────────────────────────────────
    'app_title':              {AppLocale.en: 'PerfusionCalc', AppLocale.de: 'PerfusionCalc'},
    'navigation':             {AppLocale.en: 'Navigation', AppLocale.de: 'Navigation'},
    'language':               {AppLocale.en: 'Language', AppLocale.de: 'Sprache'},
    'theme':                  {AppLocale.en: 'Appearance', AppLocale.de: 'Darstellung'},
    'theme_system':           {AppLocale.en: 'System', AppLocale.de: 'System'},
    'theme_light':            {AppLocale.en: 'Light', AppLocale.de: 'Hell'},
    'theme_dark':             {AppLocale.en: 'Dark', AppLocale.de: 'Dunkel'},
    'source':                 {AppLocale.en: 'Source',  AppLocale.de: 'Quelle'},
    'sources':                {AppLocale.en: 'Sources', AppLocale.de: 'Quellen'},
    // ── PDF Export ────────────────────────────────────────────────────────
    'pdf_export_button':      {AppLocale.en: 'Export as PDF',
                               AppLocale.de: 'Als PDF exportieren'},
    'pdf_inputs':             {AppLocale.en: 'Inputs',
                               AppLocale.de: 'Eingaben'},
    'pdf_results':            {AppLocale.en: 'Results',
                               AppLocale.de: 'Ergebnisse'},
    'pdf_export_failed':      {AppLocale.en: 'PDF export failed',
                               AppLocale.de: 'PDF-Export fehlgeschlagen'},
    'combined_report_button': {AppLocale.en: 'Export combined report',
                               AppLocale.de: 'Gesamtbericht exportieren'},
    'combined_report_empty':  {AppLocale.en: 'No data entered yet - please fill in at least one tab first.',
                               AppLocale.de: 'Noch keine Daten erfasst - bitte zuerst mindestens einen Tab ausfüllen.'},

    // ── Accessibility (screen reader labels) ────────────────────────────────
    'a11y_increase':          {AppLocale.en: 'Increase', AppLocale.de: 'Erhöhen'},
    'a11y_decrease':          {AppLocale.en: 'Decrease', AppLocale.de: 'Verringern'},
    'a11y_warning':           {AppLocale.en: 'Warning', AppLocale.de: 'Warnung'},
    'a11y_open_menu':         {AppLocale.en: 'Open navigation menu', AppLocale.de: 'Navigationsmenü öffnen'},
    'a11y_app_info':          {AppLocale.en: 'App information', AppLocale.de: 'App-Informationen'},
    'a11y_close_app':         {AppLocale.en: 'Close app', AppLocale.de: 'App schließen'},
    'a11y_view_fullscreen':   {AppLocale.en: 'View image fullscreen', AppLocale.de: 'Bild in Vollansicht öffnen'},
    'a11y_close_fullscreen':  {AppLocale.en: 'Close fullscreen view', AppLocale.de: 'Vollansicht schließen'},
    'a11y_selected':          {AppLocale.en: 'selected', AppLocale.de: 'ausgewählt'},

    // ── Tabs ──────────────────────────────────────────────────────────────
    'tab_bsa':                {AppLocale.en: 'BSA/CO/Hb/Hct',
                               AppLocale.de: 'KOF/HZV/Hb/Hkt'},
    'tab_o2':                 {AppLocale.en: 'O\u2082 delivery',
                               AppLocale.de: 'O\u2082-Versorgung'},
    'tab_resistances':        {AppLocale.en: 'Resistances',
                               AppLocale.de: 'Widerstände'},
    'tab_electrolytes':       {AppLocale.en: 'Electrolytes/Buffer',
                               AppLocale.de: 'Elektrolyte/Puffer'},
    'tab_ultrafiltration':    {AppLocale.en: 'Ultrafiltration',
                               AppLocale.de: 'Ultrafiltration'},
    'tab_cardioplegia':       {AppLocale.en: 'Cardioplegia',
                               AppLocale.de: 'Kardioplegie'},
    'tab_tube_volume':        {AppLocale.en: 'Tube volume & flow rate',
                               AppLocale.de: 'Schlauchvolumen & Flussrate'},
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
    'info_contact':           {AppLocale.en: 'Contact', AppLocale.de: 'Kontakt'},
    'info_github':            {AppLocale.en: 'GitHub', AppLocale.de: 'GitHub'},
    'close':                  {AppLocale.en: 'Close', AppLocale.de: 'Schließen'},

    // ── Plausibility tooltip (warning in InputCard) ─────────────────────────
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
    'enter_value':            {AppLocale.en: 'Enter value', AppLocale.de: 'Wert eingeben'},
    'missing_inputs_hint':    {AppLocale.en: 'Please enter: ',
                               AppLocale.de: 'Bitte eingeben: '},
    'result_below_threshold': {AppLocale.en: 'Below the clinically relevant threshold',
                               AppLocale.de: 'Unterhalb des klinisch relevanten Schwellenwerts'},
    'do2i_gdp_warning':       {AppLocale.en: 'Below the Goal-Directed-Perfusion threshold of 272 ml/min/m² — associated with increased risk of acute kidney injury (AKI).',
                               AppLocale.de: 'Unterhalb des Goal-Directed-Perfusion-Schwellenwerts von 272 ml/min/m² — assoziiert mit erhöhtem Risiko für ein akutes Nierenversagen (AKI).'},

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

    // ── Ultrafiltration Screen ───────────────────────────────────────────────
    'uf_current_volume':      {AppLocale.en: 'Current circulating volume',
                               AppLocale.de: 'Aktuelles Zirkulationsvolumen'},
    'uf_current_hct':         {AppLocale.en: 'Current hematocrit',
                               AppLocale.de: 'Aktueller Hämatokrit'},
    'uf_target_hct':          {AppLocale.en: 'Target hematocrit',
                               AppLocale.de: 'Ziel-Hämatokrit'},
    'uf_current_hb':          {AppLocale.en: 'Current hemoglobin',
                               AppLocale.de: 'Aktuelles Hämoglobin'},
    'uf_target_hb':           {AppLocale.en: 'Target hemoglobin',
                               AppLocale.de: 'Ziel-Hämoglobin'},
    'uf_metric_label':        {AppLocale.en: 'Concentration marker',
                               AppLocale.de: 'Konzentrationsmarker'},
    'uf_section_result':      {AppLocale.en: 'Ultrafiltration',
                               AppLocale.de: 'Ultrafiltration'},
    'uf_volume_remove':       {AppLocale.en: 'Volume to remove (UF)',
                               AppLocale.de: 'Zu entziehendes Volumen (UF)'},
    'uf_final_volume':        {AppLocale.en: 'Resulting circulating volume',
                               AppLocale.de: 'Resultierendes Zirkulationsvolumen'},
    'uf_warning_not_higher':  {AppLocale.en: 'Target must be higher than the current value - ultrafiltration can only concentrate blood, not dilute it.',
                               AppLocale.de: 'Der Zielwert muss höher als der aktuelle Wert sein - Ultrafiltration kann Blut nur konzentrieren, nicht verdünnen.'},
    'uf_principle_note':      {AppLocale.en: 'Assumes red-cell mass is conserved: only plasma water is filtered off, so hematocrit/hemoglobin \u00d7 volume stays constant.',
                               AppLocale.de: 'Setzt konstante Erythrozytenmasse voraus: nur Plasmawasser wird filtriert, daher bleibt Hämatokrit/Hämoglobin \u00d7 Volumen konstant.'},

    // ── Cardioplegia Screen ───────────────────────────────────────────────────
    'cardio_protocol_label':  {AppLocale.en: 'Protocol',
                               AppLocale.de: 'Protokoll'},
    'cardio_dose_per_kg':     {AppLocale.en: 'Dose',
                               AppLocale.de: 'Dosis'},
    'cardio_section_result':  {AppLocale.en: 'Cardioplegia volume',
                               AppLocale.de: 'Kardioplegievolumen'},
    'cardio_total_volume':    {AppLocale.en: 'Total dose volume',
                               AppLocale.de: 'Gesamtdosisvolumen'},
    'cardio_blood_volume':    {AppLocale.en: 'Blood component',
                               AppLocale.de: 'Blutanteil'},
    'cardio_crystalloid_volume': {AppLocale.en: 'Crystalloid component',
                               AppLocale.de: 'Kristalloidanteil'},
    'cardio_ratio_buckberg':  {AppLocale.en: 'Ratio: 4:1 blood : crystalloid',
                               AppLocale.de: 'Verhältnis: 4:1 Blut : Kristalloid'},
    'cardio_ratio_delnido':   {AppLocale.en: 'Ratio: 4:1 crystalloid : blood (i.e. 1:4 blood : crystalloid)',
                               AppLocale.de: 'Verhältnis: 4:1 Kristalloid : Blut (entspr. 1:4 Blut : Kristalloid)'},
    'cardio_interval_buckberg': {AppLocale.en: 'Repeat interval: every 15\u201320 min (maintenance dose, same rate as induction)',
                               AppLocale.de: 'Wiederholungsintervall: alle 15\u201320 min (Erhaltungsdosis, gleiche Rate wie Induktion)'},
    'cardio_interval_delnido': {AppLocale.en: 'Repeat interval: single dose, effective up to \u224890 min. If cross-clamp time exceeds 90\u2013120 min: redose \u2248500 ml.',
                               AppLocale.de: 'Wiederholungsintervall: Einzeldosis, wirksam bis ca. 90 min. Bei Klemmzeit über 90\u2013120 min: Nachdosierung \u2248500 ml.'},
    'cardio_calafiore_principle': {AppLocale.en: 'Warm oxygenated whole blood is the carrier; a K\u207a/Mg\u00b2\u207a mixture is continuously titrated in via a syringe pump (Perfusor) - no fixed blood:crystalloid ratio.',
                               AppLocale.de: 'Warmes oxygeniertes Vollblut dient als Trägermedium; eine K\u207a/Mg\u00b2\u207a-Mischung wird kontinuierlich per Perfusor beigemischt - kein festes Blut:Kristalloid-Verhältnis.'},
    'cardio_interval_calafiore': {AppLocale.en: 'Repeat interval: every 15\u201320 min. Pressure-controlled delivery (e.g. 90\u2013100 mmHg) makes flow variable \u2013 recalculate the Perfusor rate whenever flow changes.',
                               AppLocale.de: 'Wiederholungsintervall: alle 15\u201320 min. Bei druckgesteuerter Gabe (z.\u00a0B. 90\u2013100 mmHg) ist der Fluss variabel \u2013 Perfusorrate bei Flussänderung neu berechnen.'},
    'cardio_dose_number':      {AppLocale.en: 'Dose number',
                               AppLocale.de: 'Wievielte Gabe'},
    'cardio_target_alt_label': {AppLocale.en: 'Target [K\u207a] for this dose',
                               AppLocale.de: 'Ziel-[K\u207a] für diese Gabe'},
    'cardio_mg_bolus_dose2_hint': {AppLocale.en: 'May be raised to 500 mg on this dose if needed.',
                               AppLocale.de: 'Bei Bedarf kann bei dieser Gabe auf 500 mg erhöht werden.'},
    'cardio_syringe_section':  {AppLocale.en: 'Perfusor syringe',
                               AppLocale.de: 'Perfusorspritze'},
    'cardio_kcl_volume':       {AppLocale.en: 'KCl total volume',
                               AppLocale.de: 'KCl-Gesamtvolumen'},
    'cardio_kcl_conc':         {AppLocale.en: 'KCl concentration',
                               AppLocale.de: 'KCl-Konzentration'},
    'cardio_mg_volume':        {AppLocale.en: 'MgSO\u2084 total volume (optional)',
                               AppLocale.de: 'MgSO\u2084-Gesamtvolumen (optional)'},
    'cardio_mg_conc':          {AppLocale.en: 'MgSO\u2084 concentration (optional)',
                               AppLocale.de: 'MgSO\u2084-Konzentration (optional)'},
    'cardio_mg_optional_hint': {AppLocale.en: 'Magnesium in the syringe is optional \u2013 leaving these blank simply gives a pure KCl syringe; all other results stay valid.',
                               AppLocale.de: 'Magnesium in der Spritze ist optional \u2013 bleiben diese Felder leer, ergibt sich eine reine KCl-Spritze; alle übrigen Ergebnisse bleiben gültig.'},
    'cardio_syringe_k_conc':   {AppLocale.en: 'Resulting [K\u207a] in syringe',
                               AppLocale.de: 'Resultierendes [K\u207a] in der Spritze'},
    'cardio_syringe_mg_conc':  {AppLocale.en: 'Resulting [Mg\u00b2\u207a] in syringe',
                               AppLocale.de: 'Resultierendes [Mg\u00b2\u207a] in der Spritze'},
    'cardio_flow_section':     {AppLocale.en: 'Cardioplegia flow',
                               AppLocale.de: 'Kardioplegiefluss'},
    'cardio_flow':             {AppLocale.en: 'Current CPL pump flow (blood)',
                               AppLocale.de: 'Aktueller Fluss Kardioplegiepumpe (Blutanteil)'},
    'cardio_target_k':         {AppLocale.en: 'Target [K\u207a] of the CPL solution (this dose)',
                               AppLocale.de: 'Ziel-[K\u207a] der Kardioplegielösung (diese Gabe)'},
    'cardio_serum_k':          {AppLocale.en: 'Patient serum [K\u207a]',
                               AppLocale.de: 'Patienten-Serum-[K\u207a]'},
    'cardio_perfusor_rate':    {AppLocale.en: 'Perfusor rate',
                               AppLocale.de: 'Perfusorrate'},
    'cardio_mg_delivery':      {AppLocale.en: 'Continuous Mg\u00b2\u207a delivery (via syringe)',
                               AppLocale.de: 'Kontinuierliche Mg\u00b2\u207a-Zufuhr (über Perfusor)'},
    'cardio_mg_bolus_display': {AppLocale.en: 'End-of-dose Mg\u00b2\u207a bolus (separate push)',
                               AppLocale.de: 'Mg\u00b2\u207a-Bolus am Ende der Gabe (separater Push)'},
    'cardio_no_dose_needed':   {AppLocale.en: 'Patient\u2019s serum K\u207a already meets or exceeds the target \u2013 no supplementation needed at this flow.',
                               AppLocale.de: 'Der Serum-Kaliumwert des Patienten erreicht oder übersteigt bereits den Zielwert \u2013 keine Zufuhr bei diesem Fluss nötig.'},

    // ── Cardioplegia re-dose interval timer ──────────────────────────────────
    'cardio_timer_section':    {AppLocale.en: 'Time since last delivery',
                               AppLocale.de: 'Zeit seit letzter Gabe'},
    'cardio_timer_never':      {AppLocale.en: 'No delivery recorded yet',
                               AppLocale.de: 'Noch keine Gabe erfasst'},
    'cardio_timer_dose_now':   {AppLocale.en: 'Delivery now',
                               AppLocale.de: 'Gabe jetzt'},
    'cardio_timer_reset':      {AppLocale.en: 'Reset',
                               AppLocale.de: 'Zurücksetzen'},
    'cardio_timer_status_ok':  {AppLocale.en: 'Within the interval',
                               AppLocale.de: 'Innerhalb des Intervalls'},
    'cardio_timer_status_due': {AppLocale.en: 'Re-dose window open',
                               AppLocale.de: 'Nachgabe-Fenster offen'},
    'cardio_timer_status_overdue': {AppLocale.en: 'Interval exceeded',
                               AppLocale.de: 'Intervall überschritten'},
    'cardio_timer_window_calafiore': {AppLocale.en: 'Re-dose every 15\u201320 min',
                               AppLocale.de: 'Nachgabe alle 15\u201320 min'},
    'cardio_timer_window_bret': {AppLocale.en: 'Single-shot protection window ~180 min',
                               AppLocale.de: 'Schutzfenster der Einmalgabe ca. 180 min'},
    'cardio_timer_hint':       {AppLocale.en: 'Manual stopwatch only \u2013 it does not run in the background and is not a substitute for the perfusion record.',
                               AppLocale.de: 'Reine manuelle Stoppuhr \u2013 läuft nicht im Hintergrund und ersetzt nicht das Perfusionsprotokoll.'},


    // ── Timer alarm settings ─────────────────────────────────────────────────
    'cardio_alarm_section':    {AppLocale.en: 'Alert', AppLocale.de: 'Benachrichtigung'},
    'cardio_alarm_enabled':    {AppLocale.en: 'Alert when the interval is reached',
                               AppLocale.de: 'Benachrichtigen, wenn das Intervall erreicht ist'},
    'cardio_alarm_trigger':    {AppLocale.en: 'Alert after',
                               AppLocale.de: 'Benachrichtigen nach'},
    'cardio_alarm_sound':      {AppLocale.en: 'Sound', AppLocale.de: 'Ton'},
    'cardio_alarm_vibration':  {AppLocale.en: 'Vibration', AppLocale.de: 'Vibrationsalarm'},
    'cardio_alarm_repeat':     {AppLocale.en: 'Repeat every interval',
                               AppLocale.de: 'Bei jedem Intervall wiederholen'},
    'cardio_alarm_test':       {AppLocale.en: 'Test alert',
                               AppLocale.de: 'Benachrichtigung testen'},
    'cardio_alarm_scope_hint': {AppLocale.en: 'Fires only while PerfusionCalc is open in the foreground \u2013 it does not wake the device or alert from the background. Volume follows the device notification volume.',
                               AppLocale.de: 'Wird nur ausgelöst, während PerfusionCalc im Vordergrund geöffnet ist \u2013 weckt das Gerät nicht und meldet sich nicht aus dem Hintergrund. Die Lautstärke folgt der Benachrichtigungslautstärke des Geräts.'},
    'cardio_alarm_saved_hint': {AppLocale.en: 'These settings are saved and restored on the next app start.',
                               AppLocale.de: 'Diese Einstellungen werden gespeichert und beim nächsten App-Start wiederhergestellt.'},

    // ── del Nido ratio & dose per kg ─────────────────────────────────────────
    'cardio_dn_ratio_section': {AppLocale.en: 'Mixing ratio (saved)',
                               AppLocale.de: 'Mischungsverhältnis (gespeichert)'},
    'cardio_dn_cryst_percent': {AppLocale.en: 'Crystalloid share',
                               AppLocale.de: 'Kristalloidanteil'},
    'cardio_dn_blood_percent': {AppLocale.en: 'Blood share',
                               AppLocale.de: 'Blutanteil'},
    'cardio_dn_ratio_result':  {AppLocale.en: 'Resulting ratio (crystalloid : blood)',
                               AppLocale.de: 'Resultierendes Verhältnis (Kristalloid : Blut)'},
    'cardio_dn_follower_pct':  {AppLocale.en: 'Blood pump follower setting',
                               AppLocale.de: 'Follower-Einstellung Blutpumpe'},
    'cardio_dn_ratio_hint':    {AppLocale.en: 'Institutional setting \u2013 saved and restored on the next app start. 80 % corresponds to the del Nido standard of 4:1.',
                               AppLocale.de: 'Institutionelle Einstellung \u2013 wird gespeichert und beim nächsten App-Start wiederhergestellt. 80 % entspricht dem del-Nido-Standard 4:1.'},
    'cardio_dn_perkg_section': {AppLocale.en: 'Dose per body weight',
                               AppLocale.de: 'Dosis pro Körpergewicht'},
    'cardio_dn_per_kg':        {AppLocale.en: 'Total cardioplegia per kg',
                               AppLocale.de: 'Gesamtmenge Kardioplegie pro kg'},
    'cardio_dn_per_kg_hint':   {AppLocale.en: 'Cross-check against the protocol dose: del Nido is usually given at approx. 20 ml/kg, capped at 1000 ml single dose.',
                               AppLocale.de: 'Gegenprobe zur Protokolldosis: del Nido wird üblicherweise mit ca. 20 ml/kg gegeben, gedeckelt auf 1000 ml Einzeldosis.'},

    // ── del Nido mixing / delivery time ──────────────────────────────────────
    'cardio_dn_mix_section':   {AppLocale.en: 'Mixture & delivery time',
                               AppLocale.de: 'Mischung & Gabezeit'},
    'cardio_dn_crystalloid':   {AppLocale.en: 'Crystalloid volume',
                               AppLocale.de: 'Kristalloidmenge'},
    'cardio_dn_pump_flow':     {AppLocale.en: 'Crystalloid pump flow (100 %)',
                               AppLocale.de: 'Fluss Kristalloidpumpe (100 %)'},
    'cardio_dn_blood_label':   {AppLocale.en: 'Blood component',
                               AppLocale.de: 'Blutanteil'},
    'cardio_dn_total':         {AppLocale.en: 'Total cardioplegia volume',
                               AppLocale.de: 'Gesamtes Kardioplegievolumen'},
    'cardio_dn_blood_flow':    {AppLocale.en: 'Blood pump flow',
                               AppLocale.de: 'Fluss Blutpumpe'},
    'cardio_dn_follower_word': {AppLocale.en: 'follower', AppLocale.de: 'Follower'},
    'cardio_dn_ideal_total':   {AppLocale.en: 'Ideal total volume (20 ml/kg)',
                               AppLocale.de: 'Ideale Gesamtmenge (20 ml/kg)'},
    'cardio_dn_ideal_capped':  {AppLocale.en: 'Hypothetical value \u2013 the del Nido protocol provides for a maximum single dose of 1000 ml.',
                               AppLocale.de: 'Hypothetischer Wert \u2013 laut del-Nido-Protokoll sind maximal 1000 ml als Einzeldosis vorgesehen.'},
    'cardio_dn_total_flow':    {AppLocale.en: 'Combined flow',
                               AppLocale.de: 'Gesamtfluss'},
    'cardio_dn_time':          {AppLocale.en: 'Delivery time',
                               AppLocale.de: 'Benötigte Gabezeit'},
    'cardio_dn_follower_hint': {AppLocale.en: 'Follower principle: the crystalloid pump runs at 100 % of the set flow and the blood pump at the follower fraction below \u2013 mechanically producing the configured ratio. The delivery time is unaffected by the ratio.',
                               AppLocale.de: 'Followerprinzip: Die Kristalloidpumpe läuft mit 100 % des eingestellten Flusses, die Blutpumpe mit dem unten angegebenen Follower-Anteil \u2013 damit ergibt sich mechanisch das eingestellte Verhältnis. Die Gabezeit ist vom Verhältnis unabhängig.'},

    // ── Cardioplegia delivery pressure limits (all protocols) ────────────────
    'cardio_pressure_limits':  {AppLocale.en: 'Delivery pressure: antegrade max. 70\u2013100 mmHg, retrograde max. 50\u201370 mmHg.',
                               AppLocale.de: 'Applikationsdruck: antegrad max. 70\u2013100 mmHg, retrograd max. 50\u201370 mmHg.'},

    // ── Bretschneider (HTK/Custodiol) ────────────────────────────────────────
    'cardio_bret_principle':   {AppLocale.en: 'Intracellular crystalloid single-shot solution (HTK/Custodiol): extracellular sodium is lowered to intracellular levels, abolishing the electrochemical gradient. Solution temperature 5\u20138 \u00b0C.',
                               AppLocale.de: 'Intrazelluläre kristalloide Einmal-Lösung (HTK/Custodiol): Der extrazelluläre Natriumgehalt wird auf intrazelluläres Niveau gesenkt, wodurch das elektrochemische Potential aufgehoben wird. Lösungstemperatur 5\u20138 \u00b0C.'},
    'cardio_bret_ischemia':    {AppLocale.en: 'Organ protection up to 180 min from a single administration.',
                               AppLocale.de: 'Organprotektion bis zu 180 min bei einmaliger Gabe.'},
    'cardio_bret_duration':    {AppLocale.en: 'Perfusion time 6\u20138 min, re-perfusion approx. 2\u20133 min.',
                               AppLocale.de: 'Perfusionsdauer 6\u20138 min, bei Nachperfusion ca. 2\u20133 min.'},
    'cardio_bret_pressure':    {AppLocale.en: 'Perfusion pressure: initially 100\u2013110 mmHg, after cardiac arrest 40\u201350 mmHg.',
                               AppLocale.de: 'Perfusionsdruck: Initial 100\u2013110 mmHg, nach Herzstillstand 40\u201350 mmHg.'},
    'cardio_bret_pump_section': {AppLocale.en: 'Delivered volume (from pump settings)',
                               AppLocale.de: 'Verabreichtes Volumen (aus Pumpeneinstellung)'},
    'cardio_bret_flow':        {AppLocale.en: 'CPL pump flow',
                               AppLocale.de: 'Fluss Kardioplegiepumpe'},
    'cardio_bret_time':        {AppLocale.en: 'Perfusion time',
                               AppLocale.de: 'Perfusionszeit'},
    'cardio_bret_volume':      {AppLocale.en: 'Delivered cardioplegia volume',
                               AppLocale.de: 'Verabreichtes Kardioplegievolumen'},

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
    'ped_title_tube':         {AppLocale.en: 'Tube diameter (Oldeen et al. 2020)',
                               AppLocale.de: 'Schlauchdurchmesser (Oldeen et al. 2020)'},
    'ped_title_perfusion':    {AppLocale.en: 'Perfusion rate (Ramakrishnan et al. 2023)',
                               AppLocale.de: 'Perfusionsrate (Ramakrishnan et al. 2023)'},
    'ped_title_va':           {AppLocale.en: 'V-A cannula size (Finck 2025)',
                               AppLocale.de: 'V-A Kanülengröße (Finck 2025)'},
    'ped_title_vv':           {AppLocale.en: 'V-V cannula size (Finck 2025)',
                               AppLocale.de: 'V-V Kanülengröße (Finck 2025)'},
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
    'anat_tap_zoom':          {AppLocale.en: 'Tap to zoom',
                               AppLocale.de: 'Zum Vergrößern tippen'},
  };

  /// Translate a key. Falls back to EN if the DE translation is missing;
  /// returns the key itself if not defined at all (visible as a
  /// "bug marker").
  static String of(String key, AppLocale locale) {
    final entry = _all[key];
    if (entry == null) return '⟨$key⟩'; // make it visible if forgotten
    return entry[locale] ?? entry[AppLocale.en] ?? '⟨$key⟩';
  }
}

/// Global shorthand helper. Usage: `t('bsa_body_height')`.
/// Reads the currently active language from the LocaleNotifier singleton.
String t(String key) => Strings.of(key, LocaleNotifier.instance.current);
