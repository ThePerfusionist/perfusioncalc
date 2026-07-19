// PerfusionCalc PDF Export
// =========================
//
// Erzeugt ein professionelles PDF mit:
//   - Header: App-Logo (Gold-Akzent), Tab-Titel, Datum/Uhrzeit
//   - Eingabe-Sektion: alle Patientendaten/Parameter
//   - Ergebnis-Sektion: berechnete Werte
//   - Footer: App-Version, Disclaimer (kompakt), Seitenzahl
//
// WICHTIG: Diese App nutzt Sonderzeichen wie m², °C, ·, —, Subskripte usw.
// Die Standard-PDF-Schriften (Helvetica) unterstuetzen davon nur einen
// Bruchteil. Daher laden wir Roboto-TTF-Schriften aus assets/fonts/ und
// setzen sie als Default-Theme. Roboto deckt das gesamte Latin-Extended-
// und Mathematische-Zeichensatz ab.
//
// Nutzung pro Tab:
//   await exportTabAsPdf(
//     tabTitle: t('tab_bsa'),
//     filename: 'bsa',
//     sections: [
//       PdfSection(title: 'Eingaben', rows: [...]),
//       PdfSection(title: 'Ergebnisse', rows: [...]),
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
// Public Datenmodelle
// ════════════════════════════════════════════════════════════════════════════

/// Eine Tabellen-Sektion im PDF. Jede Zeile besteht aus Label/Wert/Einheit.
/// Ergebnis-Sektionen koennen Hinweise auf Normalbereiche haben.
class PdfSection {
  final String title;
  final List<PdfRow> rows;
  PdfSection({required this.title, required this.rows});
}

class PdfRow {
  final String label;
  final String value; // bereits formatiert, z.B. "1.85" oder "—"
  final String unit;
  final String? note; // z.B. Range-Hinweis oder Quelle

  PdfRow({
    required this.label,
    required this.value,
    this.unit = '',
    this.note,
  });

  /// Convenience: direkt aus einer numerischen Berechnung.
  /// Wenn value 0 oder NaN ist, wird "—" angezeigt (= "noch nicht berechnet").
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
// Font-Loading (Roboto unterstützt Unicode)
// ════════════════════════════════════════════════════════════════════════════

// Lazy-loaded und gecached - werden nur einmal geladen, dann in jedem Export
// wiederverwendet. Spart Performance bei wiederholten Exports.
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
// Hauptfunktion
// ════════════════════════════════════════════════════════════════════════════

/// Exportiert die uebergebenen Sections als PDF und triggert den Download
/// (im Web) bzw. zeigt das Share-Sheet (auf Android/iOS) bzw. ist no-op
/// (auf Desktop ohne Printing-Support).
Future<void> exportTabAsPdf({
  required String tabTitle,
  required String filename,
  required List<PdfSection> sections,
}) async {
  final locale = LocaleNotifier.instance.current;
  final theme = await _loadTheme();
  final pdf = pw.Document(theme: theme);

  // Aktuelles Datum/Zeit fuer den Header
  final now = DateTime.now();
  final dateStr = _formatDateTime(now, locale);

  // Statische Texte (lokalisiert)
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

      // ── Header (auf jeder Seite) ────────────────────────────────────────
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

      // ── Footer (auf jeder Seite) ────────────────────────────────────────
      footer: (ctx) => _buildFooter(ctx, disclaimerText, pageLabel, versionLabel),

      // ── Body: Sections ──────────────────────────────────────────────────
      build: (ctx) => [
        for (final section in sections) _buildSection(section),
      ],
    ),
  );

  // PDF-Bytes erzeugen, dann Download im Browser triggern
  final bytes = await pdf.save();
  final ts = '${now.year}${_pad(now.month)}${_pad(now.day)}_'
             '${_pad(now.hour)}${_pad(now.minute)}';
  final fullFilename = 'perfusioncalc_${filename}_$ts.pdf';
  await downloadPdf(bytes, fullFilename);
}

// ════════════════════════════════════════════════════════════════════════════
// Kombinierter Bericht (mehrere Tabs in einem PDF)
// ════════════════════════════════════════════════════════════════════════════
//
// Fasst mehrere bereits ausgefüllte Tabs (BSA, O2-Delivery, Elektrolyte, ...)
// in einem einzigen PDF zusammen - praktisch für die OP-Dokumentation, wenn
// mehrere Parameter-Kategorien für denselben Patienten erfasst wurden, statt
// pro Kategorie einzeln zu exportieren.
//
// Nutzung:
//   await exportCombinedReportAsPdf(tabs: [
//     PdfTabReport(tabTitle: t('tab_bsa'), sections: buildBsaPdfSections(pd)),
//     PdfTabReport(tabTitle: t('tab_o2'),  sections: buildO2PdfSections(pd)),
//     ...
//   ]);
//
// Die Filterung "nur ausgefüllte Tabs" erfolgt beim Aufrufer (MainScreen),
// nicht hier - diese Funktion rendert einfach, was ihr übergeben wird.

/// Ein Tab-Bericht für den kombinierten Export: Tab-Titel + seine Sections
/// (Eingaben/Ergebnisse), im selben Format wie bei den Einzel-Tab-Exports.
class PdfTabReport {
  final String tabTitle;
  final List<PdfSection> sections;
  PdfTabReport({required this.tabTitle, required this.sections});
}

/// Exportiert einen kombinierten Bericht über mehrere Tabs als ein PDF.
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

      // ── Header (auf jeder Seite) ────────────────────────────────────────
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

      // ── Footer (auf jeder Seite) - identisch zum Einzel-Tab-Export ──────
      footer: (ctx) => _buildFooter(ctx, disclaimerText, pageLabel, versionLabel),

      // ── Body: ein "Kapitel" pro Tab, jeweils mit eigenen Sections ───────
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

/// Ein Tab als "Kapitel" im kombinierten Bericht: deutlich prominenterer,
/// farbig hinterlegter Titel (statt des einfachen goldenen Unterstrichs bei
/// einzelnen Sections), damit die Tabs im durchlaufenden Dokument klar
/// auseinanderzuhalten sind.
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

/// Footer-Zeile: Disclaimer + Version/Seitenzahl. Von beiden Export-Arten
/// (Einzel-Tab und kombinierter Bericht) identisch genutzt.
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

/// Lokalisiertes Datum/Zeit-Format.
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
