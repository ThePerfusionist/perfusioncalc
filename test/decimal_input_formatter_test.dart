// Tests für DecimalTextInputFormatter (Audit N-1)
// ================================================
// Der Vorgänger war FilteringTextInputFormatter.allow mit einer auf ^…$
// verankerten Regex. Das sieht aus wie eine Prüfung des Gesamtstrings, ist
// aber keine: `allow` filtert segmentweise, und wenn die verankerte Regex
// nirgends passt, bleibt ein LEERES Feld übrig.
//
// Praktisch: 82,5 kg stehen im Gewichtsfeld, ein Fehltipp daneben - und der
// Wert ist weg. Diese Tests halten fest, dass genau das nicht mehr passiert.
//
// Nach PROJECT_STATE § 7.7 Regel 2 gehört dieser Test neben den Kommentar,
// der die Annahme über das Verhalten der API trägt.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfusion_calc/utils/decimal_input_formatter.dart';

/// TextEditingValue mit Cursor am Ende - so kommt Tastatureingabe an.
TextEditingValue v(String text) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );

void main() {
  const formatter = DecimalTextInputFormatter();

  String apply(String before, String after) =>
      formatter.formatEditUpdate(v(before), v(after)).text;

  group('Gültige Eingaben werden übernommen', () {
    test('Ganze Zahl', () => expect(apply('8', '82'), '82'));
    test('Dezimalpunkt', () => expect(apply('82', '82.'), '82.'));
    test('Dezimalstelle', () => expect(apply('82.', '82.5'), '82.5'));
    test('Komma als Trennzeichen', () => expect(apply('82', '82,'), '82,'));
    test('Negatives Vorzeichen', () => expect(apply('', '-'), '-'));
    test('Negative Dezimalzahl', () => expect(apply('-2', '-2.5'), '-2.5'));
    test('Leeres Feld', () => expect(apply('5', ''), ''));
  });

  group('Ungültige Eingaben lassen den alten Wert stehen', () {
    test('Zweites Trennzeichen löscht das Feld NICHT', () {
      // Der eigentliche Regressionstest. Vorher: ''.
      expect(apply('82.5', '82.5.'), '82.5');
    });

    test('Buchstabe mitten im Wert', () {
      expect(apply('82.5', '82.5a'), '82.5');
    });

    test('Doppeltes Minus', () {
      expect(apply('-5', '--5'), '-5');
    });

    test('Minus in der Mitte', () {
      expect(apply('82', '8-2'), '82');
    });

    test('Gemischte Trennzeichen', () {
      expect(apply('1.2', '1.2,3'), '1.2');
    });

    test('Ein voller Wert geht durch einen Fehltipp nicht verloren', () {
      // Die klinisch relevante Formulierung: das Gewicht bleibt stehen.
      const weight = '82.5';
      for (final stray in ['.', ',', '-', 'x', ' ']) {
        expect(apply(weight, '$weight$stray'), weight,
            reason: 'Fehltipp "$stray" darf das Feld nicht leeren');
      }
    });
  });

  group('Teileingaben bleiben tippbar', () {
    test('Der Weg zu -1.5 ist an jeder Stelle gültig', () {
      // Wäre einer dieser Zwischenzustände verboten, ließe sich der Wert
      // nicht eintippen.
      var text = '';
      for (final ch in ['-', '1', '.', '5']) {
        final next = text + ch;
        expect(apply(text, next), next, reason: 'Zwischenzustand "$next"');
        text = next;
      }
    });
  });
}
