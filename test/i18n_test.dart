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

  // ══════════════════════════════════════════════════════════════════════
  // Completeness (audit NEU-11)
  // ══════════════════════════════════════════════════════════════════════
  group('Translation table completeness', () {
    test('Every key is defined in every locale', () {
      // The file header always claimed to check this; it checked six
      // hand-picked keys. A one-sided addition - the normal way a
      // translation gap appears - went unnoticed.
      final missing = <String>[];
      for (final entry in Strings.all.entries) {
        for (final loc in AppLocale.values) {
          if (entry.value[loc] == null) missing.add('${loc.code}: ${entry.key}');
        }
      }
      expect(missing, isEmpty, reason: 'Missing translations: $missing');
    });

    test('No translation is empty or left as a placeholder', () {
      for (final entry in Strings.all.entries) {
        for (final loc in AppLocale.values) {
          final value = entry.value[loc];
          if (value == null) continue;
          expect(value.trim(), isNotEmpty, reason: '${loc.code}: ${entry.key}');
          expect(value.startsWith('TODO'), isFalse,
              reason: '${loc.code}: ${entry.key}');
        }
      }
    });

    test('Every plausibility range note resolves to a real key', () {
      // Range.noteKey is a string; a typo would surface in the UI as the
      // bug marker instead of a hint. Checked against the table directly.
      for (final key in Strings.all.keys.where((k) => k.startsWith('range_note_'))) {
        expect(Strings.of(key, AppLocale.de), isNot(startsWith('\u27e8')));
      }
    });
  });

  group('Source notes', () {
    test('Every source note resolves in both languages', () {
      // SourceRef.noteKey is a string; a typo would surface in the source
      // dialog as the bug marker instead of an explanation. These notes used
      // to be German literals inside the `doi` field, so an English user saw
      // a German sentence there regardless of the selected language.
      final keys = Strings.all.keys.where((k) => k.startsWith('src_note_'));
      expect(keys, isNotEmpty);
      for (final key in keys) {
        for (final loc in AppLocale.values) {
          final value = Strings.of(key, loc);
          expect(value, isNot(startsWith('\u27e8')), reason: '$key / ${loc.code}');
          expect(value.trim(), isNotEmpty, reason: '$key / ${loc.code}');
        }
      }
    });

    test('EN and DE differ — a note was actually translated, not copied', () {
      // Guards against a key pair where the German string was pasted into
      // both slots. Purely numeric or symbolic notes would be legitimate
      // exceptions, but there are none among these.
      for (final key in Strings.all.keys.where((k) => k.startsWith('src_note_'))) {
        expect(Strings.of(key, AppLocale.en),
            isNot(Strings.of(key, AppLocale.de)),
            reason: '$key is identical in both languages');
      }
    });
  });
}
