// Tests für clampStep (Audit N-3 / R-3)
// ======================================
// Diese Logik hat zwei Ausnahmen, die beim Lesen niemand nachprüft, und
// beide sind klinisch relevant:
//
//   1. Werte AUSSERHALB der Plausibilitätsrange müssen per Knopf erreichbar
//      bleiben — der Kopf von ranges.dart hält ausdrücklich fest, dass
//      Extremwerte fürs Training erlaubt sind (orange Warnung, Rechnung
//      läuft weiter). Eine frühere Fassung klemmte hart auf [min, max] und
//      nahm das weg.
//   2. Ranges mit negativer Untergrenze — Base Excess, ZVD — müssen ihre
//      negativen Werte behalten. Ein Klemmen auf 0 wäre dort falsch.
//
// Nach PROJECT_STATE § 7.7 Regel 8: der Fix ändert Verhalten, also braucht
// er denselben Prüfschritt wie der Befund.

import 'package:flutter_test/flutter_test.dart';
import 'package:perfusion_calc/models/ranges.dart';
import 'package:perfusion_calc/utils/step_clamp.dart';

void main() {
  group('Ohne Range wird nicht geklemmt', () {
    test('Beliebige Werte passieren', () {
      expect(clampStep(-99, null, fromEmpty: false), -99);
      expect(clampStep(1e6, null, fromEmpty: true), 1e6);
    });
  });

  group('Start aus dem leeren Feld', () {
    test('Dekrement landet auf der Untergrenze, nicht bei -0,1 kg', () {
      // Der ursprünglich gemeldete Fall.
      expect(clampStep(-0.1, Ranges.weight, fromEmpty: true), Ranges.weight.min);
    });

    test('Inkrement aus dem Leeren wird nicht angehoben', () {
      // 0.1 liegt unter Ranges.weight.min (0.5) -> auf min gesetzt.
      expect(clampStep(0.1, Ranges.weight, fromEmpty: true), Ranges.weight.min);
    });

    test('Ein Wert oberhalb der Untergrenze bleibt unverändert', () {
      expect(clampStep(70, Ranges.weight, fromEmpty: true), 70);
    });
  });

  group('Trainingsabsicht: unplausible Werte bleiben erreichbar', () {
    test('Hb lässt sich unter die Untergrenze senken', () {
      // Ranges.hb.min ist 4 g/dl; darunter zu gehen muss möglich bleiben —
      // eine schwere Anämie ist ein Trainingsfall, kein Eingabefehler.
      // Die orange Warnung übernimmt die Kommunikation.
      final below = Ranges.hb.min - 1;
      expect(clampStep(below, Ranges.hb, fromEmpty: false), below);
    });

    test('Werte über der Obergrenze werden nicht gekappt', () {
      final above = Ranges.hb.max + 10;
      expect(clampStep(above, Ranges.hb, fromEmpty: false), above);
      expect(clampStep(Ranges.temperature.max + 5, Ranges.temperature,
          fromEmpty: false), Ranges.temperature.max + 5);
    });
  });

  group('Nur physikalisch Unmögliches wird gestoppt', () {
    test('Nicht-negative Range: Stopp bei 0', () {
      expect(clampStep(-0.1, Ranges.weight, fromEmpty: false), 0);
      expect(clampStep(-5, Ranges.height, fromEmpty: false), 0);
    });

    test('Exakt 0 bleibt 0', () {
      expect(clampStep(0, Ranges.weight, fromEmpty: false), 0);
    });
  });

  group('Ranges mit negativer Untergrenze behalten negative Werte', () {
    test('Base Excess darf negativ werden', () {
      expect(Ranges.baseExcess.min, lessThan(0));
      expect(clampStep(-12, Ranges.baseExcess, fromEmpty: false), -12);
    });

    test('ZVD darf negativ werden', () {
      expect(Ranges.cvp.min, lessThan(0));
      expect(clampStep(-3, Ranges.cvp, fromEmpty: false), -3);
    });

    test('Aus dem leeren Feld setzt Base Excess auf seine Untergrenze auf', () {
      expect(clampStep(-0.1, Ranges.baseExcess, fromEmpty: true), -0.1,
          reason: '-0.1 liegt oberhalb von baseExcess.min, bleibt also');
    });
  });
}
