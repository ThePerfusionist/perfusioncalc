// Tests for CardioplegiaSettings
// ==============================
// This was the only one of the three persisted settings without tests, even
// though it carries the del Nido mixing ratio — the value from which the
// crystalloid and blood shares of every dose are derived.
//
// The core is the clamping: at 100 % the blood share would be zero and
// delNidoRatio undefined. The setter bounded the value, load() did not for a
// long time — a stored value outside the band would have been taken raw.
//
// Since v0.4.38 the class also persists the Calafiore Perfusor syringe. Its
// values are sanitised rather than clamped (they are free entries whose
// ranges only warn), so the tests below pin down both halves: deliberate
// entries survive a restart unchanged, garbage does not survive at all.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:perfusion_calc/models/cardioplegia_settings.dart';
import 'package:perfusion_calc/models/calafiore_syringe.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const key = 'cpl_delnido_cryst_percent';
  final cfg = CardioplegiaSettings.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await cfg.setDelNidoCrystalloidPercent(
        CardioplegiaSettings.kDefaultCrystalloidPercent);
    // The singleton outlives each test: reset the syringe part as well.
    await cfg.setCalafioreKclVolume(null);
    await cfg.setCalafioreKclConc(null);
    await cfg.setCalafioreMgVolume(null);
    await cfg.setCalafioreMgConc(null);
    await cfg.setCalafioreKclInPercent(false);
    await cfg.setCalafioreMgInPercent(false);
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

  group('Calafiore syringe', () {
    const kVol = 'cpl_calafiore_kcl_volume';
    const kConc = 'cpl_calafiore_kcl_conc';
    const mVol = 'cpl_calafiore_mg_volume';
    const mConc = 'cpl_calafiore_mg_conc';
    const kPct = 'cpl_calafiore_kcl_unit_percent';
    const mPct = 'cpl_calafiore_mg_unit_percent';

    test('Fresh install: syringe empty, units mmol/ml', () async {
      SharedPreferences.setMockInitialValues({});
      await cfg.load();
      expect(cfg.calafioreSyringe, CalafioreSyringe.empty);
      expect(cfg.calafioreSyringe.hasAnyInput, isFalse);
      expect(cfg.calafioreKclInPercent, isFalse);
      expect(cfg.calafioreMgInPercent, isFalse);
    });

    test('Entered values are written', () async {
      await cfg.setCalafioreKclVolume(40);
      await cfg.setCalafioreKclConc(2.0);
      await cfg.setCalafioreMgVolume(10);
      await cfg.setCalafioreMgConc(2.0);
      await cfg.setCalafioreKclInPercent(true);
      final p = await SharedPreferences.getInstance();
      expect(p.getDouble(kVol), 40);
      expect(p.getDouble(kConc), 2.0);
      expect(p.getDouble(mVol), 10);
      expect(p.getDouble(mConc), 2.0);
      expect(p.getBool(kPct), isTrue);
      expect(cfg.calafioreSyringe.resultingKConc, closeTo(1.6, 1e-9));
      expect(cfg.calafioreSyringe.resultingMgConc, closeTo(0.4, 1e-9));
    });

    test('load() restores the syringe after a restart', () async {
      // The actual feature: values entered in one session are there in the
      // next, including the unit the concentrations were typed in.
      SharedPreferences.setMockInitialValues({
        kVol: 40.0, kConc: 2.0, mVol: 10.0, mConc: 2.0,
        kPct: true, mPct: true,
      });
      await cfg.load();
      expect(cfg.calafioreSyringe, const CalafioreSyringe(
          kclVolume: 40, kclStockConc: 2.0, mgVolume: 10, mgStockConc: 2.0));
      expect(cfg.calafioreKclInPercent, isTrue);
      expect(cfg.calafioreMgInPercent, isTrue);
    });

    test('Clearing a field removes the stored entry', () async {
      // Otherwise an emptied field would come back after the next start.
      await cfg.setCalafioreMgVolume(10);
      await cfg.setCalafioreMgVolume(null);
      final p = await SharedPreferences.getInstance();
      expect(p.containsKey(mVol), isFalse);
      expect(cfg.calafioreSyringe.mgVolume, isNull);
    });

    test('Values outside the plausibility range are kept, not clamped', () async {
      // Ranges only warn. A deliberate 120 ml must not turn into 100 ml
      // after a restart.
      SharedPreferences.setMockInitialValues({kVol: 120.0, kConc: 3.5});
      await cfg.load();
      expect(cfg.calafioreSyringe.kclVolume, 120);
      expect(cfg.calafioreSyringe.kclStockConc, 3.5);
    });

    test('load() drops values no entry can produce', () async {
      SharedPreferences.setMockInitialValues({
        kVol: double.nan, kConc: double.infinity, mVol: -10.0, mConc: 2.0,
      });
      await cfg.load();
      expect(cfg.calafioreSyringe.kclVolume, isNull);
      expect(cfg.calafioreSyringe.kclStockConc, isNull);
      expect(cfg.calafioreSyringe.mgVolume, isNull);
      expect(cfg.calafioreSyringe.mgStockConc, 2.0,
          reason: 'one bad entry must not take the others with it');
      expect(cfg.calafioreSyringe.resultingKConc, 0);
    });

    test('An entry of the wrong type costs only that entry', () async {
      SharedPreferences.setMockInitialValues({
        kVol: 'forty', kConc: 2.0, kPct: 'yes',
        'cpl_delnido_cryst_percent': 75.0,
      });
      await cfg.load();
      expect(cfg.calafioreSyringe.kclVolume, isNull);
      expect(cfg.calafioreSyringe.kclStockConc, 2.0);
      expect(cfg.calafioreKclInPercent, isFalse);
      expect(cfg.delNidoCrystalloidPercent, 75,
          reason: 'the del Nido ratio still loads');
    });

    test('Setters reject garbage the same way', () async {
      await cfg.setCalafioreKclVolume(-5);
      expect(cfg.calafioreSyringe.kclVolume, isNull);
      await cfg.setCalafioreKclConc(double.nan);
      expect(cfg.calafioreSyringe.kclStockConc, isNull);
    });

    test('sanitizeSyringeValue', () {
      expect(CardioplegiaSettings.sanitizeSyringeValue(null), isNull);
      expect(CardioplegiaSettings.sanitizeSyringeValue(double.nan), isNull);
      expect(CardioplegiaSettings.sanitizeSyringeValue(double.negativeInfinity), isNull);
      expect(CardioplegiaSettings.sanitizeSyringeValue(-0.1), isNull);
      expect(CardioplegiaSettings.sanitizeSyringeValue(0), 0,
          reason: '0 ml MgSO4 is a valid "no magnesium" entry');
      expect(CardioplegiaSettings.sanitizeSyringeValue(40), 40);
    });

    test('Notifies only on a real change', () async {
      var calls = 0;
      void listener() => calls++;
      cfg.addListener(listener);
      await cfg.setCalafioreKclVolume(40);
      await cfg.setCalafioreKclVolume(40);
      await cfg.setCalafioreKclInPercent(true);
      await cfg.setCalafioreKclInPercent(true);
      expect(calls, 2);
      cfg.removeListener(listener);
    });
  });
}
