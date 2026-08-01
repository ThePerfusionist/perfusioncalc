// Tests for the tab definition
// =============================
// TabController was constructed with a literal `length: 12` next to a
// 12-entry list. Adding a thirteenth tab and forgetting the literal is the
// classic version of this bug, and it throws at runtime, not at compile
// time. The controller now derives its length from the list; these tests
// cover what that alone cannot.

import 'package:flutter_test/flutter_test.dart';
import 'package:perfusion_calc/i18n/app_strings.dart';
import 'package:perfusion_calc/main.dart';

void main() {
  group('MainScreen.kTabs', () {
    test('Has the expected number of tabs', () {
      // Deliberately a literal here and nowhere else: if this fails, the
      // tab list changed and TabBarView's children must be checked by hand.
      expect(MainScreen.kTabs.length, 12);
    });

    test('Tab keys are unique', () {
      final keys = MainScreen.kTabs.map((t) => t.key).toList();
      expect(keys.toSet().length, keys.length);
    });

    test('Every tab label resolves in both languages', () {
      for (final tab in MainScreen.kTabs) {
        for (final loc in AppLocale.values) {
          final label = Strings.of(tab.key, loc);
          expect(label, isNot(startsWith('\u27e8')),
              reason: 'Missing translation for ${tab.key} in ${loc.code}');
          expect(label.trim(), isNotEmpty);
        }
      }
    });

    test('Keys follow the tab_ naming convention', () {
      for (final tab in MainScreen.kTabs) {
        expect(tab.key, startsWith('tab_'));
      }
    });
  });
}
