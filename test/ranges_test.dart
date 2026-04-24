// Unit tests for Range plausibility checks
// =========================================
//
// Stellt sicher, dass die Plausibilitätslogik selbst korrekt funktioniert
// und verhindert, dass jemand versehentlich einen Normalbereich so verändert,
// dass typische Werte plötzlich als "unplausibel" markiert werden.

import 'package:flutter_test/flutter_test.dart';
import 'package:perfusion_calc/models/ranges.dart';

void main() {
  group('Range.contains()', () {
    const r = Range(5, 20, 'g/dl');

    test('Wert genau am Minimum gilt als plausibel', () {
      expect(r.contains(5), isTrue);
    });

    test('Wert genau am Maximum gilt als plausibel', () {
      expect(r.contains(20), isTrue);
    });

    test('Wert in der Mitte gilt als plausibel', () {
      expect(r.contains(14), isTrue);
    });

    test('Wert unterhalb wird als unplausibel erkannt', () {
      expect(r.contains(4), isFalse);
    });

    test('Wert oberhalb wird als unplausibel erkannt', () {
      expect(r.contains(21), isFalse);
    });

    test('null (kein Wert eingegeben) gilt nicht als unplausibel', () {
      // Wichtig: leere Felder sollen keine Warnung anzeigen, sonst leuchtet
      // beim ersten Öffnen die ganze App orange.
      expect(r.contains(null), isTrue);
    });
  });

  group('Range.display', () {
    test('Format ist "min–max unit"', () {
      const r = Range(70, 100, 'mmHg');
      expect(r.display, '70.0–100.0 mmHg');
    });
  });

  // Sanity-Checks: Typische Lehrbuch-Werte müssen in den definierten Ranges
  // liegen. Wenn jemand versehentlich z.B. den Hb-Bereich auf 10–20 ändert,
  // würde dieser Test den Fehler sofort erkennen.
  group('Plausible Werte aus dem Lehrbuch sind im Normbereich', () {
    test('Erwachsener Mann 175 cm / 70 kg', () {
      expect(Ranges.height.contains(175), isTrue);
      expect(Ranges.weight.contains(70), isTrue);
    });

    test('Normaler Hb 14 g/dl / Hct 42%', () {
      expect(Ranges.hb.contains(14), isTrue);
      expect(Ranges.hct.contains(42), isTrue);
    });

    test('Anämischer Patient mit Hb 7 ist plausibel', () {
      expect(Ranges.hb.contains(7), isTrue);
    });

    test('Hb 50 ist nicht plausibel (Tippfehler-Verdacht)', () {
      expect(Ranges.hb.contains(50), isFalse);
    });

    test('Negative Werte für Vitalparameter werden erkannt', () {
      expect(Ranges.weight.contains(-10), isFalse);
      expect(Ranges.height.contains(-5), isFalse);
    });

    test('CVP darf negativ sein (Spontanatmung)', () {
      // Wichtige Ausnahme: CVP kann tatsächlich kurz negativ werden.
      expect(Ranges.cvp.contains(-3), isTrue);
    });

    test('Standard-CI 2.4 ist plausibel', () {
      expect(Ranges.ci.contains(2.4), isTrue);
    });

    test('SaO2 99% ist plausibel, 110% nicht', () {
      expect(Ranges.saO2.contains(99), isTrue);
      expect(Ranges.saO2.contains(110), isFalse);
    });

    test('Pädiatrisches Gewicht 15 kg ist plausibel, 80 kg nicht', () {
      expect(Ranges.pediatricWeight.contains(15), isTrue);
      expect(Ranges.pediatricWeight.contains(80), isFalse);
    });
  });
}
