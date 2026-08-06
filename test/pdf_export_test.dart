// Tests for the PDF row/section builders
// =======================================
// The PDF is the one artefact that leaves the app. Audit findings 1.1 and
// 1.2 both lived here and neither was covered by a test: the on-screen
// guards (ResultCard.missingInputs) had no counterpart in the export, so a
// half-filled oxygen tab printed a plausible-looking but wrong report.
//
// These tests build the section lists directly - no widget pumping needed,
// PdfRow is plain data.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:perfusion_calc/models/patient_data.dart';
import 'package:perfusion_calc/screens/o2_delivery_screen.dart';
import 'package:perfusion_calc/screens/bsa_screen.dart';
import 'package:perfusion_calc/screens/electrolytes_screen.dart';
import 'package:perfusion_calc/screens/ultrafiltration_screen.dart';
import 'package:perfusion_calc/utils/pdf_export.dart';

/// Value of the row with exactly this label.
///
/// Exact, not `contains`: "Ca-vDO2" contains "DO2" and sits earlier in the
/// list, so a substring match would silently return the wrong row.
String? valueOf(List<PdfSection> sections, String label) {
  for (final section in sections) {
    for (final row in section.rows) {
      if (row.label == label) return row.value;
    }
  }
  return null;
}

/// Value of the first row whose label contains [needle] - for labels that
/// come from t() and therefore depend on the active locale.
String? valueContaining(List<PdfSection> sections, String needle) {
  for (final section in sections) {
    for (final row in section.rows) {
      if (row.label.contains(needle)) return row.value;
    }
  }
  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PdfRow.numeric', () {
    test('null and NaN print an em dash', () {
      expect(PdfRow.numeric(label: 'x', value: null).value, '—');
      expect(PdfRow.numeric(label: 'x', value: double.nan).value, '—');
    });

    test('Infinity prints an em dash rather than "Infinity"', () {
      expect(PdfRow.numeric(label: 'x', value: double.infinity).value, '—');
    });

    test('Zero means "not calculated" by default', () {
      expect(PdfRow.numeric(label: 'x', value: 0).value, '—');
    });

    test('zeroIsValid prints a real, entered zero', () {
      // Base excess 0, CVP 0 and LAP 0 are findings, not empty fields.
      // Printing "—" for them claims the value was never entered.
      expect(PdfRow.numeric(label: 'x', value: 0, zeroIsValid: true).value,
          '0.00');
    });

    test('Decimals are honoured', () {
      expect(PdfRow.numeric(label: 'x', value: 1.23456, decimals: 1).value,
          '1.2');
      expect(PdfRow.numeric(label: 'x', value: 826.9, decimals: 0).value, '827');
    });
  });

  group('O2 delivery export with arterial values only (audit 1.1)', () {
    late List<PdfSection> sections;

    setUp(() {
      final pd = PatientData()
        ..artHb = 12
        ..saO2 = 99
        ..paO2 = 200
        ..hzv = 5
        ..kof = 1.9;
      sections = buildO2PdfSections(pd);
    });

    test('O2-ER is not printed as 100 %', () {
      // The exact regression: cvO2 == 0 made cavDO2 == caO2, so the export
      // printed "100.00" - wrong, and plausible enough not to be noticed.
      final o2er = valueOf(sections, 'O\u2082-ER');
      expect(o2er, isNotNull);
      expect(o2er, '—');
    });

    test('VO2 and VO2i are blank, not a copy of DO2', () {
      expect(valueOf(sections, 'VO\u2082'), '—');
      expect(valueOf(sections, 'VO\u2082i'), '—');
    });

    test('DO2 is still exported - the arterial side IS complete', () {
      final do2 = valueOf(sections, 'DO\u2082');
      expect(do2, isNotNull);
      expect(do2, isNot('—'));
    });
  });

  group('O2 delivery export with a complete data set', () {
    test('Every oxygen result carries a number', () {
      final pd = PatientData()
        ..artHb = 12
        ..saO2 = 99
        ..paO2 = 200
        ..venHb = 12
        ..svO2 = 75
        ..pvO2 = 40
        ..hzv = 5
        ..kof = 1.9;
      final sections = buildO2PdfSections(pd);
      for (final label in ['CaO\u2082', 'CvO\u2082', 'DO\u2082', 'VO\u2082']) {
        expect(valueOf(sections, label), isNot('—'), reason: label);
      }
      final o2er = double.parse(valueOf(sections, 'O\u2082-ER')!);
      expect(o2er, greaterThan(0));
      expect(o2er, lessThan(100));
    });
  });

  group('BSA export', () {
    test('Empty patient data produces only em dashes', () {
      final sections = buildBsaPdfSections(PatientData());
      for (final section in sections) {
        for (final row in section.rows) {
          expect(row.value, '—', reason: row.label);
        }
      }
    });

    test('Expected Hb is exported per sex, like Hct', () {
      final pd = PatientData()
        ..weight = 80
        ..currentHb = 14
        ..primingVolume = 1500;
      final sections = buildBsaPdfSections(pd);
      final male = valueContaining(sections, '(male)');
      expect(male, isNotNull);
      expect(double.parse(male!), closeTo(10.67, 0.01));
    });
  });

  group('Calculated zero versus missing input (mirror of 1.1)', () {
    // The ResultCard on screen follows missingInputs, not the value: with
    // complete inputs it shows 0.0. The PDF showed "—" for that. Exactly the
    // reverse of finding 1.1, and wrong in the same sense: the two outputs
    // contradicted each other.

    test('Base excess 0 → NaBic and TRIS print 0.0, not "—"', () {
      // A BE of 0 is a normal finding. The correct answer is "0 ml, no
      // correction needed".
      final pd = PatientData()
        ..bodyWeightElec = 80
        ..baseExcess = 0;
      final sections = buildElectrolytesPdfSections(pd);
      expect(valueContaining(sections, 'NaBic'), '0.0');
      expect(valueContaining(sections, 'TRIS'), '0.0');
    });

    test('Without a weight it stays "—"', () {
      // The distinction is only worth anything if the "not calculable" case
      // survives.
      final pd = PatientData()..baseExcess = 0;
      final sections = buildElectrolytesPdfSections(pd);
      expect(valueContaining(sections, 'NaBic'), '—');
      expect(valueContaining(sections, 'TRIS'), '—');
    });

    test('Current equals target → requirement is 0, not "—"', () {
      final pd = PatientData()
        ..bodyWeightElec = 80
        ..kaliumIst = 4.0
        ..kaliumSoll = 4.0;
      final sections = buildElectrolytesPdfSections(pd);
      final k = valueOf(sections, 'Potassium need');
      expect(k, isNotNull);
      expect(k, isNot('—'));
      expect(double.parse(k!), closeTo(0, 1e-9));
    });

    test('A non-zero requirement is unaffected', () {
      final pd = PatientData()
        ..bodyWeightElec = 80
        ..kaliumIst = 3.0
        ..kaliumSoll = 4.0;
      final sections = buildElectrolytesPdfSections(pd);
      // (4.0 - 3.0) x 80 x 0.2 / 1.0 = 16.0
      expect(double.parse(valueOf(sections, 'Potassium need')!),
          closeTo(16, 0.05));
    });

    test('Ultrafiltration: target reached → final volume is the current one',
        () {
      // Regression: the getter returned 0 as soon as nothing was removed —
      // the card read as "no blood is left in the circuit at the end".
      final pd = PatientData()
        ..ufCurrentVolume = 4000
        ..ufCurrentHct = 24
        ..ufTargetHct = 24;
      final sections = buildUltrafiltrationPdfSections(pd);
      expect(valueOf(sections, 'Volume to remove (UF)'), '0');
      expect(valueOf(sections, 'Resulting circulating volume'), '4000');
    });

    test('Ultrafiltration without a value pair stays entirely "—"', () {
      final pd = PatientData()..ufCurrentVolume = 4000..ufCurrentHct = 20;
      final sections = buildUltrafiltrationPdfSections(pd);
      expect(valueOf(sections, 'Volume to remove (UF)'), '—');
      expect(valueOf(sections, 'Resulting circulating volume'), '—');
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // The PDF is actually built (coverage gap, v0.4.15)
  // ══════════════════════════════════════════════════════════════════════
  //
  // Until now only the data preparation was tested (PdfRow, resultIf) —
  // rendering itself sat at 10 % coverage because it was entangled with the
  // save dialog. Yet the PDF is the only artefact that leaves the app: an
  // exception while building it means the export fails with no fallback.
  //
  // These tests build real PDF bytes. They do not check appearance — that
  // needs eyes — but that the build completes and produces a valid document.
  group('PDF generation', () {
    /// %PDF-1.x at the start, %%EOF at the end — the minimum by which a PDF
    /// can be recognised.
    ///
    /// [minBytes] is deliberately a parameter rather than a fixed number.
    /// The first version demanded 1000 bytes across the board and reported a
    /// failure at 427 for the empty combined report — not a defect but a
    /// wrong expectation: a document in which no text is drawn embeds no
    /// font either, and the Roboto files make up the bulk of a normal PDF.
    /// The size therefore says something about the content here, not about
    /// validity.
    void expectValidPdf(List<int> bytes,
        {required String reason, int minBytes = 1000}) {
      expect(latin1.decode(bytes.take(8).toList()), startsWith('%PDF-'),
          reason: reason);
      final tail = latin1.decode(bytes.skip(bytes.length - 32).toList());
      expect(tail, contains('%%EOF'), reason: reason);
      expect(bytes.length, greaterThan(minBytes), reason: reason);
    }

    test('Single tab with complete data', () async {
      final pd = PatientData()
        ..artHb = 12
        ..saO2 = 99
        ..paO2 = 200
        ..venHb = 12
        ..svO2 = 75
        ..pvO2 = 40
        ..hzv = 5
        ..kof = 1.9;
      final bytes = await renderTabPdf(
        tabTitle: 'O2 delivery',
        sections: buildO2PdfSections(pd),
      );
      expectValidPdf(bytes, reason: 'gefuellter O2-Tab');
    });

    test('Empty tab — nothing but em dashes must not fail', () async {
      // The case a user triggers by accident.
      final bytes = await renderTabPdf(
        tabTitle: 'BSA',
        sections: buildBsaPdfSections(PatientData()),
      );
      expectValidPdf(bytes, reason: 'leerer BSA-Tab');
    });

    test('Rows with a footnote are rendered', () async {
      // PdfRow.note was silently dropped until block E (4.2). Now that the
      // note is rendered it is its own layout branch — and it is used by the
      // Calafiore perfusor rate when no supplementation is needed.
      final sections = [
        PdfSection(title: 'Mit Fussnote', rows: [
          PdfRow.numeric(label: 'Wert', value: 0, unit: 'ml/h',
              zeroIsValid: true, note: 'keine Zufuhr noetig'),
          PdfRow(label: 'Text', value: 'abc'),
        ]),
      ];
      final bytes = await renderTabPdf(tabTitle: 'Note', sections: sections);
      expectValidPdf(bytes, reason: 'Zeile mit Note');
    });

    test('Combined report across several tabs', () async {
      final pd = PatientData()
        ..height = 175
        ..weight = 80
        ..bodyWeightElec = 80
        ..baseExcess = -5;
      final bytes = await renderCombinedPdf(tabs: [
        PdfTabReport(tabTitle: 'BSA', sections: buildBsaPdfSections(pd)),
        PdfTabReport(tabTitle: 'Elektrolyte',
            sections: buildElectrolytesPdfSections(pd)),
      ]);
      expectValidPdf(bytes, reason: 'Gesamtbericht');
    });

    test('A combined report without tabs still yields a valid document',
        () async {
      // Not reachable from the UI: _exportCombinedReport() catches the empty
      // case and shows a hint instead. The test therefore only guarantees
      // that renderCombinedPdf() does not throw — an exception here would
      // turn any future change to the filter logic into a total failure of
      // the export.
      //
      // 300 instead of 1000 bytes: without drawn text no font is embedded,
      // and that is exactly what makes a normal PDF large. Measured, an
      // empty document is around 427 bytes.
      final bytes = await renderCombinedPdf(tabs: []);
      expectValidPdf(bytes, reason: 'leerer Gesamtbericht', minBytes: 300);
    });

    test('Very many rows force a page break', () async {
      // MultiPage paginates; a layout error in the header or footer only
      // shows up from the second page onwards.
      final rows = [
        for (var i = 0; i < 120; i++)
          PdfRow.numeric(label: 'Zeile $i', value: i.toDouble(), unit: 'ml'),
      ];
      final bytes = await renderTabPdf(
        tabTitle: 'Viele Zeilen',
        sections: [PdfSection(title: 'Lang', rows: rows)],
      );
      expectValidPdf(bytes, reason: 'mehrseitiges Dokument');
      expect(bytes.length, greaterThan(5000));
    });
  });
}
