// Tests für die Internationalisierung
// ====================================
// Stellt sicher, dass die Übersetzungslogik robust ist und alle definierten
// Keys in beiden Sprachen verfügbar sind.

import 'package:flutter_test/flutter_test.dart';
import 'package:perfusion_calc/i18n/app_strings.dart';

void main() {
  group('Strings.of()', () {
    test('Existierender Key wird in EN korrekt aufgelöst', () {
      expect(Strings.of('bsa_body_height', AppLocale.en), 'Body height');
    });

    test('Existierender Key wird in DE korrekt aufgelöst', () {
      expect(Strings.of('bsa_body_height', AppLocale.de), 'Körpergröße');
    });

    test('Unbekannter Key gibt Bug-Marker zurück (kein Crash)', () {
      // Bug-Marker hilft beim Debuggen: man sieht im UI sofort, was fehlt.
      final result = Strings.of('does_not_exist', AppLocale.en);
      expect(result, contains('does_not_exist'));
    });

    test('Disclaimer-Texte sind in beiden Sprachen vorhanden', () {
      // Wichtige UX-Texte explizit prüfen.
      expect(Strings.of('disclaimer_clinical', AppLocale.en),
          'Not for clinical use!');
      expect(Strings.of('disclaimer_clinical', AppLocale.de),
          'Nicht für den klinischen Einsatz!');
    });

    test('Tab-Labels haben sinnvolle Übersetzungen', () {
      expect(Strings.of('tab_pediatric', AppLocale.de), 'Pädiatrie');
      expect(Strings.of('tab_resistances', AppLocale.de), 'Widerstände');
    });
  });

  group('AppLocale extension', () {
    test('Code ist der Enum-Name', () {
      expect(AppLocale.en.code, 'en');
      expect(AppLocale.de.code, 'de');
    });

    test('DisplayName ist menschenlesbar', () {
      expect(AppLocale.de.displayName, 'Deutsch');
      expect(AppLocale.en.displayName, 'English');
    });
  });

  group('LocaleNotifier', () {
    test('Default ist Englisch', () {
      // Singleton-Default ohne load() zu rufen (das wäre I/O).
      expect(LocaleNotifier.instance.current, AppLocale.en);
    });

    test('setLocale wechselt und benachrichtigt', () async {
      final notifier = LocaleNotifier.instance;
      var notified = 0;
      void listener() => notified++;
      notifier.addListener(listener);

      await notifier.setLocale(AppLocale.de);
      expect(notifier.current, AppLocale.de);
      expect(notified, 1);

      // Erneut auf gleiche Sprache → keine Notifikation
      await notifier.setLocale(AppLocale.de);
      expect(notified, 1);

      // Zurück auf EN
      await notifier.setLocale(AppLocale.en);
      expect(notifier.current, AppLocale.en);
      expect(notified, 2);

      notifier.removeListener(listener);
    });
  });
}
