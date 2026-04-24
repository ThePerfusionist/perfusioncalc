// Unit tests for PerfusionCalc formulas
// =====================================
//
// Ziel: Jede klinische Formel in PatientData hat mindestens einen Test-Fall
// mit einem bekannten Referenzwert aus der Primärliteratur.
//
// Laufen automatisch bei jedem Push durch den GitHub-Actions-Workflow.
//
// Bei einem Fehlschlag: entweder wurde eine Formel falsch geändert, oder der
// Testfall ist falsch. In beiden Fällen: HINSCHAUEN, nicht einfach anpassen.
//
// Toleranzen: closeTo() mit epsilon 0.01 (Zwei Dezimalstellen) reicht für die
// meisten klinischen Werte. Für Sättigungen (S-förmige Kurve) nutzen wir 0.5%.

import 'package:flutter_test/flutter_test.dart';
import 'package:perfusion_calc/models/patient_data.dart';

void main() {
  // ════════════════════════════════════════════════════════════════════════
  // BSA, Cardiac Output, Blood Volume
  // ════════════════════════════════════════════════════════════════════════
  group('BSA (DuBois 1916)', () {
    // Formel: BSA = 0.007184 × H^0.725 × W^0.425
    // Quelle: DuBois D, DuBois EF. Arch Intern Med 1916; 17: 863-871.

    test('Referenz-Erwachsener 175 cm / 70 kg ≈ 1.85 m²', () {
      final pd = PatientData()..height = 175..weight = 70;
      expect(pd.bsa, closeTo(1.848, 0.01));
    });

    test('Großer Mann 180 cm / 80 kg ≈ 2.00 m²', () {
      final pd = PatientData()..height = 180..weight = 80;
      expect(pd.bsa, closeTo(1.996, 0.01));
    });

    test('Kleine Person 160 cm / 60 kg ≈ 1.62 m²', () {
      final pd = PatientData()..height = 160..weight = 60;
      expect(pd.bsa, closeTo(1.622, 0.01));
    });

    test('Fehlende Größe liefert 0 (kein Ergebnis statt NaN)', () {
      final pd = PatientData()..weight = 70;
      expect(pd.bsa, 0);
    });

    test('Fehlendes Gewicht liefert 0', () {
      final pd = PatientData()..height = 175;
      expect(pd.bsa, 0);
    });

    test('Negative Werte werden abgelehnt', () {
      final pd = PatientData()..height = -175..weight = 70;
      expect(pd.bsa, 0);
    });

    test('Extreme Werte werden abgelehnt (Overflow-Schutz)', () {
      final pd = PatientData()..height = 9999..weight = 9999;
      expect(pd.bsa, 0);
    });
  });

  group('Cardiac Output', () {
    // CO = BSA × CI    (Default CI = 2.4 l/min/m²)
    // Quelle: Gorlin R, Gorlin SG. Am Heart J 1951; 41: 1-29.

    test('CO = BSA × CI bei Default-CI 2.4', () {
      final pd = PatientData()..height = 175..weight = 70;
      // BSA = 1.848, CI = 2.4 → CO = 4.44
      expect(pd.cardiacOutput, closeTo(4.435, 0.02));
    });

    test('Benutzerdefiniertes CI überschreibt Default', () {
      final pd = PatientData()
        ..height = 175
        ..weight = 70
        ..bsaCardiacIndex = 3.0;
      expect(pd.cardiacOutput, closeTo(1.848 * 3.0, 0.02));
    });
  });

  group('Blood Volume (Silbernagl & Despopoulos)', () {
    // ♂: BV = 0.041 × kg + 1.53 L
    // ♀: BV = 0.047 × kg + 0.86 L

    test('Mann 70 kg = 4.40 L', () {
      final pd = PatientData()..weight = 70;
      expect(pd.bloodVolumeMale, closeTo(4.40, 0.001));
    });

    test('Frau 60 kg = 3.68 L', () {
      final pd = PatientData()..weight = 60;
      expect(pd.bloodVolumeFemale, closeTo(3.68, 0.001));
    });
  });

  group('Expected Hb/Hct nach Priming', () {
    // Expected Hb: Hb × (1 - priming_ml / (weight_kg × 100))
    // Expected Hct (Nadler 1962): Hct × BV / (BV + priming)

    test('Hb 14 g/dl, 1500 ml Priming, 70 kg → Hb 11.0', () {
      final pd = PatientData()
        ..currentHb = 14
        ..primingVolume = 1500
        ..weight = 70;
      expect(pd.expectedHb, closeTo(11.0, 0.01));
    });

    test('Hct 42%, 1500 ml Priming, 70 kg Mann → ~31.32%', () {
      final pd = PatientData()
        ..currentHct = 42
        ..primingVolume = 1500
        ..weight = 70;
      // BV_male = 4.40 L = 4400 ml; 42 × 4400 / (4400 + 1500) = 31.32
      expect(pd.expectedHctMale, closeTo(31.32, 0.02));
    });

    test('Ohne Priming (= 0 ml) bleibt Hb unverändert', () {
      final pd = PatientData()
        ..currentHb = 14
        ..primingVolume = 0
        ..weight = 70;
      expect(pd.expectedHb, closeTo(14.0, 0.001));
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // Sauerstofftransport (Hüfner 1884, Ranucci 2005)
  // ════════════════════════════════════════════════════════════════════════
  group('CaO2 / CvO2 (Hüfner)', () {
    // CaO2 = Hb × 1.34 × SaO2/100 + PaO2 × 0.0031
    // Hüfner-Konstante 1.34 (ml O2 pro g Hb)

    test('CaO2 bei Normalbefund (Hb 14, SaO2 99%, PaO2 95) ≈ 18.87', () {
      final pd = PatientData()
        ..artHb = 14
        ..saO2 = 99
        ..paO2 = 95;
      expect(pd.caO2, closeTo(18.87, 0.01));
    });

    test('CvO2 gemischt-venös (Hb 14, SvO2 75%, PvO2 40) ≈ 14.19', () {
      final pd = PatientData()
        ..venHb = 14
        ..svO2 = 75
        ..pvO2 = 40;
      expect(pd.cvO2, closeTo(14.19, 0.01));
    });

    test('Ca-vDO2 Differenz', () {
      final pd = PatientData()
        ..artHb = 14..saO2 = 99..paO2 = 95
        ..venHb = 14..svO2 = 75..pvO2 = 40;
      // 18.87 - 14.19 ≈ 4.67
      expect(pd.cavDO2, closeTo(4.67, 0.02));
    });
  });

  group('DO2 / DO2i / VO2 / O2-ER', () {
    // DO2   = CaO2 × CO × 10
    // DO2i  = CaO2 × CI × 10     (Ranucci-Schwelle 272 ml/min/m²)
    // VO2   = Ca-vDO2 × CO × 10
    // O2-ER = VO2 / DO2 × 100

    test('DO2 (CaO2 18.87, CO 5 l/min) ≈ 943', () {
      final pd = PatientData()
        ..artHb = 14..saO2 = 99..paO2 = 95
        ..hzv = 5;
      expect(pd.do2, closeTo(943.35, 0.5));
    });

    test('DO2i bei CI 2.4 und Normalbefund ≈ 453', () {
      final pd = PatientData()
        ..artHb = 14..saO2 = 99..paO2 = 95
        ..cardiacIndex = 2.4;
      expect(pd.do2i, closeTo(452.81, 0.5));
      // Weit über Ranucci-Schwelle 272 → kein kritischer Bereich
      expect(pd.do2i, greaterThan(272));
    });

    test('O2-ER im Normalbereich (~25%)', () {
      final pd = PatientData()
        ..artHb = 14..saO2 = 99..paO2 = 95
        ..venHb = 14..svO2 = 75..pvO2 = 40
        ..hzv = 5;
      // cavDO2 / CaO2 × 100 = 4.673 / 18.867 × 100 ≈ 24.77
      // Normalbereich laut Literatur 22-30%.
      expect(pd.o2er, closeTo(24.77, 0.1));
    });

    test('Min. CO für DO2i = 272 bei BSA 1.85 und CaO2 18.87 ≈ 2.67', () {
      final pd = PatientData()
        ..artHb = 14..saO2 = 99..paO2 = 95
        ..kof = 1.85;
      expect(pd.minCardiacOutput, closeTo(2.667, 0.02));
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // Gefäßwiderstände
  // ════════════════════════════════════════════════════════════════════════
  group('SVR / PVR', () {
    // SVR = (MAP - CVP) / CO × 80
    // PVR = (PAP - LAP) / CO × 80
    // Einheit: dyn·s·cm⁻⁵, Faktor 80 konvertiert von mmHg/l/min.

    test('SVR bei MAP 80, CVP 5, CO 5 = 1200', () {
      final pd = PatientData()..map = 80..cvp = 5..hzvRes = 5;
      expect(pd.svr, closeTo(1200, 0.1));
    });

    test('PVR bei PAP 20, LAP 10, CO 5 = 160', () {
      final pd = PatientData()..pap = 20..lap = 10..hzvPvr = 5;
      expect(pd.pvr, closeTo(160, 0.1));
    });

    test('CO = 0 liefert 0 (Division durch 0 abgefangen)', () {
      final pd = PatientData()..map = 80..cvp = 5..hzvRes = 0;
      expect(pd.svr, 0);
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // Elektrolyte / Puffer
  // ════════════════════════════════════════════════════════════════════════
  group('Elektrolyt-Bedarf', () {
    // Alle: (Soll - Ist) × BW × 0.2 / Faktor
    // Faktor Na = 1.71, K = 1.0, Ca = 0.225

    test('Na-Bedarf (Soll 130, Ist 120, 70 kg) ≈ 81.87 ml', () {
      final pd = PatientData()
        ..natriumSoll = 130
        ..natriumIst = 120
        ..bodyWeightElec = 70;
      expect(pd.natriumBedarf, closeTo(81.87, 0.01));
    });

    test('K-Bedarf (Soll 4.8, Ist 3.0, 70 kg) = 25.2 ml', () {
      final pd = PatientData()
        ..kaliumSoll = 4.8
        ..kaliumIst = 3.0
        ..bodyWeightElec = 70;
      expect(pd.kaliumBedarf, closeTo(25.2, 0.01));
    });

    test('Ca-Bedarf (Soll 1.2, Ist 0.8, 70 kg) ≈ 24.89 ml', () {
      final pd = PatientData()
        ..calziumSoll = 1.2
        ..calziumIst = 0.8
        ..bodyWeightElec = 70;
      expect(pd.calziumBedarf, closeTo(24.89, 0.01));
    });
  });

  group('Puffer (NaBic / TRIS)', () {
    // NaBic 8.4%: BE × BW × 3 / (-10)
    // TRIS 36.34%: BE × BW / (-10)

    test('NaBic bei BE -10, 70 kg = 210 ml', () {
      final pd = PatientData()..baseExcess = -10..bodyWeightElec = 70;
      expect(pd.nabic, closeTo(210, 0.01));
    });

    test('TRIS bei BE -10, 70 kg = 70 ml', () {
      final pd = PatientData()..baseExcess = -10..bodyWeightElec = 70;
      expect(pd.tris, closeTo(70, 0.01));
    });

    test('Positiver BE liefert negative Menge (keine Puffergabe)', () {
      final pd = PatientData()..baseExcess = 5..bodyWeightElec = 70;
      expect(pd.nabic, lessThan(0));
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // Schlauchvolumen (Größen in Zoll)
  // ════════════════════════════════════════════════════════════════════════
  group('Tube Volumes', () {
    // Koeffizienten: ml pro cm Länge für übliche HLM-Schlauchgrößen.
    // 1/2" = 1.2668, 3/8" = 0.7126, 1/4" = 0.3167, 3/16" = 0.1781

    test('100 cm 1/2-Zoll Schlauch = 126.68 ml', () {
      final pd = PatientData()..tubeLength = 100;
      expect(pd.tubeVol12, closeTo(126.68, 0.01));
    });

    test('100 cm 3/8-Zoll Schlauch = 71.26 ml', () {
      final pd = PatientData()..tubeLength = 100;
      expect(pd.tubeVol38, closeTo(71.26, 0.01));
    });

    test('100 cm 1/4-Zoll Schlauch = 31.67 ml', () {
      final pd = PatientData()..tubeLength = 100;
      expect(pd.tubeVol14, closeTo(31.67, 0.01));
    });

    test('100 cm 3/16-Zoll Schlauch = 17.81 ml', () {
      final pd = PatientData()..tubeLength = 100;
      expect(pd.tubeVol316, closeTo(17.81, 0.01));
    });

    test('Tube length null → 0 ml', () {
      final pd = PatientData();
      expect(pd.tubeVol12, 0);
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // Charrière / Zoll
  // ════════════════════════════════════════════════════════════════════════
  group('Charrière-Umrechnung', () {
    // 1 Ch = 1/3 mm (international definiert).

    test('18 Ch = 6.00 mm', () {
      final pd = PatientData()..chInput = 18;
      expect(pd.chToMm, closeTo(6.0, 0.001));
    });

    test('6 mm = 18 Ch', () {
      final pd = PatientData()..mmInput = 6;
      expect(pd.mmToCh, closeTo(18.0, 0.001));
    });

    test('Round-Trip: Ch → mm → Ch', () {
      final pd1 = PatientData()..chInput = 24;
      final mm = pd1.chToMm;
      final pd2 = PatientData()..mmInput = mm;
      expect(pd2.mmToCh, closeTo(24, 0.001));
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // Pädiatrische Transfusion
  // ════════════════════════════════════════════════════════════════════════
  group('Pädiatrische Transfusion', () {
    // Volumen = kg × ΔHb × 3 / (55 × 0.01)

    test('15 kg, ΔHb +3 → ca. 245 ml Erythrozytenkonzentrat', () {
      final pd = PatientData()
        ..pediatricWeight = 15
        ..desiredHbIncrease = 3;
      expect(pd.transfusionVolume, closeTo(245.45, 0.02));
    });

    test('Kein Gewicht → 0', () {
      final pd = PatientData()..desiredHbIncrease = 3;
      expect(pd.transfusionVolume, 0);
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // Kantentests: NaN, Infinity, Divisions-durch-Null
  // ════════════════════════════════════════════════════════════════════════
  group('Sicherheit gegen Grenzwerte', () {
    test('Leere PatientData liefert für alle Formeln 0 (keine Crashes)', () {
      final pd = PatientData();
      // Ein kleiner Parcours durch alle Hauptformeln:
      expect(pd.bsa, 0);
      expect(pd.cardiacOutput, 0);
      expect(pd.bloodVolumeMale, 0);
      expect(pd.expectedHb, 0);
      expect(pd.caO2, 0);
      expect(pd.do2, 0);
      expect(pd.svr, 0);
      expect(pd.pvr, 0);
      expect(pd.natriumBedarf, 0);
      expect(pd.tubeVol12, 0);
      expect(pd.transfusionVolume, 0);
    });

    test('Kein Ergebnis ist NaN', () {
      // Test mit Grenzwerten, die mathematisch zu NaN/Inf führen könnten.
      final pd = PatientData()
        ..height = 175..weight = 70
        ..artHb = 0..saO2 = 0..paO2 = 0
        ..cardiacIndex = 0..hzv = 0..kof = 0;
      expect(pd.bsa.isNaN, false);
      expect(pd.caO2.isNaN, false);
      expect(pd.do2.isNaN, false);
      expect(pd.o2er.isNaN, false);
      expect(pd.minCardiacOutput.isNaN, false);
    });
  });
}
