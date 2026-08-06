// Tests for CardioplegiaSettings
// ==============================
// This was the only one of the three persisted settings without tests, even
// though it carries the del Nido mixing ratio — the value from which the
// crystalloid and blood shares of every dose are derived.
//
// The core is the clamping: at 100 % the blood share would be zero and
// delNidoRatio undefined. The setter bounded the value, load() did not for a
// long time — a stored value outside the band would have been taken raw.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:perfusion_calc/models/cardioplegia_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const key = 'cpl_delnido_cryst_percent';
  final cfg = CardioplegiaSettings.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await cfg.setDelNidoCrystalloidPercent(
        CardioplegiaSettings.kDefaultCrystalloidPercent);
  });

  group('Defaults', () {
    test('80 % corresponds to the classic 4:1 ratio', () {
      expect(cfg.delNidoCrystalloidPercent, 80);
      expect(cfg.delNidoBloodPercent, 20);
      expect(cfg.delNidoRatio, closeTo(4.0, 1e-9));
    });

    test('Crystalloid and blood share always add up to 100 %', () async {
      for (final v in [50.0, 62.5, 75.0, 90.0, 95.0]) {
        await cfg.setDelNidoCrystalloidPercent(v);
        expect(cfg.delNidoCrystalloidPercent + cfg.delNidoBloodPercent,
            closeTo(100, 1e-9));
      }
    });

    test('Known ratios are correct', () async {
      // 1:1 -> 50 %, 2:1 -> 66.67 %, 4:1 -> 80 %, 9:1 -> 90 %
      await cfg.setDelNidoCrystalloidPercent(50);
      expect(cfg.delNidoRatio, closeTo(1.0, 1e-9));
      await cfg.setDelNidoCrystalloidPercent(200 / 3);
      expect(cfg.delNidoRatio, closeTo(2.0, 1e-9));
      await cfg.setDelNidoCrystalloidPercent(90);
      expect(cfg.delNidoRatio, closeTo(9.0, 1e-9));
    });
  });

  group('Clamping', () {
    test('Below the band', () async {
      await cfg.setDelNidoCrystalloidPercent(10);
      expect(cfg.delNidoCrystalloidPercent, CardioplegiaSettings.kMinPercent);
    });

    test('Above the band', () async {
      await cfg.setDelNidoCrystalloidPercent(140);
      expect(cfg.delNidoCrystalloidPercent, CardioplegiaSettings.kMaxPercent);
    });

    test('100 % can never make the ratio undefined', () async {
      // The actual reason for the upper bound: at 100 % the blood share
      // would be zero and delNidoRatio a division by zero.
      await cfg.setDelNidoCrystalloidPercent(100);
      expect(cfg.delNidoBloodPercent, greaterThan(0));
      expect(cfg.delNidoRatio.isFinite, isTrue);
    });
  });

  group('Persistence', () {
    test('A changed value is written', () async {
      await cfg.setDelNidoCrystalloidPercent(75);
      final p = await SharedPreferences.getInstance();
      expect(p.getDouble(key), 75);
    });

    test('load() restores the stored value', () async {
      SharedPreferences.setMockInitialValues({key: 66.0});
      await cfg.load();
      expect(cfg.delNidoCrystalloidPercent, 66);
    });

    test('load() clamps an unusable stored value', () async {
      // Regression: load() used to take the value raw. A stored 100 would
      // have set the blood share to zero.
      SharedPreferences.setMockInitialValues({key: 100.0});
      await cfg.load();
      expect(cfg.delNidoCrystalloidPercent, CardioplegiaSettings.kMaxPercent);
      expect(cfg.delNidoBloodPercent, greaterThan(0));
    });

    test('Nothing stored → the default stands', () async {
      SharedPreferences.setMockInitialValues({});
      await cfg.load();
      expect(cfg.delNidoCrystalloidPercent,
          CardioplegiaSettings.kDefaultCrystalloidPercent);
    });
  });

  group('Notification', () {
    test('Only on a real change', () async {
      var calls = 0;
      void listener() => calls++;
      cfg.addListener(listener);
      await cfg.setDelNidoCrystalloidPercent(70);
      expect(calls, 1);
      await cfg.setDelNidoCrystalloidPercent(70);
      expect(calls, 1, reason: 'no rebuild for an unchanged value');
      cfg.removeListener(listener);
    });
  });
}
