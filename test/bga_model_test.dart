// Unit tests for BgaModel (Severinghaus temperature correction)
// =============================================================
//
// Reference sources:
//   Severinghaus JW. J Appl Physiol 1958; 12: 485-6.
//   Severinghaus JW. J Appl Physiol 1979; 46: 599-602.
//     Eq. 1 (S from PO2), Eq. 3 (temperature coefficient f_T) - original
//     formulas verified against the full text: S = ((PO2³+150·PO2)⁻¹×23400 + 1)⁻¹
//     Published P50 of Eq. 1: 26.86 mmHg (Severinghaus 1979, p. 600).
//   Rosenthal TB. J Biol Chem 1948; 173: 25-30.
//     pH temperature coefficient -0.0147 pH units/°C, valid 18-37°C
//     (confirmed by Craig FN, 1952 - see Marshall & Marshall, JECT 1977).
//   Bradley AF, Severinghaus JW, Stupfel M. J Appl Physiol 1956; 9: 201-4.
//     PCO2 temperature coefficient 0.0185.
//
// Tolerances: closeTo() with 0.5 for mmHg values, 0.01 for pH (higher
// precision needed since pH is logarithmic), 1.0% for saturations -
// except for tests that check EXACTLY a published reference value
// (tighter tolerance there, see comments).

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:perfusion_calc/models/bga_model.dart';

void main() {
  // ════════════════════════════════════════════════════════════════════════
  // Temperature correction
  // ════════════════════════════════════════════════════════════════════════
  group('Severinghaus at 37°C (normal temperature)', () {
    // At core body temperature, no correction should take place – all
    // values stay identical to the measured value.

    test('PaO2 stays unchanged', () {
      final m = BgaModel()..paO2 = 100..temp = 37;
      expect(m.corrPaO2, closeTo(100.0, 0.001));
    });

    test('PaCO2 stays unchanged', () {
      final m = BgaModel()..paCO2 = 40..temp = 37;
      expect(m.corrPaCO2, closeTo(40.0, 0.001));
    });

    test('pH stays unchanged', () {
      final m = BgaModel()..pH = 7.40..temp = 37;
      expect(m.corrPH, closeTo(7.40, 0.001));
    });
  });

  group('pH temperature coefficient (Rosenthal 1948, confirmed by Craig 1952)', () {
    // The constant -0.0147 pH units/°C originally comes from Rosenthal
    // (J Biol Chem 1948;173:25-30), not from Bradley/Severinghaus 1956
    // (who primarily provide the PCO2/PO2 coefficients). Craig
    // independently confirmed the same value in 1952. Documented range of
    // validity: 18-37°C (whole blood). Since the formula is a pure linear
    // multiplication, a very tight tolerance is possible here - this test
    // checks the constant itself, not just an approximation.

    test('pH 7.40 at 18°C (lower bound of the validated range) → 7.6793', () {
      final m = BgaModel()..pH = 7.40..temp = 18;
      // 7.40 - 0.0147 × (18 - 37) = 7.40 + 0.2793 = 7.6793
      expect(m.corrPH, closeTo(7.6793, 0.0005));
    });

    test('pH 7.40 at 42°C (fever/hyperthermia) → 7.3265', () {
      final m = BgaModel()..pH = 7.40..temp = 42;
      // 7.40 - 0.0147 × (42 - 37) = 7.40 - 0.0735 = 7.3265
      expect(m.corrPH, closeTo(7.3265, 0.0005));
    });
  });

  group('Severinghaus at 32°C (moderate hypothermia)', () {
    // Classic scenario: patient at 32°C, blood gas analyzer measures at
    // 37°C. On cooling, PaO2 and PaCO2 drop, pH rises.

    test('PaO2 100 → approx. 74.2 mmHg at 32°C', () {
      final m = BgaModel()..paO2 = 100..temp = 32;
      expect(m.corrPaO2, closeTo(74.21, 0.5));
    });

    test('PaCO2 40 → approx. 32.3 mmHg at 32°C', () {
      final m = BgaModel()..paCO2 = 40..temp = 32;
      expect(m.corrPaCO2, closeTo(32.33, 0.1));
    });

    test('pH 7.40 → approx. 7.47 at 32°C (alkalosis from cooling)', () {
      final m = BgaModel()..pH = 7.40..temp = 32;
      expect(m.corrPH, closeTo(7.4735, 0.001));
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // Oxygen dissociation curve (classic reference points)
  // ════════════════════════════════════════════════════════════════════════
  group('O2 dissociation curve (Severinghaus 1979)', () {
    // These three points are the classic textbook reference values.
    // If they don't come out right here, the formula is broken.

    test('P50: PaO2 ≈ 27 mmHg → ~50% saturation', () {
      final m = BgaModel()..paO2 = 27..temp = 37;
      expect(m.satFromPaO2, closeTo(50, 1.0));
    });

    test('P50 EXACTLY per Severinghaus 1979 Eq.1: PaO2 26.86 mmHg → 50.0%', () {
      // Severinghaus himself reports in the original paper (p. 600): "P50
      // with Eq. 1 is 26.86" - so that's the exact point where Eq. 1 (the
      // formula implemented here) itself yields 50.0%, as opposed to the
      // clinically rounded textbook value of 26.6-27 mmHg (Adair
      // equation/measured values). Tight tolerance, since this isn't a
      // rounded value but the inflection point produced by the formula
      // itself.
      final m = BgaModel()..paO2 = 26.86..temp = 37;
      expect(m.satFromPaO2, closeTo(50.0, 0.1));
    });

    test('PaO2 60 mmHg → approx. 90% (steep drop of the curve)', () {
      final m = BgaModel()..paO2 = 60..temp = 37;
      expect(m.satFromPaO2, closeTo(90.6, 1.0));
    });

    test('PaO2 100 mmHg → approx. 98% (normal range)', () {
      final m = BgaModel()..paO2 = 100..temp = 37;
      expect(m.satFromPaO2, closeTo(97.7, 0.5));
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // HCO3 per Henderson-Hasselbalch
  // ════════════════════════════════════════════════════════════════════════
  group('HCO3 (Henderson-Hasselbalch)', () {
    // Formula: HCO3 = 0.0307 × PaCO2 × 10^(pH - 6.105)

    test('Normal finding (PaCO2 40, pH 7.40) → approx. 24 mmol/l', () {
      final m = BgaModel()
        ..paCO2 = 40..pH = 7.40..temp = 37;
      expect(m.hco3, closeTo(24.22, 0.1));
    });

    test('Acidosis (PaCO2 40, pH 7.20) → lower HCO3', () {
      final m = BgaModel()
        ..paCO2 = 40..pH = 7.20..temp = 37;
      final hco3 = m.hco3!;
      expect(hco3, lessThan(20));  // clearly below the normal range
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // Validation / boundary values
  // ════════════════════════════════════════════════════════════════════════
  group('Input validation', () {
    test('Temperature 50°C is rejected (above malignant hyperthermia)', () {
      final m = BgaModel()..paO2 = 100..temp = 50;
      expect(m.corrPaO2, isNull);
    });

    test('Temperature -5°C is rejected', () {
      final m = BgaModel()..paO2 = 100..temp = -5;
      expect(m.corrPaO2, isNull);
    });

    test('Negative PaO2 is rejected', () {
      final m = BgaModel()..paO2 = -10..temp = 37;
      expect(m.corrPaO2, isNull);
    });

    test('pH 10 (non-physiological) is rejected', () {
      final m = BgaModel()..pH = 10..temp = 37;
      expect(m.corrPH, isNull);
    });

    test('Missing inputs return null', () {
      final m = BgaModel();
      expect(m.corrPaO2, isNull);
      expect(m.corrPaCO2, isNull);
      expect(m.corrPH, isNull);
      expect(m.satFromPaO2, isNull);
      expect(m.hco3, isNull);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // Displayed correction factor (audit 1.6)
  // ══════════════════════════════════════════════════════════════════════
  group('fTPercent', () {
    test('Is derived from the measured PaO2, not from the corrected one', () {
      // corrPaO2 uses _fT(paO2). If fTPercent used _fT(corrPaO2) the
      // displayed percentage would not belong to the correction actually
      // carried out - two numbers on one screen from different inputs.
      final m = BgaModel()
        ..paO2 = 100
        ..temp = 28;
      // Same measured PaO2 at a different temperature must yield the same
      // factor, because the factor is a property of PO2 alone.
      final other = BgaModel()
        ..paO2 = 100
        ..temp = 37;
      expect(m.fTPercent, isNotNull);
      expect(m.fTPercent, closeTo(other.fTPercent!, 1e-9));
    });

    test('Matches the coefficient used inside corrPaO2', () {
      final m = BgaModel()
        ..paO2 = 100
        ..temp = 30;
      // corrPaO2 = paO2 × exp(f_T × (T - 37)) → solve back for f_T.
      final implied =
          (log(m.corrPaO2! / m.paO2!) / (m.temp! - 37.0)) * 100.0;
      expect(m.fTPercent, closeTo(implied, 1e-9));
    });

    test('Returns null without PaO2', () {
      expect((BgaModel()..temp = 30).fTPercent, isNull);
    });
  });
}
