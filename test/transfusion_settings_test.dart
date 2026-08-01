// Tests for TransfusionSettings
// ==============================
// The value this class holds divides Davies' formula, so it scales every
// pediatric transfusion volume linearly. A clamp that lets a 0 through, or a
// load() that silently drops the stored value, would move a clinical number
// without anyone noticing.
//
// SharedPreferences is faked via setMockInitialValues, so these run on the VM
// without a platform channel.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:perfusion_calc/models/patient_data.dart';
import 'package:perfusion_calc/models/transfusion_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const key = 'tx_rbc_unit_hct_percent';
  final tx = TransfusionSettings.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await tx.reset();
  });

  group('Defaults', () {
    test('Ships with 55 %', () {
      expect(TransfusionSettings.kDefaultRbcUnitHematocritPercent, 55);
      expect(tx.rbcUnitHematocritPercent, 55);
      expect(tx.isDefault, isTrue);
    });

    test('The fraction is what the formula divides by', () {
      expect(tx.rbcUnitHematocritFraction, closeTo(0.55, 1e-9));
    });
  });

  group('Clamping', () {
    test('Below the band snaps to the minimum', () async {
      await tx.setRbcUnitHematocritPercent(5);
      expect(tx.rbcUnitHematocritPercent, TransfusionSettings.kMinPercent);
    });

    test('Above the band snaps to the maximum', () async {
      await tx.setRbcUnitHematocritPercent(150);
      expect(tx.rbcUnitHematocritPercent, TransfusionSettings.kMaxPercent);
    });

    test('Zero can never reach the formula', () async {
      // Guards against a division by zero producing an infinite volume.
      await tx.setRbcUnitHematocritPercent(0);
      expect(tx.rbcUnitHematocritPercent, greaterThan(0));
    });

    test('The whole German specification band is accepted', () async {
      for (final v in [50.0, 55.0, 60.0, 65.0, 70.0]) {
        await tx.setRbcUnitHematocritPercent(v);
        expect(tx.rbcUnitHematocritPercent, v);
      }
    });
  });

  group('Persistence', () {
    test('A changed value is written to SharedPreferences', () async {
      await tx.setRbcUnitHematocritPercent(62);
      final p = await SharedPreferences.getInstance();
      expect(p.getDouble(key), 62);
    });

    test('load() restores the stored value - survives an app restart', () async {
      SharedPreferences.setMockInitialValues({key: 68.0});
      await tx.load();
      expect(tx.rbcUnitHematocritPercent, 68);
      expect(tx.isDefault, isFalse);
    });

    test('load() clamps a corrupted stored value', () async {
      SharedPreferences.setMockInitialValues({key: 999.0});
      await tx.load();
      expect(tx.rbcUnitHematocritPercent, TransfusionSettings.kMaxPercent);
    });

    test('Nothing stored yet → the default stands', () async {
      SharedPreferences.setMockInitialValues({});
      await tx.load();
      expect(tx.rbcUnitHematocritPercent, 55);
    });
  });

  group('Listeners', () {
    test('A change notifies, an identical value does not', () async {
      var calls = 0;
      void listener() => calls++;
      tx.addListener(listener);
      await tx.setRbcUnitHematocritPercent(60);
      expect(calls, 1);
      await tx.setRbcUnitHematocritPercent(60);
      expect(calls, 1, reason: 'no rebuild for an unchanged value');
      tx.removeListener(listener);
    });
  });

  group('Effect on the transfusion volume', () {
    test('The configured value reaches the result', () async {
      final pd = PatientData()
        ..pediatricWeight = 20
        ..desiredHbIncrease = 2;
      await tx.setRbcUnitHematocritPercent(60);
      // Davies' worked example: 10 ml/kg for +2 g/dl at Hct 0.60.
      expect(pd.transfusionVolume(tx.rbcUnitHematocritPercent),
          closeTo(200, 0.001));
      await tx.setRbcUnitHematocritPercent(50);
      expect(pd.transfusionVolume(tx.rbcUnitHematocritPercent),
          closeTo(240, 0.001));
    });
  });
}
