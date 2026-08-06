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
import 'package:perfusion_calc/models/bga_model.dart';
import 'package:perfusion_calc/models/patient_data.dart';

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

  group('Combined report covers every calculating tab', () {
    // The candidate list was a hand-maintained copy of the tab order. A new
    // calculating tab would have had to be added there, and nothing would
    // have been a reminder — unlike the previously hard-wired TabController
    // this would not have thrown an exception but silently left a chapter
    // out of the delivered report.
    final candidates =
        buildCombinedReportCandidates(PatientData(), BgaModel());

    test('Count matches kTabs minus the pure reference tabs', () {
      final computing = MainScreen.kTabs
          .where((t) => !kNonComputingTabKeys.contains(t.key))
          .toList();
      expect(candidates.length, computing.length);
    });

    test('Titles and order match the tab bar', () {
      final expected = MainScreen.kTabs
          .where((t) => !kNonComputingTabKeys.contains(t.key))
          .map((t) => Strings.of(t.key, AppLocale.en))
          .toList();
      expect(candidates.map((c) => c.tabTitle).toList(), expected);
    });

    test('The excluded tabs actually exist', () {
      // Otherwise a typo in kNonComputingTabKeys would silently defeat the
      // check above.
      final keys = MainScreen.kTabs.map((t) => t.key).toSet();
      for (final k in kNonComputingTabKeys) {
        expect(keys, contains(k));
      }
    });

    test('Without input every candidate consists solely of em dashes', () {
      // This is the precondition for the "only filled tabs" filter in the
      // combined report to work at all.
      for (final tab in candidates) {
        final values =
            tab.sections.expand((s) => s.rows).map((r) => r.value).toSet();
        expect(values, everyElement('—'), reason: tab.tabTitle);
      }
    });
  });
}
