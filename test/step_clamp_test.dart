// Tests for clampStep (audit N-3 / R-3)
// =====================================
// This logic has two exceptions that nobody verifies while reading, and both
// are clinically relevant:
//
//   1. Values OUTSIDE the plausibility range must remain reachable with the
//      stepper buttons — the header of ranges.dart states explicitly that
//      extreme values are allowed for training (orange warning, calculation
//      continues). An earlier version clamped hard to [min, max] and took
//      that away.
//   2. Ranges with a negative lower bound — base excess, CVP — must keep
//      their negative values. Clamping those to 0 would be wrong.
//
// Per PROJECT_STATE § 7.7 rule 8: the fix changes behaviour, so it needs the
// same verification step as the finding that prompted it.

import 'package:flutter_test/flutter_test.dart';
import 'package:perfusion_calc/models/ranges.dart';
import 'package:perfusion_calc/utils/step_clamp.dart';

void main() {
  group('Without a range nothing is clamped', () {
    test('Arbitrary values pass through', () {
      expect(clampStep(-99, null, fromEmpty: false), -99);
      expect(clampStep(1e6, null, fromEmpty: true), 1e6);
    });
  });

  group('Starting from an empty field', () {
    test('Decrement lands on the lower bound, not at -0.1 kg', () {
      // The originally reported case.
      expect(clampStep(-0.1, Ranges.weight, fromEmpty: true), Ranges.weight.min);
    });

    test('Increment from empty is lifted to the lower bound', () {
      // 0.1 is below Ranges.weight.min (0.5) and is raised to it: 0.5 kg is
      // the more sensible first position than 0.1 kg.
      expect(clampStep(0.1, Ranges.weight, fromEmpty: true), Ranges.weight.min);
    });

    test('A value above the lower bound stays unchanged', () {
      expect(clampStep(70, Ranges.weight, fromEmpty: true), 70);
    });
  });

  group('Training intent: implausible values stay reachable', () {
    test('Hb can be stepped below the lower bound', () {
      // Ranges.hb.min is 4 g/dl; going below it has to remain possible —
      // severe anaemia is a training case, not an input error. The orange
      // warning does the communicating.
      final below = Ranges.hb.min - 1;
      expect(clampStep(below, Ranges.hb, fromEmpty: false), below);
    });

    test('Values above the upper bound are not capped', () {
      final above = Ranges.hb.max + 10;
      expect(clampStep(above, Ranges.hb, fromEmpty: false), above);
      expect(clampStep(Ranges.temperature.max + 5, Ranges.temperature,
          fromEmpty: false), Ranges.temperature.max + 5);
    });
  });

  group('Only the physically impossible is stopped', () {
    test('Non-negative range: stop at 0', () {
      expect(clampStep(-0.1, Ranges.weight, fromEmpty: false), 0);
      expect(clampStep(-5, Ranges.height, fromEmpty: false), 0);
    });

    test('Exactly 0 stays 0', () {
      expect(clampStep(0, Ranges.weight, fromEmpty: false), 0);
    });
  });

  group('Ranges with a negative lower bound keep negative values', () {
    test('Base excess may go negative', () {
      expect(Ranges.baseExcess.min, lessThan(0));
      expect(clampStep(-12, Ranges.baseExcess, fromEmpty: false), -12);
    });

    test('CVP may go negative', () {
      expect(Ranges.cvp.min, lessThan(0));
      expect(clampStep(-3, Ranges.cvp, fromEmpty: false), -3);
    });

    test('From an empty field base excess settles on its lower bound', () {
      expect(clampStep(-0.1, Ranges.baseExcess, fromEmpty: true), -0.1,
          reason: '-0.1 is above baseExcess.min, so it stays');
    });
  });
}
