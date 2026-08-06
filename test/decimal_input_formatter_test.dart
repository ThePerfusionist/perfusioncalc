// Tests for DecimalTextInputFormatter (audit N-1)
// ===============================================
// The predecessor was FilteringTextInputFormatter.allow with a regex
// anchored by ^…$. That looks like a check of the whole string but is none:
// `allow` filters segment by segment, and when the anchored regex matches
// nowhere, what remains is an EMPTY field.
//
// In practice: 82.5 kg are in the weight field, one mistyped character next
// to it — and the value is gone. These tests record that this no longer
// happens.
//
// Per PROJECT_STATE § 7.7 rule 2, this test belongs next to the comment that
// carries the assumption about the API's behaviour.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfusion_calc/utils/decimal_input_formatter.dart';

/// TextEditingValue with the cursor at the end — that is how keyboard input
/// arrives.
TextEditingValue v(String text) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );

void main() {
  const formatter = DecimalTextInputFormatter();

  String apply(String before, String after) =>
      formatter.formatEditUpdate(v(before), v(after)).text;

  group('Valid input is accepted', () {
    test('Whole number', () => expect(apply('8', '82'), '82'));
    test('Decimal point', () => expect(apply('82', '82.'), '82.'));
    test('Decimal place', () => expect(apply('82.', '82.5'), '82.5'));
    test('Comma as separator', () => expect(apply('82', '82,'), '82,'));
    test('Negative sign', () => expect(apply('', '-'), '-'));
    test('Negative decimal', () => expect(apply('-2', '-2.5'), '-2.5'));
    test('Empty field', () => expect(apply('5', ''), ''));
  });

  group('Invalid input leaves the old value in place', () {
    test('A second separator does NOT clear the field', () {
      // The actual regression test. Before: ''.
      expect(apply('82.5', '82.5.'), '82.5');
    });

    test('Letter inside the value', () {
      expect(apply('82.5', '82.5a'), '82.5');
    });

    test('Double minus', () {
      expect(apply('-5', '--5'), '-5');
    });

    test('Minus in the middle', () {
      expect(apply('82', '8-2'), '82');
    });

    test('Mixed separators', () {
      expect(apply('1.2', '1.2,3'), '1.2');
    });

    test('A complete value survives any mistyped character', () {
      // The clinically relevant phrasing: the weight stays put.
      const weight = '82.5';
      for (final stray in ['.', ',', '-', 'x', ' ']) {
        expect(apply(weight, '$weight$stray'), weight,
            reason: 'mistyped "$stray" must not clear the field');
      }
    });
  });

  group('Partial input stays typeable', () {
    test('Every step on the way to -1.5 is valid', () {
      // If one of these intermediate states were rejected, the value could
      // not be typed at all.
      var text = '';
      for (final ch in ['-', '1', '.', '5']) {
        final next = text + ch;
        expect(apply(text, next), next, reason: 'intermediate state "$next"');
        text = next;
      }
    });
  });
}
