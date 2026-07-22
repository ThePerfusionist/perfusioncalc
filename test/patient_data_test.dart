// Unit tests for PerfusionCalc formulas
// =====================================
//
// Goal: every clinical formula in PatientData has at least one test case
// with a known reference value from the primary literature.
//
// Run automatically on every push via the GitHub Actions workflow.
//
// On failure: either a formula was changed incorrectly, or the test case
// itself is wrong. Either way: LOOK INTO IT, don't just adjust it.
//
// Tolerances: closeTo() with epsilon 0.01 (two decimal places) is enough
// for most clinical values. For saturations (S-shaped curve) we use 0.5%.

import 'package:flutter_test/flutter_test.dart';
import 'package:perfusion_calc/models/patient_data.dart';

void main() {
  // ════════════════════════════════════════════════════════════════════════
  // BSA, Cardiac Output, Blood Volume
  // ════════════════════════════════════════════════════════════════════════
  group('BSA (DuBois 1916)', () {
    // Formula: BSA = 0.007184 × H^0.725 × W^0.425
    // Source: DuBois D, DuBois EF. Arch Intern Med 1916; 17: 863-871.

    test('Reference adult 175 cm / 70 kg ≈ 1.85 m²', () {
      final pd = PatientData()..height = 175..weight = 70;
      expect(pd.bsa, closeTo(1.848, 0.01));
    });

    test('Large man 180 cm / 80 kg ≈ 2.00 m²', () {
      final pd = PatientData()..height = 180..weight = 80;
      expect(pd.bsa, closeTo(1.996, 0.01));
    });

    test('Small person 160 cm / 60 kg ≈ 1.62 m²', () {
      final pd = PatientData()..height = 160..weight = 60;
      expect(pd.bsa, closeTo(1.622, 0.01));
    });

    test('Missing height yields 0 (no result instead of NaN)', () {
      final pd = PatientData()..weight = 70;
      expect(pd.bsa, 0);
    });

    test('Missing weight yields 0', () {
      final pd = PatientData()..height = 175;
      expect(pd.bsa, 0);
    });

    test('Negative values are rejected', () {
      final pd = PatientData()..height = -175..weight = 70;
      expect(pd.bsa, 0);
    });

    test('Extreme values are rejected (overflow protection)', () {
      final pd = PatientData()..height = 9999..weight = 9999;
      expect(pd.bsa, 0);
    });
  });

  group('Cardiac Output', () {
    // CO = BSA × CI    (default CI = 2.4 l/min/m²)
    // Source: 2024 EACTS/EACTAIC/EBCP Guidelines on cardiopulmonary bypass.
    // Kunst G et al. Br J Anaesth. 2025;134(4):917–1008.

    test('CO = BSA × CI with default CI 2.4', () {
      final pd = PatientData()..height = 175..weight = 70;
      // BSA = 1.848, CI = 2.4 → CO = 4.44
      expect(pd.cardiacOutput, closeTo(4.435, 0.02));
    });

    test('Custom CI overrides the default', () {
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

    test('Man 70 kg = 4.40 L', () {
      final pd = PatientData()..weight = 70;
      expect(pd.bloodVolumeMale, closeTo(4.40, 0.001));
    });

    test('Woman 60 kg = 3.68 L', () {
      final pd = PatientData()..weight = 60;
      expect(pd.bloodVolumeFemale, closeTo(3.68, 0.001));
    });

    test('Sanity check against the Nadler 1962 gold-standard formula (175 cm / 70 kg man)', () {
      // The app deliberately uses a simplified, weight-based approximation
      // (Silbernagl/Despopoulos) instead of the full Nadler regression
      // formula (which additionally factors in height). Nadler SB, Hidalgo
      // JH, Bloch T. Surgery. 1962;51(2):224-232:
      //   BV_male = 0.3669 × h[m]³ + 0.03219 × w[kg] + 0.6041
      // For 175 cm / 70 kg: 0.3669×1.75³ + 0.03219×70 + 0.6041 ≈ 4.824 L
      // vs. the simplified formula here: 4.40 L (≈ 8.8% lower).
      // This test ensures the simplified approximation doesn't accidentally
      // drift far from the clinical gold standard (e.g. due to a typo in a
      // coefficient) - 15% tolerance band, since both formulas are
      // deliberately different and aren't meant to be identical.
      const nadlerBV = 0.3669 * 1.75 * 1.75 * 1.75 + 0.03219 * 70 + 0.6041;
      final pd = PatientData()..height = 175..weight = 70;
      expect(pd.bloodVolumeMale, closeTo(nadlerBV, nadlerBV * 0.15));
    });
  });

  group('Expected Hb/Hct after priming', () {
    // Expected Hb: Hb × (1 - priming_ml / (weight_kg × 100))
    // Expected Hct (Nadler 1962): Hct × BV / (BV + priming)

    test('Hb 14 g/dl, 1500 ml priming, 70 kg → Hb 11.0', () {
      final pd = PatientData()
        ..currentHb = 14
        ..primingVolume = 1500
        ..weight = 70;
      expect(pd.expectedHb, closeTo(11.0, 0.01));
    });

    test('Hct 42%, 1500 ml priming, 70 kg man → ~31.32%', () {
      final pd = PatientData()
        ..currentHct = 42
        ..primingVolume = 1500
        ..weight = 70;
      // BV_male = 4.40 L = 4400 ml; 42 × 4400 / (4400 + 1500) = 31.32
      expect(pd.expectedHctMale, closeTo(31.32, 0.02));
    });

    test('Without priming (= 0 ml), Hb stays unchanged', () {
      final pd = PatientData()
        ..currentHb = 14
        ..primingVolume = 0
        ..weight = 70;
      expect(pd.expectedHb, closeTo(14.0, 0.001));
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // Oxygen transport (Hüfner 1894, Ranucci 2005)
  // ════════════════════════════════════════════════════════════════════════
  group('CaO2 / CvO2 (Hüfner)', () {
    // CaO2 = Hb × 1.34 × SaO2/100 + PaO2 × 0.0031
    // Hüfner constant 1.34 (ml O2 per g Hb)

    test('CaO2 for a normal finding (Hb 14, SaO2 99%, PaO2 95) ≈ 18.87', () {
      final pd = PatientData()
        ..artHb = 14
        ..saO2 = 99
        ..paO2 = 95;
      expect(pd.caO2, closeTo(18.87, 0.01));
    });

    test('CvO2 mixed-venous (Hb 14, SvO2 75%, PvO2 40) ≈ 14.19', () {
      final pd = PatientData()
        ..venHb = 14
        ..svO2 = 75
        ..pvO2 = 40;
      expect(pd.cvO2, closeTo(14.19, 0.01));
    });

    test('Ca-vDO2 difference', () {
      final pd = PatientData()
        ..artHb = 14..saO2 = 99..paO2 = 95
        ..venHb = 14..svO2 = 75..pvO2 = 40;
      // 18.87 - 14.19 ≈ 4.67
      expect(pd.cavDO2, closeTo(4.67, 0.02));
    });
  });

  group('DO2 / DO2i / VO2 / O2 ER', () {
    // DO2   = CaO2 × CO × 10
    // DO2i  = CaO2 × CI × 10     (Ranucci threshold 272 ml/min/m²)
    // VO2   = Ca-vDO2 × CO × 10
    // O2 ER = VO2 / DO2 × 100

    test('DO2 (CaO2 18.87, CO 5 l/min) ≈ 943', () {
      final pd = PatientData()
        ..artHb = 14..saO2 = 99..paO2 = 95
        ..hzv = 5;
      expect(pd.do2, closeTo(943.35, 0.5));
    });

    test('DO2i at CI 2.4 with a normal finding ≈ 453', () {
      final pd = PatientData()
        ..artHb = 14..saO2 = 99..paO2 = 95
        ..cardiacIndex = 2.4;
      expect(pd.do2i, closeTo(452.81, 0.5));
      // Well above the Ranucci threshold of 272 → not a critical range
      expect(pd.do2i, greaterThan(272));
    });

    test('Ranucci 2005 threshold: DO2i just above/below 272 ml/min/m² is distinguished correctly', () {
      // Source: Ranucci M et al. Ann Thorac Surg. 2005;80(6):2213-2220.
      // n=1048 CABG patients; ROC cutoff for acute kidney injury at
      // 272 mL·min⁻¹·m⁻². Independently confirmed multiple times (among
      // others de Somer 2011: ~262; Newland 2019, ANZCPR registry
      // n=19410). This test does not check the threshold itself (that
      // lives in main.dart/ResultCard as a UI warning, not in the model),
      // but that DO2i is calculated correctly and stably just above and
      // just below the published cutoff - regression protection for the
      // GDP warning hint on the O2 tab.
      final justBelow = PatientData()
        ..artHb = 8.5..saO2 = 93..paO2 = 75..cardiacIndex = 2.4;
      final justAbove = PatientData()
        ..artHb = 9.0..saO2 = 93..paO2 = 75..cardiacIndex = 2.4;
      // Both cases differ only by 0.5 g/dl Hb:
      // Hb 8.5 → DO2i ≈ 259.8 (below the threshold)
      // Hb 9.0 → DO2i ≈ 274.8 (above the threshold)
      expect(justBelow.do2i, lessThan(272));
      expect(justAbove.do2i, greaterThan(272));
    });

    test('O2 ER in the normal range (~25%)', () {
      final pd = PatientData()
        ..artHb = 14..saO2 = 99..paO2 = 95
        ..venHb = 14..svO2 = 75..pvO2 = 40
        ..hzv = 5;
      // cavDO2 / CaO2 × 100 = 4.673 / 18.867 × 100 ≈ 24.77
      // Normal range per the literature is 22-30%.
      expect(pd.o2er, closeTo(24.77, 0.1));
    });

    test('Min. CO for DO2i = 272 at BSA 1.85 and CaO2 18.87 ≈ 2.67', () {
      final pd = PatientData()
        ..artHb = 14..saO2 = 99..paO2 = 95
        ..kof = 1.85;
      expect(pd.minCardiacOutput, closeTo(2.667, 0.02));
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // Vascular resistances
  // ════════════════════════════════════════════════════════════════════════
  group('SVR / PVR', () {
    // SVR = (MAP - CVP) / CO × 80
    // PVR = (PAP - LAP) / CO × 80
    // Unit: dyn·s·cm⁻⁵, factor 80 converts from mmHg/l/min.

    test('SVR at MAP 80, CVP 5, CO 5 = 1200', () {
      final pd = PatientData()..map = 80..cvp = 5..hzvRes = 5;
      expect(pd.svr, closeTo(1200, 0.1));
    });

    test('PVR at PAP 20, LAP 10, CO 5 = 160', () {
      final pd = PatientData()..pap = 20..lap = 10..hzvPvr = 5;
      expect(pd.pvr, closeTo(160, 0.1));
    });

    test('CO = 0 yields 0 (division by zero caught)', () {
      final pd = PatientData()..map = 80..cvp = 5..hzvRes = 0;
      expect(pd.svr, 0);
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // Electrolytes / buffers
  // ════════════════════════════════════════════════════════════════════════
  group('Electrolyte requirement', () {
    // All: (target - current) × BW × 0.2 / factor
    // Factor Na = 1.71, K = 1.0, Ca = 0.225

    test('Na requirement (target 130, current 120, 70 kg) ≈ 81.87 ml', () {
      final pd = PatientData()
        ..natriumSoll = 130
        ..natriumIst = 120
        ..bodyWeightElec = 70;
      expect(pd.natriumBedarf, closeTo(81.87, 0.01));
    });

    test('K requirement (target 4.8, current 3.0, 70 kg) = 25.2 ml', () {
      final pd = PatientData()
        ..kaliumSoll = 4.8
        ..kaliumIst = 3.0
        ..bodyWeightElec = 70;
      expect(pd.kaliumBedarf, closeTo(25.2, 0.01));
    });

    test('Ca requirement (target 1.2, current 0.8, 70 kg) ≈ 24.89 ml', () {
      final pd = PatientData()
        ..calziumSoll = 1.2
        ..calziumIst = 0.8
        ..bodyWeightElec = 70;
      expect(pd.calziumBedarf, closeTo(24.89, 0.01));
    });
  });

  group('Buffer (NaBic / TRIS)', () {
    // NaBic 8.4%: BE × BW × 3 / (-10)
    // TRIS 36.34%: BE × BW / (-10)

    test('NaBic at BE -10, 70 kg = 210 ml', () {
      final pd = PatientData()..baseExcess = -10..bodyWeightElec = 70;
      expect(pd.nabic, closeTo(210, 0.01));
    });

    test('TRIS at BE -10, 70 kg = 70 ml', () {
      final pd = PatientData()..baseExcess = -10..bodyWeightElec = 70;
      expect(pd.tris, closeTo(70, 0.01));
    });

    test('Positive BE yields a negative amount (no buffer administration)', () {
      final pd = PatientData()..baseExcess = 5..bodyWeightElec = 70;
      expect(pd.nabic, lessThan(0));
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // Tube volume (sizes in inches)
  // ════════════════════════════════════════════════════════════════════════
  group('Tube Volumes', () {
    // Coefficients: ml per cm of length for common CPB tube sizes.
    // 1/2" = 1.2668, 3/8" = 0.7126, 1/4" = 0.3167, 3/16" = 0.1781

    test('100 cm 1/2-inch tube = 126.68 ml', () {
      final pd = PatientData()..tubeLength = 100;
      expect(pd.tubeVol12, closeTo(126.68, 0.01));
    });

    test('100 cm 3/8-inch tube = 71.26 ml', () {
      final pd = PatientData()..tubeLength = 100;
      expect(pd.tubeVol38, closeTo(71.26, 0.01));
    });

    test('100 cm 1/4-inch tube = 31.67 ml', () {
      final pd = PatientData()..tubeLength = 100;
      expect(pd.tubeVol14, closeTo(31.67, 0.01));
    });

    test('100 cm 3/16-inch tube = 17.81 ml', () {
      final pd = PatientData()..tubeLength = 100;
      expect(pd.tubeVol316, closeTo(17.81, 0.01));
    });

    test('Tube length null → 0 ml', () {
      final pd = PatientData();
      expect(pd.tubeVol12, 0);
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // Charrière / French
  // ════════════════════════════════════════════════════════════════════════
  group('Charrière conversion', () {
    // 1 Ch = 1/3 mm (internationally defined).

    test('18 Ch = 6.00 mm', () {
      final pd = PatientData()..chInput = 18;
      expect(pd.chToMm, closeTo(6.0, 0.001));
    });

    test('6 mm = 18 Ch', () {
      final pd = PatientData()..mmInput = 6;
      expect(pd.mmToCh, closeTo(18.0, 0.001));
    });

    test('Round trip: Ch → mm → Ch', () {
      final pd1 = PatientData()..chInput = 24;
      final mm = pd1.chToMm;
      final pd2 = PatientData()..mmInput = mm;
      expect(pd2.mmToCh, closeTo(24, 0.001));
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // Pediatric transfusion
  // ════════════════════════════════════════════════════════════════════════
  group('Pediatric transfusion', () {
    // Volume = kg × ΔHb × 3 / (55 × 0.01)

    test('15 kg, ΔHb +3 → approx. 245 ml packed red cells', () {
      final pd = PatientData()
        ..pediatricWeight = 15
        ..desiredHbIncrease = 3;
      expect(pd.transfusionVolume, closeTo(245.45, 0.02));
    });

    test('No weight → 0', () {
      final pd = PatientData()..desiredHbIncrease = 3;
      expect(pd.transfusionVolume, 0);
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // Edge-case tests: NaN, Infinity, division by zero
  // ════════════════════════════════════════════════════════════════════════
  group('Safety against edge values', () {
    test('Empty PatientData yields 0 for all formulas (no crashes)', () {
      final pd = PatientData();
      // A quick run through all the main formulas:
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

    test('No result is NaN', () {
      // Test with boundary values that could mathematically lead to NaN/Inf.
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
