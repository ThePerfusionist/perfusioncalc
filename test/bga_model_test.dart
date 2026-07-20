// Unit tests for BgaModel (Severinghaus temperature correction)
// =============================================================
//
// Referenzquellen:
//   Severinghaus JW. J Appl Physiol 1958; 12: 485-6.
//   Severinghaus JW. J Appl Physiol 1979; 46: 599-602.
//     Eq. 1 (S aus PO2), Eq. 3 (Temperaturkoeffizient f_T) - Originalformeln
//     im Volltext verifiziert: S = ((PO2³+150·PO2)⁻¹×23400 + 1)⁻¹
//     Publizierter P50 der Eq. 1: 26.86 mmHg (Severinghaus 1979, S. 600).
//   Rosenthal TB. J Biol Chem 1948; 173: 25-30.
//     pH-Temperaturkoeffizient -0.0147 pH-Einheiten/°C, gültig 18-37°C
//     (bestätigt durch Craig FN, 1952 - siehe Marshall & Marshall, JECT 1977).
//   Bradley AF, Severinghaus JW, Stupfel M. J Appl Physiol 1956; 9: 201-4.
//     PCO2-Temperaturkoeffizient 0.0185.
//
// Toleranzen: closeTo() mit 0.5 für mmHg-Werte, 0.01 für pH (stärkere
// Genauigkeit nötig, da pH logarithmisch ist), 1.0% für Sättigungen -
// außer bei Tests, die EXAKT einen publizierten Referenzwert prüfen
// (dort enger toleriert, siehe Kommentare).

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

  group('pH-Temperaturkoeffizient (Rosenthal 1948, bestätigt Craig 1952)', () {
    // Die Konstante -0.0147 pH-Einheiten/°C stammt ursprünglich von
    // Rosenthal (J Biol Chem 1948;173:25-30), nicht von Bradley/Severinghaus
    // 1956 (die primär die PCO2/PO2-Koeffizienten liefern). Craig
    // bestätigte 1952 unabhängig denselben Wert. Dokumentierter
    // Gültigkeitsbereich: 18-37°C (Vollblut). Da die Formel eine reine
    // lineare Multiplikation ist, ist hier eine sehr enge Toleranz möglich -
    // dieser Test prüft die Konstante selbst, nicht nur eine Näherung.

    test('pH 7.40 bei 18°C (untere Grenze des validierten Bereichs) → 7.6793', () {
      final m = BgaModel()..pH = 7.40..temp = 18;
      // 7.40 - 0.0147 × (18 - 37) = 7.40 + 0.2793 = 7.6793
      expect(m.corrPH, closeTo(7.6793, 0.0005));
    });

    test('pH 7.40 bei 42°C (Fieber/Hyperthermie) → 7.3265', () {
      final m = BgaModel()..pH = 7.40..temp = 42;
      // 7.40 - 0.0147 × (42 - 37) = 7.40 - 0.0735 = 7.3265
      expect(m.corrPH, closeTo(7.3265, 0.0005));
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

    test('P50 EXAKT nach Severinghaus 1979 Eq.1: PaO2 26.86 mmHg → 50.0%', () {
      // Severinghaus selbst berichtet im Originalpaper (S. 600): "P50 with
      // Eq. 1 is 26.86" - das ist also der exakte Punkt, an dem Eq. 1 (die
      // hier implementierte Formel) selbst 50.0% liefert, im Gegensatz zum
      // klinisch gerundeten Lehrbuchwert 26.6-27 mmHg (Adair-Gleichung/
      // gemessene Werte). Enge Toleranz, da dies kein Rundungswert ist,
      // sondern der von der Formel selbst erzeugte Umkehrpunkt.
      final m = BgaModel()..paO2 = 26.86..temp = 37;
      expect(m.satFromPaO2, closeTo(50.0, 0.1));
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
