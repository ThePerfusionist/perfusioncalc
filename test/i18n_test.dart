// Tests for internationalization
// ================================
// Ensures the translation logic is robust and all defined keys are
// available in both languages.

import 'package:flutter_test/flutter_test.dart';
import 'package:perfusion_calc/i18n/app_strings.dart';

void main() {
  group('Strings.of()', () {
    test('Existing key resolves correctly in EN', () {
      expect(Strings.of('bsa_body_height', AppLocale.en), 'Body height');
    });

    test('Existing key resolves correctly in DE', () {
      expect(Strings.of('bsa_body_height', AppLocale.de), 'Körpergröße');
    });

    test('Unknown key returns a bug marker (no crash)', () {
      // The bug marker helps with debugging: you can see immediately in
      // the UI what's missing.
      final result = Strings.of('does_not_exist', AppLocale.en);
      expect(result, contains('does_not_exist'));
    });

    test('Disclaimer texts are present in both languages', () {
      // Explicitly check important UX texts.
      expect(Strings.of('disclaimer_clinical', AppLocale.en),
          'Not for clinical use!');
      expect(Strings.of('disclaimer_clinical', AppLocale.de),
          'Nicht für den klinischen Einsatz!');
    });

    test('Tab labels have sensible translations', () {
      expect(Strings.of('tab_pediatric', AppLocale.de), 'Pädiatrie');
      expect(Strings.of('tab_resistances', AppLocale.de), 'Widerstände');
    });
  });

  group('AppLocale extension', () {
    test('Code is the enum name', () {
      expect(AppLocale.en.code, 'en');
      expect(AppLocale.de.code, 'de');
    });

    test('DisplayName is human-readable', () {
      expect(AppLocale.de.displayName, 'Deutsch');
      expect(AppLocale.en.displayName, 'English');
    });
  });

  group('LocaleNotifier', () {
    test('Default is English', () {
      // Singleton default without calling load() (that would be I/O).
      expect(LocaleNotifier.instance.current, AppLocale.en);
    });

    test('setLocale switches and notifies', () async {
      final notifier = LocaleNotifier.instance;
      var notified = 0;
      void listener() => notified++;
      notifier.addListener(listener);

      await notifier.setLocale(AppLocale.de);
      expect(notifier.current, AppLocale.de);
      expect(notified, 1);

      // Same language again → no notification
      await notifier.setLocale(AppLocale.de);
      expect(notified, 1);

      // Back to EN
      await notifier.setLocale(AppLocale.en);
      expect(notifier.current, AppLocale.en);
      expect(notified, 2);

      notifier.removeListener(listener);
    });
  });
}
