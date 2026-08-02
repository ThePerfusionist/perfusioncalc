// PerfusionCalc PDF Export
// =========================
//
// Produces a professional PDF with:
//   - Header: app logo (gold accent), tab title, date/time
//   - Input section: all patient data/parameters
//   - Results section: calculated values
//   - Footer: app version, disclaimer (compact), page number
//
// IMPORTANT: This app uses special characters like m², °C, ·, —, subscripts
// etc. The standard PDF fonts (Helvetica) only support a fraction of these.
// We therefore load Roboto TTF fonts from assets/fonts/ and set them as the
// default theme. Roboto covers the full Latin Extended and mathematical
// character set.
//
// Usage per tab:
//   await exportTabAsPdf(
//     tabTitle: t('tab_bsa'),
//     filename: 'bsa',
//     sections: [
//       PdfSection(title: 'Inputs', rows: [...]),
//       PdfSection(title: 'Results', rows: [...]),
//     ],
//   );

import 'dart:typed_data' show Uint8List;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../i18n/app_strings.dart';
import '../main.dart' show kAppVersion;
import 'pdf_download_stub.dart'
    if (dart.library.js_interop) 'pdf_download_web.dart';

// ════════════════════════════════════════════════════════════════════════════
// Public data models
// ════════════════════════════════════════════════════════════════════════════

/// A table section in the PDF. Each row consists of label/value/unit.
/// Result sections can carry hints about normal ranges.
class PdfSection {
  final String title;
  final List<PdfRow> rows;
  PdfSection({required this.title, required this.rows});
}

class PdfRow {
  final String label;
  final String value; // already formatted, e.g. "1.85" or "—"
  final String unit;
  final String? note; // e.g. range hint or source

  PdfRow({
    required this.label,
    required this.value,
    this.unit = '',
    this.note,
  });

  /// Convenience: directly from a numeric calculation.
  ///
  /// null and NaN always print "—". A value of exactly 0 does too, because
  /// every result getter in PatientData returns 0 to mean "inputs
  /// incomplete" - that is what makes the combined report's "only filled
  /// tabs" filter work.
  ///
  /// [zeroIsValid] switches that off for the handful of fields where 0 is a
  /// real, entered measurement rather than a missing one: base excess, CVP,
  /// LAP. Printing "—" for a CVP of 0 mmHg claims the value was never
  /// entered, which is a different statement from "it was 0".
  factory PdfRow.numeric({
    required String label,
    required double? value,
    String unit = '',
    int decimals = 2,
    String? note,
    bool zeroIsValid = false,
  }) {
    final missing = value == null ||
        value.isNaN ||
        value.isInfinite ||
        (value == 0 && !zeroIsValid);
    final str = missing ? '—' : value.toStringAsFixed(decimals);
    return PdfRow(label: label, value: str, unit: unit, note: note);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Font loading (Roboto supports Unicode)
// ════════════════════════════════════════════════════════════════════════════

// Lazy-loaded and cached - loaded only once, then reused on every export.
// Saves performance on repeated exports.
pw.Font? _cachedRegular;
pw.Font? _cachedBold;
pw.Font? _cachedItalic;

Future<pw.ThemeData> _loadTheme() async {
  _cachedRegular ??= pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
  _cachedBold    ??= pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
  _cachedItalic  ??= pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Italic.ttf'));
  return pw.ThemeData.withFont(
    base: _cachedRegular!,
    bold: _cachedBold!,
    italic: _cachedItalic!,
  );
}

// ════════════════════════════════════════════════════════════════════════════
// Main function
// ════════════════════════════════════════════════════════════════════════════

/// Exports the given sections as a PDF and triggers the download (on web),
/// shows the share sheet (on Android/iOS), or is a no-op (on desktop
/// without printing support).
/// Rendert das PDF und gibt die Bytes zurueck - ohne Download.
///
/// Getrennt vom Export, damit das Rendern testbar ist: Die Erzeugung war
/// bis v0.4.15 mit dem Speichern-Dialog verwoben und damit in einem Unit-
/// Test nicht erreichbar (Abdeckung 10 %). Das PDF ist aber das einzige
/// Artefakt, das die App verlaesst - eine Ausnahme beim Aufbau, etwa durch
/// eine Layout-Ueberschreitung oder eine fehlende Schrift, bedeutet
/// vollstaendigen Ausfall des Exports und wurde von nichts abgesichert.
@visibleForTesting
Future<Uint8List> renderTabPdf({
  required String tabTitle,
  required List<PdfSection> sections,
  DateTime? now,
}) async {
  final theme = await _loadTheme();
  final pdf = pw.Document(theme: theme);
  final labels = _PdfLabels.forCurrentLocale(now ?? DateTime.now());

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 60),

      // ── Header/Footer (on every page), shared with the combined report ──
      header: (ctx) => _buildHeader(subtitle: tabTitle, labels: labels),
      footer: (ctx) => _buildFooter(ctx, labels),

      // ── Body: sections ───────────────────────────────────────────────────
      build: (ctx) => [
        for (final section in sections) _buildSection(section),
      ],
    ),
  );
  return pdf.save();
}

Future<void> exportTabAsPdf({
  required String tabTitle,
  required String filename,
  required List<PdfSection> sections,
}) async {
  final now = DateTime.now();
  final bytes = await renderTabPdf(tabTitle: tabTitle, sections: sections, now: now);
  final ts = '${now.year}${_pad(now.month)}${_pad(now.day)}_'
             '${_pad(now.hour)}${_pad(now.minute)}';
  final fullFilename = 'perfusioncalc_${filename}_$ts.pdf';
  await downloadPdf(bytes, fullFilename);
}

// ════════════════════════════════════════════════════════════════════════════
// Combined report (multiple tabs in one PDF)
// ════════════════════════════════════════════════════════════════════════════
//
// Combines several already-filled-in tabs (BSA, O2 delivery, electrolytes,
// ...) into a single PDF - handy for OR documentation when several
// parameter categories were captured for the same patient, instead of
// exporting each category separately.
//
// Usage:
//   await exportCombinedReportAsPdf(tabs: [
//     PdfTabReport(tabTitle: t('tab_bsa'), sections: buildBsaPdfSections(pd)),
//     PdfTabReport(tabTitle: t('tab_o2'),  sections: buildO2PdfSections(pd)),
//     ...
//   ]);
//
// Filtering "only filled-in tabs" happens at the call site (MainScreen),
// not here - this function simply renders whatever it is given.

/// A tab report for the combined export: tab title + its sections
/// (inputs/results), in the same format as the single-tab exports.
class PdfTabReport {
  final String tabTitle;
  final List<PdfSection> sections;
  PdfTabReport({required this.tabTitle, required this.sections});
}

/// Exports a combined report across multiple tabs as a single PDF.
/// Gegenstueck zu [renderTabPdf] fuer den Gesamtbericht.
@visibleForTesting
Future<Uint8List> renderCombinedPdf({
  required List<PdfTabReport> tabs,
  DateTime? now,
}) async {
  final theme = await _loadTheme();
  final pdf = pw.Document(theme: theme);
  final labels = _PdfLabels.forCurrentLocale(now ?? DateTime.now());

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 60),

      // ── Header/Footer (on every page), shared with the single-tab export ─
      header: (ctx) => _buildHeader(subtitle: labels.reportTitle, labels: labels),
      footer: (ctx) => _buildFooter(ctx, labels),

      // ── Body: one "chapter" per tab, each with its own sections ─────────
      build: (ctx) => [
        for (final tab in tabs) _buildTabChapter(tab),
      ],
    ),
  );

  return pdf.save();
}

Future<void> exportCombinedReportAsPdf({
  required List<PdfTabReport> tabs,
}) async {
  final now = DateTime.now();
  final bytes = await renderCombinedPdf(tabs: tabs, now: now);
  final ts = '${now.year}${_pad(now.month)}${_pad(now.day)}_'
             '${_pad(now.hour)}${_pad(now.minute)}';
  final fullFilename = 'perfusioncalc_combined_report_$ts.pdf';
  await downloadPdf(bytes, fullFilename);
}

/// A tab as a "chapter" in the combined report: a noticeably more
/// prominent, color-filled title (instead of the plain gold underline used
/// for individual sections), so the tabs are clearly distinguishable within
/// the continuous document.
pw.Widget _buildTabChapter(PdfTabReport tab) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 20),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: const pw.BoxDecoration(
          color: PdfColors.amber800,
          borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
        ),
        child: pw.Text(tab.tabTitle, style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
        )),
      ),
      for (final section in tab.sections) _buildSection(section),
    ]),
  );
}

// ════════════════════════════════════════════════════════════════════════════
// Helpers
// ════════════════════════════════════════════════════════════════════════════

/// Gibt [value] nur zurueck, wenn ALLE benoetigten Eingaben vorliegen -
/// sonst null.
///
/// Loest die Spiegelung von Auditbefund 1.1: Dort druckte das PDF eine Zahl,
/// wo der Bildschirm "—" zeigte. Hier war es umgekehrt.
///
/// Ergebnis-Getter in PatientData geben 0 zurueck, wenn Eingaben fehlen -
/// PdfRow.numeric zeigt dafuer "—". Bei manchen Rechnungen ist 0 aber ein
/// gueltiges, klinisch bedeutsames Ergebnis: ein Base Excess von 0 heisst
/// "0 ml NaBic, keine Korrektur noetig", nicht "nicht berechenbar". Die
/// ResultCard auf dem Bildschirm zeigt dort korrekt 0.0, weil sie sich nach
/// missingInputs richtet und nicht nach dem Wert - das PDF zeigte "—".
///
/// Mit resultIf(...) plus `zeroIsValid: true` bilden beide dieselbe
/// Unterscheidung ab: fehlende Eingabe -> "—", errechnete Null -> "0.0".
double? resultIf(List<Object?> requiredInputs, double value) =>
    requiredInputs.any((i) => i == null) ? null : value;

/// The handful of chrome strings both exports need, resolved once per
/// document. These are not in app_strings.dart because they only ever
/// appear inside a generated PDF, never in the UI.
class _PdfLabels {
  final String dateStr;
  final String disclaimer;
  final String page;
  final String exported;
  final String version;
  final String reportTitle;

  const _PdfLabels({
    required this.dateStr,
    required this.disclaimer,
    required this.page,
    required this.exported,
    required this.version,
    required this.reportTitle,
  });

  factory _PdfLabels.forCurrentLocale(DateTime now) {
    final locale = LocaleNotifier.instance.current;
    final de = locale == AppLocale.de;
    return _PdfLabels(
      dateStr: _formatDateTime(now, locale),
      disclaimer: de
          ? 'Nur zu Ausbildungszwecken. Keine klinische Verwendung. Keine Garantie auf Richtigkeit der Ergebnisse.'
          : 'For educational use only. Not for clinical use. No guarantee of result accuracy.',
      page: de ? 'Seite' : 'Page',
      exported: de ? 'Exportiert am' : 'Exported on',
      version: 'Version',
      reportTitle: de ? 'Perfusionsbericht' : 'Perfusion report',
    );
  }
}

/// Header band: app name, a subtitle (tab title or report title) and the
/// export timestamp. Used identically by both export types - this block and
/// the label construction above it were ~60 duplicated lines.
pw.Widget _buildHeader({required String subtitle, required _PdfLabels labels}) {
  return pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 8),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(color: PdfColors.amber700, width: 1.5),
      ),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('PerfusionCalc', style: pw.TextStyle(
            color: PdfColors.amber800,
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          )),
          pw.SizedBox(height: 2),
          pw.Text(subtitle, style: const pw.TextStyle(
            color: PdfColors.grey800,
            fontSize: 13,
          )),
        ]),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('${labels.exported} ${labels.dateStr}',
              style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 9)),
        ]),
      ],
    ),
  );
}

/// Footer line: disclaimer + version/page number. Used identically by both
/// export types (single-tab and combined report).
pw.Widget _buildFooter(pw.Context ctx, _PdfLabels labels) {
  return pw.Container(
    padding: const pw.EdgeInsets.only(top: 8),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        top: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
      ),
    ),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(labels.disclaimer, style: pw.TextStyle(
        color: PdfColors.grey600,
        fontSize: 7.5,
        fontStyle: pw.FontStyle.italic,
      )),
      pw.SizedBox(height: 2),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('PerfusionCalc · ${labels.version} $kAppVersion',
            style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8)),
        pw.Text('${labels.page} ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8)),
      ]),
    ]),
  );
}

pw.Widget _buildSection(PdfSection section) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 16),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      // Section title (gold underline)
      pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 4),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.amber700, width: 1),
          ),
        ),
        child: pw.Text(section.title, style: pw.TextStyle(
          color: PdfColors.amber800,
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
        )),
      ),
      pw.SizedBox(height: 6),
      // Rows table
      ...section.rows.map((row) => _buildRow(row)),
    ]),
  );
}

pw.Widget _buildRow(PdfRow row) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        // Label - 50% width
        pw.Expanded(flex: 5, child: pw.Text(row.label,
            style: const pw.TextStyle(color: PdfColors.grey800, fontSize: 10))),
        // Value - 25% width, bold
        pw.Expanded(flex: 3, child: pw.Text(row.value,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              color: PdfColors.black,
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ))),
        // Unit - 15% width
        pw.SizedBox(width: 6),
        pw.Expanded(flex: 2, child: pw.Text(row.unit,
            style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 10))),
      ]),
      // Note on a second line. PdfRow.note was filled in several places and
      // then silently dropped - the comment here described code that did
      // not exist.
      if (row.note != null && row.note!.isNotEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 1),
          child: pw.Text(row.note!, style: pw.TextStyle(
            color: PdfColors.grey600,
            fontSize: 8,
            fontStyle: pw.FontStyle.italic,
          )),
        ),
    ]),
  );
}

/// Localized date/time format.
/// DE: "25.04.2026, 16:30"
/// EN: "Apr 25, 2026, 4:30 PM"
String _formatDateTime(DateTime dt, AppLocale locale) {
  if (locale == AppLocale.de) {
    return '${_pad(dt.day)}.${_pad(dt.month)}.${dt.year}, '
           '${_pad(dt.hour)}:${_pad(dt.minute)}';
  } else {
    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final m = monthNames[dt.month - 1];
    final hour12 = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$m ${dt.day}, ${dt.year}, $hour12:${_pad(dt.minute)} $ampm';
  }
}

String _pad(int n) => n.toString().padLeft(2, '0');
