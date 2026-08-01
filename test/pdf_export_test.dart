// Tests for the PDF row/section builders
// =======================================
// The PDF is the one artefact that leaves the app. Audit findings 1.1 and
// 1.2 both lived here and neither was covered by a test: the on-screen
// guards (ResultCard.missingInputs) had no counterpart in the export, so a
// half-filled oxygen tab printed a plausible-looking but wrong report.
//
// These tests build the section lists directly - no widget pumping needed,
// PdfRow is plain data.

import 'package:flutter_test/flutter_test.dart';
import 'package:perfusion_calc/models/patient_data.dart';
import 'package:perfusion_calc/screens/o2_delivery_screen.dart';
import 'package:perfusion_calc/screens/bsa_screen.dart';
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
}
