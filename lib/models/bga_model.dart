// Severinghaus-Temperaturkorrektur für Blutgasanalysen
// ====================================================
// Diese Klasse wurde aus hypothermia_screen.dart extrahiert, um sie
// unit-testbar zu machen. Die Screen-Datei importiert sie weiterhin.
//
// Quellen:
//   Severinghaus JW. J Appl Physiol 1958; 12: 485-6.
//     → PaO2, PaCO2, pH Temperaturkorrektur
//   Severinghaus JW. J Appl Physiol 1979; 46: 599-602.
//     → Sauerstoffdissoziationskurve
//   Henderson-Hasselbalch:
//     HCO3 = 0.0307 × PaCO2 × 10^(pH - 6.105)
//
// Sicherheit: Alle Getter geben null zurück, wenn
//   - Eingaben fehlen,
//   - Eingaben außerhalb physiologischer Bereiche liegen,
//   - das Ergebnis NaN oder Infinity wäre.

import 'dart:math';

class BgaModel {
  double? paO2;
  double? paCO2;
  double? pH;
  double? temp;

  /// Liefert v zurück, oder null wenn NaN/Infinity.
  static double? _safe(double v) {
    if (v.isNaN || v.isInfinite) return null;
    return v;
  }

  /// Temperatur-Korrekturkoeffizient nach Severinghaus.
  /// Wird intern von corrPaO2 und fTPercent verwendet.
  double _fT(double po2) {
    if (po2 <= 0) return 0.013;
    final inner = 0.243 * pow(po2 / 100.0, 3.88) + 1.0;
    if (inner <= 0) return 0.013;
    return 0.058 / inner + 0.013;
  }

  /// Temperatur-korrigierter PaO2 (mmHg).
  /// Physiologischer Temperaturbereich: 4°C (tiefe Hypothermie) bis 42°C
  /// (maligne Hyperthermie). PaO2 bis 800 mmHg erlaubt (unter 100% O2
  /// typisch max ~600).
  double? get corrPaO2 {
    if (paO2 == null || temp == null) return null;
    if (temp! < 4 || temp! > 42) return null;
    if (paO2! < 0 || paO2! > 800) return null;
    return _safe(paO2! * exp(_fT(paO2!) * (temp! - 37.0)));
  }

  /// Temperatur-korrigierter PaCO2 (mmHg).
  double? get corrPaCO2 {
    if (paCO2 == null || temp == null) return null;
    if (temp! < 4 || temp! > 42) return null;
    if (paCO2! < 0 || paCO2! > 200) return null;
    final result = paCO2! * pow(10.0, 0.0185 * (temp! - 37.0));
    return _safe(result.toDouble());
  }

  /// Temperatur-korrigierter pH.
  double? get corrPH {
    if (pH == null || temp == null) return null;
    if (temp! < 4 || temp! > 42) return null;
    if (pH! < 6.0 || pH! > 8.0) return null;
    return _safe(pH! - 0.0147 * (temp! - 37.0));
  }

  /// Sauerstoff-Sättigung in % aus (korrigiertem) PaO2.
  /// Severinghaus-Dissoziationskurve.
  double? get satFromPaO2 {
    final p = corrPaO2 ?? paO2;
    if (p == null || p <= 0) return null;
    final denominator = 23400.0 / (pow(p, 3) + 150.0 * p) + 1.0;
    if (denominator <= 0) return null;
    return _safe(100.0 / denominator);
  }

  /// Korrekturfaktor in % (wie stark sich der PaO2 pro °C ändert).
  double? get fTPercent {
    final p = corrPaO2 ?? paO2;
    if (p == null || p <= 0) return null;
    return _safe(_fT(p) * 100.0);
  }

  /// HCO3 nach Henderson-Hasselbalch (mmol/l).
  /// Nutzt temperaturkorrigierte Werte, falls vorhanden.
  double? get hco3 {
    final co2c = corrPaCO2 ?? paCO2;
    final phc  = corrPH    ?? pH;
    if (co2c == null || phc == null) return null;
    if (co2c <= 0) return null;
    final result = 0.0307 * co2c * pow(10.0, phc - 6.105);
    return _safe(result.toDouble());
  }
}
