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
  /// If value is 0 or NaN, "—" is shown (= "not yet calculated").
  factory PdfRow.numeric({
    required String label,
    required double? value,
    String unit = '',
    int decimals = 2,
    String? note,
  }) {
    final str = (value == null || value.isNaN || value == 0)
        ? '—'
        : value.toStringAsFixed(decimals);
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
Future<void> exportTabAsPdf({
  required String tabTitle,
  required String filename,
  required List<PdfSection> sections,
}) async {
  final locale = LocaleNotifier.instance.current;
  final theme = await _loadTheme();
  final pdf = pw.Document(theme: theme);

  // Current date/time for the header
  final now = DateTime.now();
  final dateStr = _formatDateTime(now, locale);

  // Static texts (localized)
  final headerTitle = 'PerfusionCalc';
  final disclaimerText = locale == AppLocale.de
      ? 'Nur zu Ausbildungszwecken. Keine klinische Verwendung. Keine Garantie auf Richtigkeit der Ergebnisse.'
      : 'For educational use only. Not for clinical use. No guarantee of result accuracy.';
  final pageLabel = locale == AppLocale.de ? 'Seite' : 'Page';
  final exportedLabel = locale == AppLocale.de ? 'Exportiert am' : 'Exported on';
  final versionLabel = locale == AppLocale.de ? 'Version' : 'Version';

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 60),

      // ── Header (on every page) ──────────────────────────────────────────
      header: (ctx) => pw.Container(
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
              pw.Text(headerTitle, style: pw.TextStyle(
                color: PdfColors.amber800,
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              )),
              pw.SizedBox(height: 2),
              pw.Text(tabTitle, style: const pw.TextStyle(
                color: PdfColors.grey800,
                fontSize: 13,
              )),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('$exportedLabel $dateStr',
                  style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 9)),
            ]),
          ],
        ),
      ),

      // ── Footer (on every page) ──────────────────────────────────────────
      footer: (ctx) => _buildFooter(ctx, disclaimerText, pageLabel, versionLabel),

      // ── Body: sections ───────────────────────────────────────────────────
      build: (ctx) => [
        for (final section in sections) _buildSection(section),
      ],
    ),
  );

  // Generate PDF bytes, then trigger the download in the browser
  final bytes = await pdf.save();
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
Future<void> exportCombinedReportAsPdf({
  required List<PdfTabReport> tabs,
}) async {
  final locale = LocaleNotifier.instance.current;
  final theme = await _loadTheme();
  final pdf = pw.Document(theme: theme);

  final now = DateTime.now();
  final dateStr = _formatDateTime(now, locale);

  final headerTitle = 'PerfusionCalc';
  final reportTitle = locale == AppLocale.de ? 'Perfusionsbericht' : 'Perfusion report';
  final disclaimerText = locale == AppLocale.de
      ? 'Nur zu Ausbildungszwecken. Keine klinische Verwendung. Keine Garantie auf Richtigkeit der Ergebnisse.'
      : 'For educational use only. Not for clinical use. No guarantee of result accuracy.';
  final pageLabel = locale == AppLocale.de ? 'Seite' : 'Page';
  final exportedLabel = locale == AppLocale.de ? 'Exportiert am' : 'Exported on';
  final versionLabel = locale == AppLocale.de ? 'Version' : 'Version';

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 60),

      // ── Header (on every page) ──────────────────────────────────────────
      header: (ctx) => pw.Container(
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
              pw.Text(headerTitle, style: pw.TextStyle(
                color: PdfColors.amber800,
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              )),
              pw.SizedBox(height: 2),
              pw.Text(reportTitle, style: const pw.TextStyle(
                color: PdfColors.grey800,
                fontSize: 13,
              )),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('$exportedLabel $dateStr',
                  style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 9)),
            ]),
          ],
        ),
      ),

      // ── Footer (on every page) - identical to the single-tab export ─────
      footer: (ctx) => _buildFooter(ctx, disclaimerText, pageLabel, versionLabel),

      // ── Body: one "chapter" per tab, each with its own sections ─────────
      build: (ctx) => [
        for (final tab in tabs) _buildTabChapter(tab),
      ],
    ),
  );

  final bytes = await pdf.save();
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

/// Footer line: disclaimer + version/page number. Used identically by both
/// export types (single-tab and combined report).
pw.Widget _buildFooter(pw.Context ctx, String disclaimerText, String pageLabel, String versionLabel) {
  return pw.Container(
    padding: const pw.EdgeInsets.only(top: 8),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        top: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
      ),
    ),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(disclaimerText, style: pw.TextStyle(
        color: PdfColors.grey600,
        fontSize: 7.5,
        fontStyle: pw.FontStyle.italic,
      )),
      pw.SizedBox(height: 2),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('PerfusionCalc · $versionLabel $kAppVersion',
            style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8)),
        pw.Text('$pageLabel ${ctx.pageNumber} / ${ctx.pagesCount}',
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
    child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
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
      // Note - if any, on a second line below the row (wider context)
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
