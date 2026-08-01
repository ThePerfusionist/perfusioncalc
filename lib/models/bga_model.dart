// Severinghaus temperature correction for blood gas analysis
// ============================================================
// This class was extracted from hypothermia_screen.dart to make it
// unit-testable. The screen file still imports it.
//
// Sources:
//   Severinghaus JW. J Appl Physiol 1958; 12: 485-6.
//     → PaO2, PaCO2, pH temperature correction
//   Severinghaus JW. J Appl Physiol 1979; 46: 599-602.
//     → Oxygen dissociation curve
//   Henderson-Hasselbalch:
//     HCO3 = 0.0307 × PaCO2 × 10^(pH - 6.105)
//
// Safety: all getters return null if
//   - inputs are missing,
//   - inputs are outside physiological ranges,
//   - the result would be NaN or Infinity.

import 'dart:math';

class BgaModel {
  double? paO2;
  double? paCO2;
  double? pH;
  double? temp;

  /// Returns v, or null if NaN/Infinity.
  static double? _safe(double v) {
    if (v.isNaN || v.isInfinite) return null;
    return v;
  }

  /// Severinghaus temperature correction coefficient.
  /// Used internally by corrPaO2 and fTPercent.
  double _fT(double po2) {
    if (po2 <= 0) return 0.013;
    final inner = 0.243 * pow(po2 / 100.0, 3.88) + 1.0;
    if (inner <= 0) return 0.013;
    return 0.058 / inner + 0.013;
  }

  /// Temperature-corrected PaO2 (mmHg).
  /// Physiological temperature range: 4°C (deep hypothermia) to 42°C
  /// (malignant hyperthermia). PaO2 up to 800 mmHg allowed (under 100%
  /// O2, typically max ~600).
  double? get corrPaO2 {
    if (paO2 == null || temp == null) return null;
    if (temp! < 4 || temp! > 42) return null;
    if (paO2! < 0 || paO2! > 800) return null;
    return _safe(paO2! * exp(_fT(paO2!) * (temp! - 37.0)));
  }

  /// Temperature-corrected PaCO2 (mmHg).
  double? get corrPaCO2 {
    if (paCO2 == null || temp == null) return null;
    if (temp! < 4 || temp! > 42) return null;
    if (paCO2! < 0 || paCO2! > 200) return null;
    final result = paCO2! * pow(10.0, 0.0185 * (temp! - 37.0));
    return _safe(result.toDouble());
  }

  /// Temperature-corrected pH.
  double? get corrPH {
    if (pH == null || temp == null) return null;
    if (temp! < 4 || temp! > 42) return null;
    if (pH! < 6.0 || pH! > 8.0) return null;
    return _safe(pH! - 0.0147 * (temp! - 37.0));
  }

  /// Oxygen saturation in % from (corrected) PaO2.
  /// Severinghaus dissociation curve.
  ///
  /// Model simplification, stated openly: the 37 °C dissociation curve is
  /// applied to a temperature-corrected PO2. Physiologically the curve
  /// itself shifts with temperature as well, so this is an approximation -
  /// deliberate, because the alternative needs a full temperature-dependent
  /// curve that the correction this screen teaches does not use either.
  double? get satFromPaO2 {
    final p = corrPaO2 ?? paO2;
    if (p == null || p <= 0) return null;
    final denominator = 23400.0 / (pow(p, 3) + 150.0 * p) + 1.0;
    if (denominator <= 0) return null;
    return _safe(100.0 / denominator);
  }

  /// Correction factor in % (how strongly PaO2 changes per °C).
  ///
  /// Must use the MEASURED 37 °C PaO2, exactly like [corrPaO2] does. Feeding
  /// the already-corrected value back in produced a displayed percentage
  /// that did not belong to the correction actually carried out - the number
  /// on screen and the number in the result were derived from different
  /// inputs.
  double? get fTPercent {
    final p = paO2;
    if (p == null || p <= 0) return null;
    return _safe(_fT(p) * 100.0);
  }

  /// HCO3 per Henderson-Hasselbalch (mmol/l).
  /// Uses temperature-corrected values if available.
  double? get hco3 {
    final co2c = corrPaCO2 ?? paCO2;
    final phc  = corrPH    ?? pH;
    if (co2c == null || phc == null) return null;
    if (co2c <= 0) return null;
    final result = 0.0307 * co2c * pow(10.0, phc - 6.105);
    return _safe(result.toDouble());
  }
}
