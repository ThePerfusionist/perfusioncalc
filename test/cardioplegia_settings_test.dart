// Tests für CardioplegiaSettings
// ===============================
// Diese Klasse war die einzige der drei persistierten Einstellungen ohne
// Tests, obwohl sie das del-Nido-Mischungsverhältnis trägt — den Wert, aus
// dem die Kristalloid- und Blutanteile jeder Dosis berechnet werden.
//
// Der Kern ist die Klemmung: bei 100 % wäre der Blutanteil null und
// delNidoRatio undefiniert. Der Setter begrenzt, load() tat es lange nicht —
// ein gespeicherter Wert außerhalb des Bandes wäre also roh übernommen
// worden.

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

  group('Standardwerte', () {
    test('80 % entspricht dem klassischen 4:1-Verhältnis', () {
      expect(cfg.delNidoCrystalloidPercent, 80);
      expect(cfg.delNidoBloodPercent, 20);
      expect(cfg.delNidoRatio, closeTo(4.0, 1e-9));
    });

    test('Kristalloid- und Blutanteil ergeben immer 100 %', () async {
      for (final v in [50.0, 62.5, 75.0, 90.0, 95.0]) {
        await cfg.setDelNidoCrystalloidPercent(v);
        expect(cfg.delNidoCrystalloidPercent + cfg.delNidoBloodPercent,
            closeTo(100, 1e-9));
      }
    });

    test('Bekannte Verhältnisse stimmen', () async {
      // 1:1 -> 50 %, 2:1 -> 66,67 %, 4:1 -> 80 %, 9:1 -> 90 %
      await cfg.setDelNidoCrystalloidPercent(50);
      expect(cfg.delNidoRatio, closeTo(1.0, 1e-9));
      await cfg.setDelNidoCrystalloidPercent(200 / 3);
      expect(cfg.delNidoRatio, closeTo(2.0, 1e-9));
      await cfg.setDelNidoCrystalloidPercent(90);
      expect(cfg.delNidoRatio, closeTo(9.0, 1e-9));
    });
  });

  group('Klemmung', () {
    test('Unter dem Band', () async {
      await cfg.setDelNidoCrystalloidPercent(10);
      expect(cfg.delNidoCrystalloidPercent, CardioplegiaSettings.kMinPercent);
    });

    test('Über dem Band', () async {
      await cfg.setDelNidoCrystalloidPercent(140);
      expect(cfg.delNidoCrystalloidPercent, CardioplegiaSettings.kMaxPercent);
    });

    test('100 % kann das Verhältnis nie undefiniert machen', () async {
      // Der eigentliche Grund für die Obergrenze: bei 100 % wäre der
      // Blutanteil null und delNidoRatio eine Division durch null.
      await cfg.setDelNidoCrystalloidPercent(100);
      expect(cfg.delNidoBloodPercent, greaterThan(0));
      expect(cfg.delNidoRatio.isFinite, isTrue);
    });
  });

  group('Persistenz', () {
    test('Ein geänderter Wert wird geschrieben', () async {
      await cfg.setDelNidoCrystalloidPercent(75);
      final p = await SharedPreferences.getInstance();
      expect(p.getDouble(key), 75);
    });

    test('load() stellt den gespeicherten Wert wieder her', () async {
      SharedPreferences.setMockInitialValues({key: 66.0});
      await cfg.load();
      expect(cfg.delNidoCrystalloidPercent, 66);
    });

    test('load() klemmt einen unbrauchbaren gespeicherten Wert', () async {
      // Regression: load() übernahm den Wert früher roh. Ein gespeichertes
      // 100 hätte den Blutanteil auf null gesetzt.
      SharedPreferences.setMockInitialValues({key: 100.0});
      await cfg.load();
      expect(cfg.delNidoCrystalloidPercent, CardioplegiaSettings.kMaxPercent);
      expect(cfg.delNidoBloodPercent, greaterThan(0));
    });

    test('Nichts gespeichert → Standard bleibt', () async {
      SharedPreferences.setMockInitialValues({});
      await cfg.load();
      expect(cfg.delNidoCrystalloidPercent,
          CardioplegiaSettings.kDefaultCrystalloidPercent);
    });
  });

  group('Benachrichtigung', () {
    test('Nur bei echter Änderung', () async {
      var calls = 0;
      void listener() => calls++;
      cfg.addListener(listener);
      await cfg.setDelNidoCrystalloidPercent(70);
      expect(calls, 1);
      await cfg.setDelNidoCrystalloidPercent(70);
      expect(calls, 1, reason: 'kein Rebuild für einen unveränderten Wert');
      cfg.removeListener(listener);
    });
  });
}
