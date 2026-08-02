// Tests für CardioplegiaAlarmSettings
// ====================================
// Die Abdeckungsauswertung wies diese Klasse mit 10 % aus, während ihre
// beiden Geschwister (CardioplegiaSettings, TransfusionSettings) bei 100 %
// standen — und genau im ungetesteten Teil steckte der dritte Fall
// derselben Asymmetrie: load() klemmte den gespeicherten Wert nicht.
//
// Die Folgen sind hier die stillsten der drei: ein gespeichertes 0 lässt
// expectedFireCount() dauerhaft 0 zurückgeben. Der Alarm ist eingeschaltet,
// die Oberfläche zeigt ihn als aktiv — und er feuert nie. Ohne
// Fehlermeldung, an einer Erinnerung, auf die man sich im Fall verlässt.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:perfusion_calc/models/cardioplegia_alarm_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const kEnabled = 'cpl_alarm_enabled';
  const kMinutes = 'cpl_alarm_minutes';
  const kRepeat = 'cpl_alarm_repeat';
  final s = CardioplegiaAlarmSettings.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await s.setEnabled(false);
    await s.setTriggerMinutes(CardioplegiaAlarmSettings.kDefaultTriggerMinutes);
    await s.setSound(true);
    await s.setVibration(true);
    await s.setRepeat(false);
  });

  group('Standardwerte', () {
    test('Alarm ist aus, damit die App nie ungefragt Lärm macht', () {
      expect(s.enabled, isFalse);
    });

    test('15 Minuten entspricht der Untergrenze des Calafiore-Fensters', () {
      expect(CardioplegiaAlarmSettings.kDefaultTriggerMinutes, 15);
      expect(s.triggerMinutes, 15);
    });

    test('Ton und Vibration an, Wiederholung aus', () {
      expect(s.sound, isTrue);
      expect(s.vibration, isTrue);
      expect(s.repeat, isFalse);
    });
  });

  group('Klemmung des Intervalls', () {
    test('Unter der Untergrenze', () async {
      await s.setTriggerMinutes(0);
      expect(s.triggerMinutes, CardioplegiaAlarmSettings.kMinTriggerMinutes);
    });

    test('Über der Obergrenze', () async {
      await s.setTriggerMinutes(9999);
      expect(s.triggerMinutes, CardioplegiaAlarmSettings.kMaxTriggerMinutes);
    });

    test('Übliche Protokollintervalle passieren unverändert', () async {
      for (final v in [15.0, 20.0, 30.0, 90.0, 180.0]) {
        await s.setTriggerMinutes(v);
        expect(s.triggerMinutes, v);
      }
    });
  });

  group('Persistenz', () {
    test('Änderungen werden geschrieben', () async {
      await s.setEnabled(true);
      await s.setTriggerMinutes(20);
      await s.setRepeat(true);
      final p = await SharedPreferences.getInstance();
      expect(p.getBool(kEnabled), isTrue);
      expect(p.getDouble(kMinutes), 20);
      expect(p.getBool(kRepeat), isTrue);
    });

    test('load() stellt gespeicherte Werte wieder her', () async {
      SharedPreferences.setMockInitialValues({
        kEnabled: true,
        kMinutes: 25.0,
        kRepeat: true,
      });
      await s.load();
      expect(s.enabled, isTrue);
      expect(s.triggerMinutes, 25);
      expect(s.repeat, isTrue);
    });

    test('load() klemmt ein gespeichertes 0 — der Alarm feuert sonst nie',
        () async {
      // Der eigentliche Regressionstest. Vorher wurde der Wert roh
      // übernommen; expectedFireCount() gibt bei triggerMinutes <= 0
      // dauerhaft 0 zurück, der eingeschaltete Alarm bleibt stumm.
      SharedPreferences.setMockInitialValues({kEnabled: true, kMinutes: 0.0});
      await s.load();
      expect(s.triggerMinutes, CardioplegiaAlarmSettings.kMinTriggerMinutes);
      expect(
          CardioplegiaAlarmSettings.expectedFireCount(
            elapsed: const Duration(minutes: 30),
            enabled: s.enabled,
            triggerMinutes: s.triggerMinutes,
            repeat: false,
          ),
          1,
          reason: 'eingeschalteter Alarm muss nach 30 min gefeuert haben');
    });

    test('load() klemmt einen absurd großen gespeicherten Wert', () async {
      SharedPreferences.setMockInitialValues({kMinutes: 10000.0});
      await s.load();
      expect(s.triggerMinutes, CardioplegiaAlarmSettings.kMaxTriggerMinutes);
    });

    test('Nichts gespeichert → Standardwerte', () async {
      SharedPreferences.setMockInitialValues({});
      await s.load();
      expect(s.enabled, isFalse);
      expect(s.triggerMinutes, 15);
      expect(s.sound, isTrue);
    });
  });

  group('Benachrichtigung der Zuhörer', () {
    test('Jeder Setter meldet genau eine echte Änderung', () async {
      var calls = 0;
      void listener() => calls++;
      s.addListener(listener);
      await s.setEnabled(true);
      await s.setEnabled(true); // unverändert
      await s.setTriggerMinutes(30);
      await s.setTriggerMinutes(30); // unverändert
      await s.setSound(false);
      await s.setVibration(false);
      await s.setRepeat(true);
      s.removeListener(listener);
      expect(calls, 5);
    });
  });

  group('Feuerplan (expectedFireCount)', () {
    int count(int minutes, {bool enabled = true, double trigger = 15,
        bool repeat = false}) =>
        CardioplegiaAlarmSettings.expectedFireCount(
          elapsed: Duration(minutes: minutes),
          enabled: enabled,
          triggerMinutes: trigger,
          repeat: repeat,
        );

    test('Ausgeschaltet feuert nie', () {
      expect(count(60, enabled: false), 0);
    });

    test('Vor dem Auslösepunkt feuert nichts', () {
      expect(count(0), 0);
      expect(count(14), 0);
    });

    test('Genau am Auslösepunkt feuert es', () {
      expect(count(15), 1);
    });

    test('Ohne Wiederholung bleibt es bei einmal', () {
      expect(count(30), 1);
      expect(count(200), 1);
    });

    test('Mit Wiederholung einmal je vollem Intervall', () {
      expect(count(15, repeat: true), 1);
      expect(count(29, repeat: true), 1);
      expect(count(30, repeat: true), 2);
      expect(count(45, repeat: true), 3);
    });

    test('Ein unbrauchbares Intervall feuert nicht statt endlos', () {
      // Division durch 0 wäre Infinity; der Guard fängt das ab.
      expect(count(60, trigger: 0), 0);
      expect(count(60, trigger: -5), 0);
    });

    test('Sekundengenau, nicht minutengerundet', () {
      // Der Ticker läuft im Sekundentakt; ein Rundungsfehler hier würde die
      // Erinnerung bis zu 59 s zu früh auslösen.
      int atSeconds(int sec) => CardioplegiaAlarmSettings.expectedFireCount(
            elapsed: Duration(seconds: sec),
            enabled: true,
            triggerMinutes: 15,
            repeat: false,
          );
      expect(atSeconds(15 * 60 - 1), 0);
      expect(atSeconds(15 * 60), 1);
    });

    test('Der Zähler wächst monoton', () {
      // Der Screen vergleicht den Zählerstand mit dem zuletzt gesehenen.
      // Fiele er zwischendurch, würde die Erinnerung mehrfach ausgelöst.
      var previous = 0;
      for (var m = 0; m <= 120; m++) {
        final c = count(m, repeat: true, trigger: 20);
        expect(c, greaterThanOrEqualTo(previous), reason: 'bei $m min');
        previous = c;
      }
    });
  });
}
