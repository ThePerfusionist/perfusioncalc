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

  group('Errechnete Null gegen fehlende Eingabe (Spiegelung von 1.1)', () {
    // Die ResultCard auf dem Bildschirm richtet sich nach missingInputs,
    // nicht nach dem Wert: bei vollstaendigen Eingaben zeigt sie 0.0. Das
    // PDF zeigte dafuer "—". Genau umgekehrt zu Befund 1.1, und im selben
    // Sinne falsch: die beiden Ausgaben widersprachen sich.

    test('Base Excess 0 → NaBic und TRIS drucken 0.0, nicht "—"', () {
      // BE 0 ist ein normaler Befund. Die richtige Antwort lautet
      // "0 ml, keine Korrektur noetig".
      final pd = PatientData()
        ..bodyWeightElec = 80
        ..baseExcess = 0;
      final sections = buildElectrolytesPdfSections(pd);
      expect(valueContaining(sections, 'NaBic'), '0.0');
      expect(valueContaining(sections, 'TRIS'), '0.0');
    });

    test('Ohne Gewicht bleibt es bei "—"', () {
      // Die Unterscheidung ist nur etwas wert, wenn der Fall "nicht
      // berechenbar" erhalten bleibt.
      final pd = PatientData()..baseExcess = 0;
      final sections = buildElectrolytesPdfSections(pd);
      expect(valueContaining(sections, 'NaBic'), '—');
      expect(valueContaining(sections, 'TRIS'), '—');
    });

    test('Ist gleich Soll → Bedarf ist 0, nicht "—"', () {
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

    test('Ein von Null verschiedener Bedarf bleibt unveraendert', () {
      final pd = PatientData()
        ..bodyWeightElec = 80
        ..kaliumIst = 3.0
        ..kaliumSoll = 4.0;
      final sections = buildElectrolytesPdfSections(pd);
      // (4.0 - 3.0) x 80 x 0.2 / 1.0 = 16.0
      expect(double.parse(valueOf(sections, 'Potassium need')!),
          closeTo(16, 0.05));
    });

    test('Ultrafiltration: Ziel erreicht → Endvolumen ist das aktuelle', () {
      // Regression: der Getter lieferte 0, sobald nichts entzogen wurde -
      // die Karte las sich als "am Ende ist kein Blut mehr im Kreislauf".
      final pd = PatientData()
        ..ufCurrentVolume = 4000
        ..ufCurrentHct = 24
        ..ufTargetHct = 24;
      final sections = buildUltrafiltrationPdfSections(pd);
      expect(valueOf(sections, 'Volume to remove (UF)'), '0');
      expect(valueOf(sections, 'Resulting circulating volume'), '4000');
    });

    test('Ultrafiltration ohne Wertepaar bleibt vollstaendig "—"', () {
      final pd = PatientData()..ufCurrentVolume = 4000..ufCurrentHct = 20;
      final sections = buildUltrafiltrationPdfSections(pd);
      expect(valueOf(sections, 'Volume to remove (UF)'), '—');
      expect(valueOf(sections, 'Resulting circulating volume'), '—');
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // Das PDF wird tatsaechlich gebaut (Abdeckungsluecke, v0.4.15)
  // ══════════════════════════════════════════════════════════════════════
  //
  // Bis hierher war nur die Datenaufbereitung getestet (PdfRow, resultIf) -
  // das Rendern selbst lag bei 10 % Abdeckung, weil es mit dem
  // Speichern-Dialog verwoben war. Das PDF ist aber das einzige Artefakt,
  // das die App verlaesst: eine Ausnahme beim Aufbau bedeutet, dass der
  // Export ersatzlos fehlschlaegt.
  //
  // Diese Tests bauen echte PDF-Bytes. Sie pruefen nicht das Aussehen -
  // dafuer braucht es Augen - sondern dass der Aufbau durchlaeuft und ein
  // gueltiges Dokument entsteht.
  group('PDF-Erzeugung', () {
    /// %PDF-1.x am Anfang, %%EOF am Ende - das Minimum, an dem sich ein
    /// PDF erkennen laesst.
    ///
    /// [minBytes] ist bewusst ein Parameter und keine feste Zahl. Die erste
    /// Fassung verlangte pauschal 1000 Bytes und meldete beim leeren
    /// Gesamtbericht einen Fehlschlag bei 427 - kein Defekt, sondern eine
    /// falsche Erwartung: Ein Dokument, in dem kein Text gezeichnet wird,
    /// bettet auch keine Schrift ein, und die Roboto-Dateien machen den
    /// Loewenanteil eines normalen PDFs aus. Die Groesse sagt hier also
    /// etwas ueber den Inhalt, nicht ueber die Gueltigkeit.
    void expectValidPdf(List<int> bytes,
        {required String reason, int minBytes = 1000}) {
      expect(latin1.decode(bytes.take(8).toList()), startsWith('%PDF-'),
          reason: reason);
      final tail = latin1.decode(bytes.skip(bytes.length - 32).toList());
      expect(tail, contains('%%EOF'), reason: reason);
      expect(bytes.length, greaterThan(minBytes), reason: reason);
    }

    test('Einzelner Tab mit vollstaendigen Daten', () async {
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

    test('Leerer Tab - lauter Gedankenstriche darf nicht scheitern', () async {
      // Der Fall, den ein Nutzer versehentlich ausloest.
      final bytes = await renderTabPdf(
        tabTitle: 'BSA',
        sections: buildBsaPdfSections(PatientData()),
      );
      expectValidPdf(bytes, reason: 'leerer BSA-Tab');
    });

    test('Zeilen mit Fussnote werden gerendert', () async {
      // PdfRow.note wurde bis Block E (4.2) still verworfen. Seit die Note
      // gerendert wird, ist sie ein eigener Layoutzweig - und wird von der
      // Calafiore-Perfusorrate benutzt, wenn keine Zufuhr noetig ist.
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

    test('Gesamtbericht ueber mehrere Tabs', () async {
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

    test('Gesamtbericht ohne Tabs erzeugt trotzdem ein gueltiges Dokument',
        () async {
      // Aus der Oberflaeche heraus nicht erreichbar: _exportCombinedReport()
      // faengt den leeren Fall ab und zeigt stattdessen einen Hinweis. Der
      // Test sichert daher nur zu, dass renderCombinedPdf() nicht wirft -
      // eine Ausnahme hier wuerde bei jeder kuenftigen Aenderung an der
      // Filterlogik zum Totalausfall des Exports fuehren.
      //
      // 300 statt 1000 Bytes: ohne gezeichneten Text wird keine Schrift
      // eingebettet, und genau die macht ein normales PDF gross. Gemessen
      // sind es rund 427 Bytes fuer ein leeres Dokument.
      final bytes = await renderCombinedPdf(tabs: []);
      expectValidPdf(bytes, reason: 'leerer Gesamtbericht', minBytes: 300);
    });

    test('Sehr viele Zeilen erzwingen einen Seitenumbruch', () async {
      // MultiPage bricht um; ein Layoutfehler im Header oder Footer faellt
      // erst ab der zweiten Seite auf.
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
