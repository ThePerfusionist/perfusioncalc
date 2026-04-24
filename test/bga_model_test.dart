// Unit tests for BgaModel (Severinghaus temperature correction)
// =============================================================
//
// Referenzquellen:
//   Severinghaus JW. J Appl Physiol 1958; 12: 485-6.
//   Severinghaus JW. J Appl Physiol 1979; 46: 599-602.
//
// Toleranzen: closeTo() mit 0.5 für mmHg-Werte, 0.01 für pH (stärkere
// Genauigkeit nötig, da pH logarithmisch ist), 1.0% für Sättigungen.

import 'package:flutter_test/flutter_test.dart';
import 'package:perfusion_calc/models/bga_model.dart';

void main() {
  // ════════════════════════════════════════════════════════════════════════
  // Temperaturkorrektur
  // ════════════════════════════════════════════════════════════════════════
  group('Severinghaus bei 37°C (Normaltemperatur)', () {
    // Bei Körperkerntemperatur soll keine Korrektur stattfinden – alle
    // Werte bleiben identisch zum Messwert.

    test('PaO2 bleibt unverändert', () {
      final m = BgaModel()..paO2 = 100..temp = 37;
      expect(m.corrPaO2, closeTo(100.0, 0.001));
    });

    test('PaCO2 bleibt unverändert', () {
      final m = BgaModel()..paCO2 = 40..temp = 37;
      expect(m.corrPaCO2, closeTo(40.0, 0.001));
    });

    test('pH bleibt unverändert', () {
      final m = BgaModel()..pH = 7.40..temp = 37;
      expect(m.corrPH, closeTo(7.40, 0.001));
    });
  });

  group('Severinghaus bei 32°C (moderate Hypothermie)', () {
    // Klassisches Szenario: Patient bei 32°C, BGA-Gerät misst bei 37°C.
    // Bei Abkühlung sinken PaO2 und PaCO2, pH steigt.

    test('PaO2 100 → ca. 74.2 mmHg bei 32°C', () {
      final m = BgaModel()..paO2 = 100..temp = 32;
      expect(m.corrPaO2, closeTo(74.21, 0.5));
    });

    test('PaCO2 40 → ca. 32.3 mmHg bei 32°C', () {
      final m = BgaModel()..paCO2 = 40..temp = 32;
      expect(m.corrPaCO2, closeTo(32.33, 0.1));
    });

    test('pH 7.40 → ca. 7.47 bei 32°C (Alkalose durch Abkühlung)', () {
      final m = BgaModel()..pH = 7.40..temp = 32;
      expect(m.corrPH, closeTo(7.4735, 0.001));
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // Sauerstoffdissoziationskurve (klassische Referenzpunkte)
  // ════════════════════════════════════════════════════════════════════════
  group('O2-Dissoziationskurve (Severinghaus 1979)', () {
    // Diese drei Punkte sind die klassischen Lehrbuch-Referenzwerte.
    // Finden sie sich hier nicht wieder, ist die Formel kaputt.

    test('P50: PaO2 ≈ 27 mmHg → ~50% Sättigung', () {
      final m = BgaModel()..paO2 = 27..temp = 37;
      expect(m.satFromPaO2, closeTo(50, 1.0));
    });

    test('PaO2 60 mmHg → ca. 90% (Steilabfall der Kurve)', () {
      final m = BgaModel()..paO2 = 60..temp = 37;
      expect(m.satFromPaO2, closeTo(90.6, 1.0));
    });

    test('PaO2 100 mmHg → ca. 98% (Normalbereich)', () {
      final m = BgaModel()..paO2 = 100..temp = 37;
      expect(m.satFromPaO2, closeTo(97.7, 0.5));
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // HCO3 nach Henderson-Hasselbalch
  // ════════════════════════════════════════════════════════════════════════
  group('HCO3 (Henderson-Hasselbalch)', () {
    // Formel: HCO3 = 0.0307 × PaCO2 × 10^(pH - 6.105)

    test('Normalbefund (PaCO2 40, pH 7.40) → ca. 24 mmol/l', () {
      final m = BgaModel()
        ..paCO2 = 40..pH = 7.40..temp = 37;
      expect(m.hco3, closeTo(24.22, 0.1));
    });

    test('Acidose (PaCO2 40, pH 7.20) → niedriger HCO3', () {
      final m = BgaModel()
        ..paCO2 = 40..pH = 7.20..temp = 37;
      final hco3 = m.hco3!;
      expect(hco3, lessThan(20));  // deutlich unter Normalbereich
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // Validierung / Grenzwerte
  // ════════════════════════════════════════════════════════════════════════
  group('Eingabevalidierung', () {
    test('Temperatur 50°C wird abgelehnt (über maligner Hyperthermie)', () {
      final m = BgaModel()..paO2 = 100..temp = 50;
      expect(m.corrPaO2, isNull);
    });

    test('Temperatur -5°C wird abgelehnt', () {
      final m = BgaModel()..paO2 = 100..temp = -5;
      expect(m.corrPaO2, isNull);
    });

    test('Negative PaO2 wird abgelehnt', () {
      final m = BgaModel()..paO2 = -10..temp = 37;
      expect(m.corrPaO2, isNull);
    });

    test('pH 10 (nicht-physiologisch) wird abgelehnt', () {
      final m = BgaModel()..pH = 10..temp = 37;
      expect(m.corrPH, isNull);
    });

    test('Fehlende Eingaben liefern null', () {
      final m = BgaModel();
      expect(m.corrPaO2, isNull);
      expect(m.corrPaCO2, isNull);
      expect(m.corrPH, isNull);
      expect(m.satFromPaO2, isNull);
      expect(m.hco3, isNull);
    });
  });
}
