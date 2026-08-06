// Tests for CardioplegiaAlarmSettings
// ===================================
// The coverage report put this class at 10 % while its two siblings
// (CardioplegiaSettings, TransfusionSettings) stood at 100 % — and the third
// instance of the same asymmetry sat exactly in the untested part: load()
// did not clamp the stored value.
//
// The consequences here are the quietest of the three: a stored 0 makes
// expectedFireCount() return 0 permanently. The alarm is switched on, the UI
// shows it as active — and it never fires. Without any error message, on a
// reminder that gets relied upon during a case.

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

  group('Defaults', () {
    test('The alarm is off, so the app never makes noise unasked', () {
      expect(s.enabled, isFalse);
    });

    test('15 minutes is the lower bound of the Calafiore window', () {
      expect(CardioplegiaAlarmSettings.kDefaultTriggerMinutes, 15);
      expect(s.triggerMinutes, 15);
    });

    test('Sound and vibration on, repeat off', () {
      expect(s.sound, isTrue);
      expect(s.vibration, isTrue);
      expect(s.repeat, isFalse);
    });
  });

  group('Clamping the interval', () {
    test('Below the lower bound', () async {
      await s.setTriggerMinutes(0);
      expect(s.triggerMinutes, CardioplegiaAlarmSettings.kMinTriggerMinutes);
    });

    test('Above the upper bound', () async {
      await s.setTriggerMinutes(9999);
      expect(s.triggerMinutes, CardioplegiaAlarmSettings.kMaxTriggerMinutes);
    });

    test('Usual protocol intervals pass unchanged', () async {
      for (final v in [15.0, 20.0, 30.0, 90.0, 180.0]) {
        await s.setTriggerMinutes(v);
        expect(s.triggerMinutes, v);
      }
    });
  });

  group('Persistence', () {
    test('Changes are written', () async {
      await s.setEnabled(true);
      await s.setTriggerMinutes(20);
      await s.setRepeat(true);
      final p = await SharedPreferences.getInstance();
      expect(p.getBool(kEnabled), isTrue);
      expect(p.getDouble(kMinutes), 20);
      expect(p.getBool(kRepeat), isTrue);
    });

    test('load() restores stored values', () async {
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

    test('load() clamps a stored 0 — the alarm would never fire otherwise',
        () async {
      // The actual regression test. The value used to be taken raw;
      // expectedFireCount() returns 0 permanently for triggerMinutes <= 0,
      // so the enabled alarm stays silent.
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
          reason: 'an enabled alarm must have fired after 30 min');
    });

    test('load() clamps an absurdly large stored value', () async {
      SharedPreferences.setMockInitialValues({kMinutes: 10000.0});
      await s.load();
      expect(s.triggerMinutes, CardioplegiaAlarmSettings.kMaxTriggerMinutes);
    });

    test('Nothing stored → defaults', () async {
      SharedPreferences.setMockInitialValues({});
      await s.load();
      expect(s.enabled, isFalse);
      expect(s.triggerMinutes, 15);
      expect(s.sound, isTrue);
    });
  });

  group('Listener notification', () {
    test('Each setter reports exactly one real change', () async {
      var calls = 0;
      void listener() => calls++;
      s.addListener(listener);
      await s.setEnabled(true);
      await s.setEnabled(true); // unchanged
      await s.setTriggerMinutes(30);
      await s.setTriggerMinutes(30); // unchanged
      await s.setSound(false);
      await s.setVibration(false);
      await s.setRepeat(true);
      s.removeListener(listener);
      expect(calls, 5);
    });
  });

  group('Firing schedule (expectedFireCount)', () {
    int count(int minutes, {bool enabled = true, double trigger = 15,
        bool repeat = false}) =>
        CardioplegiaAlarmSettings.expectedFireCount(
          elapsed: Duration(minutes: minutes),
          enabled: enabled,
          triggerMinutes: trigger,
          repeat: repeat,
        );

    test('Switched off it never fires', () {
      expect(count(60, enabled: false), 0);
    });

    test('Before the trigger point nothing fires', () {
      expect(count(0), 0);
      expect(count(14), 0);
    });

    test('Exactly at the trigger point it fires', () {
      expect(count(15), 1);
    });

    test('Without repeat it stays at once', () {
      expect(count(30), 1);
      expect(count(200), 1);
    });

    test('With repeat, once per full interval', () {
      expect(count(15, repeat: true), 1);
      expect(count(29, repeat: true), 1);
      expect(count(30, repeat: true), 2);
      expect(count(45, repeat: true), 3);
    });

    test('An unusable interval does not fire rather than firing endlessly', () {
      // A division by 0 would be Infinity; the guard catches it.
      expect(count(60, trigger: 0), 0);
      expect(count(60, trigger: -5), 0);
    });

    test('Accurate to the second, not rounded to minutes', () {
      // The ticker runs once per second; a rounding error here would fire
      // the reminder up to 59 s early.
      int atSeconds(int sec) => CardioplegiaAlarmSettings.expectedFireCount(
            elapsed: Duration(seconds: sec),
            enabled: true,
            triggerMinutes: 15,
            repeat: false,
          );
      expect(atSeconds(15 * 60 - 1), 0);
      expect(atSeconds(15 * 60), 1);
    });

    test('The counter grows monotonically', () {
      // The screen compares the counter with the last value it saw. If it
      // ever dropped, the reminder would be raised twice.
      var previous = 0;
      for (var m = 0; m <= 120; m++) {
        final c = count(m, repeat: true, trigger: 20);
        expect(c, greaterThanOrEqualTo(previous), reason: 'at $m min');
        previous = c;
      }
    });
  });
}
