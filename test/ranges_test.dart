// Unit tests for Range plausibility checks
// =========================================
//
// Ensures the plausibility logic itself works correctly and prevents
// someone from accidentally changing a normal range so that typical
// values are suddenly flagged as "implausible".

import 'package:flutter_test/flutter_test.dart';
import 'package:perfusion_calc/models/ranges.dart';

void main() {
  group('Range.contains()', () {
    const r = Range(5, 20, 'g/dl');

    test('Value exactly at the minimum counts as plausible', () {
      expect(r.contains(5), isTrue);
    });

    test('Value exactly at the maximum counts as plausible', () {
      expect(r.contains(20), isTrue);
    });

    test('Value in the middle counts as plausible', () {
      expect(r.contains(14), isTrue);
    });

    test('Value below is recognized as implausible', () {
      expect(r.contains(4), isFalse);
    });

    test('Value above is recognized as implausible', () {
      expect(r.contains(21), isFalse);
    });

    test('null (no value entered) does not count as implausible', () {
      // Important: empty fields must not show a warning, or the whole app
      // would light up orange on first open.
      expect(r.contains(null), isTrue);
    });
  });

  group('Range.display', () {
    test('Whole numbers print without a decimal tail', () {
      // This string ends up in every plausibility tooltip; "70.0–100.0"
      // was cosmetic noise on values that are integers by nature.
      const r = Range(70, 100, 'mmHg');
      expect(r.display, '70–100 mmHg');
    });

    test('Real decimals are preserved', () {
      const r = Range(0.5, 6.0, 'l/min/m²');
      expect(r.display, '0.5–6 l/min/m²');
    });

    test('Negative bounds work', () {
      const r = Range(-5, 30, 'mmHg');
      expect(r.display, '-5–30 mmHg');
    });

    test('Unitless range leaves no double space', () {
      const r = Range(6.8, 7.8, '');
      expect(r.display.trim(), '6.8–7.8');
    });
  });

  group('Range.noteKey', () {
    test('Every note is an i18n key, never a finished string', () {
      // German literals used to be appended to an otherwise translated
      // tooltip, so an English user got a mixed-language message.
      const ranges = [
        Ranges.hb, Ranges.hct, Ranges.height, Ranges.weight,
        Ranges.paO2, Ranges.svO2, Ranges.baseExcess, Ranges.temperature,
      ];
      for (final r in ranges) {
        expect(r.noteKey, isNotNull);
        expect(r.noteKey, startsWith('range_note_'));
        expect(r.noteKey, matches(RegExp(r'^[a-z0-9_]+$')));
      }
    });
  });

  // Sanity checks: typical textbook values must fall within the defined
  // ranges. If someone accidentally changes e.g. the Hb range to 10-20,
  // this test would immediately catch the error.
  group('Plausible textbook values fall within the normal range', () {
    test('Adult man 175 cm / 70 kg', () {
      expect(Ranges.height.contains(175), isTrue);
      expect(Ranges.weight.contains(70), isTrue);
    });

    test('Normal Hb 14 g/dl / Hct 42%', () {
      expect(Ranges.hb.contains(14), isTrue);
      expect(Ranges.hct.contains(42), isTrue);
    });

    test('Anemic patient with Hb 7 is plausible', () {
      expect(Ranges.hb.contains(7), isTrue);
    });

    test('Hb 50 is not plausible (suspected typo)', () {
      expect(Ranges.hb.contains(50), isFalse);
    });

    test('Negative values for vital parameters are detected', () {
      expect(Ranges.weight.contains(-10), isFalse);
      expect(Ranges.height.contains(-5), isFalse);
    });

    test('CVP is allowed to be negative (spontaneous breathing)', () {
      // Important exception: CVP can genuinely go briefly negative.
      expect(Ranges.cvp.contains(-3), isTrue);
    });

    test('Standard CI 2.4 is plausible', () {
      expect(Ranges.ci.contains(2.4), isTrue);
    });

    test('SaO2 99% is plausible, 110% is not', () {
      expect(Ranges.saO2.contains(99), isTrue);
      expect(Ranges.saO2.contains(110), isFalse);
    });

    test('Pediatric weight 15 kg is plausible, 80 kg is not', () {
      expect(Ranges.pediatricWeight.contains(15), isTrue);
      expect(Ranges.pediatricWeight.contains(80), isFalse);
    });
  });
}
