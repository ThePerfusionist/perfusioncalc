// Tests for formatElapsed (cardioplegia re-dose clock)
// =====================================================
// The function feeds both the timer card and the in-app banner. If they ever
// disagreed about how long ago the last dose was given, the banner would be
// actively misleading during a case - which is why this got pulled out of
// the screen's State into its own file in the first place.

import 'package:flutter_test/flutter_test.dart';
import 'package:perfusion_calc/utils/duration_format.dart';

void main() {
  group('formatElapsed', () {
    test('Zero', () {
      expect(formatElapsed(Duration.zero), '00:00');
    });

    test('Seconds are zero padded', () {
      expect(formatElapsed(const Duration(seconds: 7)), '00:07');
    });

    test('Boundary 59 → 60 seconds', () {
      expect(formatElapsed(const Duration(seconds: 59)), '00:59');
      expect(formatElapsed(const Duration(seconds: 60)), '01:00');
    });

    test('Typical Calafiore re-dose window', () {
      expect(formatElapsed(const Duration(minutes: 15)), '15:00');
      expect(formatElapsed(const Duration(minutes: 20, seconds: 5)), '20:05');
    });

    test('Boundary 3599 → 3600 seconds switches to h:mm:ss', () {
      expect(formatElapsed(const Duration(seconds: 3599)), '59:59');
      expect(formatElapsed(const Duration(seconds: 3600)), '1:00:00');
    });

    test('Bretschneider protection window (~180 min)', () {
      expect(formatElapsed(const Duration(minutes: 180)), '3:00:00');
    });

    test('Hours are not padded, minutes and seconds always are', () {
      expect(formatElapsed(const Duration(hours: 1, minutes: 5, seconds: 3)),
          '1:05:03');
    });

    test('Two-digit hours still work', () {
      expect(formatElapsed(const Duration(hours: 12, minutes: 34, seconds: 56)),
          '12:34:56');
    });
  });
}
