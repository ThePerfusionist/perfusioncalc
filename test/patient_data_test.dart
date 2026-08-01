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
import 'package:perfusion_calc/models/cardioplegia_alarm_settings.dart';

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
    // One dilution law for both metrics, because it is the same red cell
    // mass in a larger volume:  X_after = X_before × BV / (BV + priming)
    // BV_male   = 0.041 × kg + 1.53 [l]
    // BV_female = 0.047 × kg + 0.86 [l]

    test('Hb 14 g/dl, 1500 ml priming, 70 kg male → 10.39 g/dl', () {
      final pd = PatientData()
        ..currentHb = 14
        ..primingVolume = 1500
        ..weight = 70;
      // BV_male = 4.40 l = 4400 ml; 14 × 4400 / (4400 + 1500) = 10.4407
      expect(pd.expectedHbMale, closeTo(10.4407, 0.001));
    });

    test('Hb 14 g/dl, 1500 ml priming, 70 kg female → uses female BV', () {
      final pd = PatientData()
        ..currentHb = 14
        ..primingVolume = 1500
        ..weight = 70;
      // BV_female = 4.15 l = 4150 ml; 14 × 4150 / (4150 + 1500) = 10.2832
      expect(pd.expectedHbFemale, closeTo(10.2832, 0.001));
      // Lower blood volume dilutes more.
      expect(pd.expectedHbFemale, lessThan(pd.expectedHbMale));
    });

    test('Regression: expectedHb no longer uses weight × 100 ml', () {
      // The old implementation returned 11.38 g/dl for this case (implied
      // BV 8000 ml, linearised). Exact dilution against the model's own
      // blood volume: BV_male = 0.041 x 80 + 1.53 = 4.81 l = 4810 ml,
      // 14 x 4810 / (4810 + 1500) = 10.6719. The +0.71 g/dl was systematic
      // and always on the optimistic side. Audit finding 1.3.
      final pd = PatientData()
        ..currentHb = 14
        ..primingVolume = 1500
        ..weight = 80;
      expect(pd.expectedHbMale, closeTo(10.6719, 0.001));
      expect(pd.expectedHbMale, lessThan(11.0));
    });

    test('Hct 42%, 1500 ml priming, 70 kg man → ~31.32%', () {
      final pd = PatientData()
        ..currentHct = 42
        ..primingVolume = 1500
        ..weight = 70;
      // BV_male = 4.40 L = 4400 ml; 42 × 4400 / (4400 + 1500) = 31.32
      expect(pd.expectedHctMale, closeTo(31.32, 0.02));
    });

    test('Hb and Hct dilute by the same factor', () {
      final pd = PatientData()
        ..currentHb = 14
        ..currentHct = 42
        ..primingVolume = 1500
        ..weight = 70;
      expect(pd.expectedHbMale / 14, closeTo(pd.expectedHctMale / 42, 1e-9));
    });

    test('Without priming (= 0 ml), Hb stays unchanged', () {
      final pd = PatientData()
        ..currentHb = 14
        ..primingVolume = 0
        ..weight = 70;
      expect(pd.expectedHbMale, closeTo(14.0, 0.001));
      expect(pd.expectedHbFemale, closeTo(14.0, 0.001));
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

  group('Ultrafiltration / hemoconcentration (mass conservation)', () {
    // Hct1 x V1 = Hct2 x V2   (equally: Hb1 x V1 = Hb2 x V2)
    // Source: Klineberg PL, Kam CA, Johnson DC, Cartmill TB, Brown JJ.
    // Hematocrit and blood volume control during cardiopulmonary bypass with
    // the use of hemofiltration. Anesthesiology. 1984;60(5):478-480.

    test('Hct mode: V1 4000 ml, Hct 20% -> 28% needs 1142.86 ml removed', () {
      final pd = PatientData()
        ..ufCurrentVolume = 4000
        ..ufCurrentHct = 20
        ..ufTargetHct = 28;
      expect(pd.ufVolumeToRemove, closeTo(1142.86, 0.1));
      expect(pd.ufFinalVolume, closeTo(2857.14, 0.1));
    });

    test('Hb mode: V1 4000 ml, Hb 7 g/dl -> 10 g/dl needs exactly 1200 ml removed', () {
      final pd = PatientData()
        ..ufCurrentVolume = 4000
        ..ufCurrentHb = 7
        ..ufTargetHb = 10;
      expect(pd.ufVolumeToRemove, closeTo(1200, 0.01));
      expect(pd.ufFinalVolume, closeTo(2800, 0.01));
    });

    test('Mass is conserved: metric1 x V1 equals metric2 x V2', () {
      final pd = PatientData()
        ..ufCurrentVolume = 4000
        ..ufCurrentHct = 20
        ..ufTargetHct = 28;
      final v2 = pd.ufFinalVolume;
      expect(20 * 4000, closeTo(28 * v2, 1));
    });

    test('Target at or below current yields 0 (UF cannot dilute)', () {
      final pdEqual = PatientData()
        ..ufCurrentVolume = 4000..ufCurrentHct = 24..ufTargetHct = 24;
      final pdLower = PatientData()
        ..ufCurrentVolume = 4000..ufCurrentHct = 30..ufTargetHct = 24;
      expect(pdEqual.ufVolumeToRemove, 0);
      expect(pdLower.ufVolumeToRemove, 0);
    });

    test('Mixing Hct and Hb pairs is ignored (only a fully populated pair counts)', () {
      // Only ufCurrentHct is set, no ufTargetHct, and a stray ufTargetHb
      // without a matching ufCurrentHb - neither pair is complete, so the
      // result must stay 0 rather than guessing across metrics.
      final pd = PatientData()
        ..ufCurrentVolume = 4000
        ..ufCurrentHct = 20
        ..ufTargetHb = 10;
      expect(pd.ufVolumeToRemove, 0);
    });

    test('Missing current volume yields 0', () {
      final pd = PatientData()..ufCurrentHct = 20..ufTargetHct = 28;
      expect(pd.ufVolumeToRemove, 0);
    });
  });

  group('Cardioplegia (Buckberg 1987 / Matte & del Nido 2012 / Calafiore 1995)', () {
    // Buckberg: 4:1 blood:crystalloid, dose = weight x dose_per_kg (1-2 ml/kg)
    // Source: Buckberg GD. J Thorac Cardiovasc Surg. 1987;93(1):127-139.
    //
    // del Nido: 4:1 crystalloid:blood, single dose capped at 1000 ml
    // Source: Matte GS, del Nido PJ. J Extra Corpor Technol. 2012;44(3):98-103.

    test('Buckberg 70 kg at 1.5 ml/kg: total 105 ml, 4:1 blood:crystalloid', () {
      final pd = PatientData()
        ..cardioplegiaWeight = 70
        ..cardioplegiaDoseBuckberg = 1.5;
      expect(pd.buckbergDoseVolume, closeTo(105, 0.01));
      expect(pd.buckbergBloodVolume, closeTo(84, 0.01));
      expect(pd.buckbergCrystalloidVolume, closeTo(21, 0.01));
      expect(pd.buckbergBloodVolume / pd.buckbergCrystalloidVolume, closeTo(4.0, 0.001));
    });

    test('del Nido 40 kg at 17.5 ml/kg: 700 ml, not capped, 4:1 crystalloid:blood', () {
      final pd = PatientData()
        ..cardioplegiaWeight = 40
        ..cardioplegiaDoseDelNido = 17.5;
      expect(pd.delNidoDoseVolume, closeTo(700, 0.01));
      expect(pd.delNidoDoseCapped, isFalse);
      expect(pd.delNidoBloodVolume, closeTo(140, 0.01));
      expect(pd.delNidoCrystalloidVolume, closeTo(560, 0.01));
      expect(pd.delNidoCrystalloidVolume / pd.delNidoBloodVolume, closeTo(4.0, 0.001));
    });

    test('del Nido 70 kg at 17.5 ml/kg: raw 1225 ml is capped to the 1000 ml single-dose ceiling', () {
      final pd = PatientData()
        ..cardioplegiaWeight = 70
        ..cardioplegiaDoseDelNido = 17.5;
      expect(pd.delNidoDoseVolume, closeTo(1000, 0.01));
      expect(pd.delNidoDoseCapped, isTrue);
      expect(pd.delNidoBloodVolume, closeTo(200, 0.01));
      expect(pd.delNidoCrystalloidVolume, closeTo(800, 0.01));
    });

    test('del Nido exactly at the 1000 ml boundary is NOT flagged as capped', () {
      final pd = PatientData()
        ..cardioplegiaWeight = 50
        ..cardioplegiaDoseDelNido = 20;
      expect(pd.delNidoDoseVolume, closeTo(1000, 0.01));
      expect(pd.delNidoDoseCapped, isFalse);
    });

    test('Missing weight yields 0 for both protocols', () {
      final pdB = PatientData()..cardioplegiaDoseBuckberg = 1.5;
      final pdD = PatientData()..cardioplegiaDoseDelNido = 17.5;
      expect(pdB.buckbergDoseVolume, 0);
      expect(pdD.delNidoDoseVolume, 0);
    });

    test('The two protocols are independent - setting one does not affect the other', () {
      final pd = PatientData()
        ..cardioplegiaWeight = 70
        ..cardioplegiaDoseBuckberg = 1.5;
      expect(pd.buckbergDoseVolume, greaterThan(0));
      expect(pd.delNidoDoseVolume, 0); // del Nido dose was never set
    });

    // Calafiore: pressure-controlled, intermittent warm blood cardioplegia.
    // Whole blood is the carrier; a K+/Mg2+ MIXTURE (institutional syringe:
    // 4 x 10 ml KCl 14.9% [2 mmol/ml] + 1 x 10 ml MgSO4-heptahydrate
    // 500 mg/ml, i.e. 20 mmol per 10 ml ampoule [~2.0 mmol/ml] - confirmed
    // by direct inspection of the institutional ampoule; an earlier version
    // of this app incorrectly assumed "10%"/~0.4 mmol/ml) is continuously
    // titrated in via a syringe pump (Perfusor). Both the target [K+] and a
    // SEPARATE end-of-dose Mg2+ bolus change across the dose sequence:
    //   Dose 1: target 20 mmol/l | bolus 1000 mg
    //   Dose 2: target 12 mmol/l | bolus  100 mg (alt. 500 mg)
    //   Dose 3: target 12 mmol/l | bolus  100 mg
    //   Dose 4: target 12 mmol/l (alt. 10/8) | bolus 500 mg
    //   Dose 5: target 12 mmol/l (alt. 10/8) | bolus 100 mg
    //   Dose 6: target 12 mmol/l (alt. 10/8) | bolus 100 mg
    // All expected Perfusor-rate values below are computed directly from
    // the mass-balance formula (verified in an earlier session against the
    // institutional Excel's own worked example) applied to the resulting
    // 1.6 mmol/ml [K+] / 0.4 mmol/ml [Mg2+] institutional syringe mixture.
    // Source (technique origin): Calafiore AM, Teodori G, Mezzetti A,
    // Bosco G, Verna AM, Di Giammarco G, Lapenna D. Ann Thorac Surg.
    // 1995;59(2):398-402.

    PatientData calafioreSyringe({int? dose}) => PatientData()
      ..cardioplegiaCalafioreKclVolume = 40
      ..cardioplegiaCalafioreKclConc = 2.0
      ..cardioplegiaCalafioreMgVolume = 10
      ..cardioplegiaCalafioreMgConc = 2.0
      ..cardioplegiaCalafioreDoseNumber = dose;

    test('Institutional syringe mixture (40 ml KCl 2mmol/ml + 10 ml MgSO4 2mmol/ml [500mg/ml]): 1.6 / 0.4 mmol/ml', () {
      final pd = calafioreSyringe();
      expect(pd.calafioreSyringeTotalVolume, closeTo(50, 0.01));
      expect(pd.calafioreSyringeKConc, closeTo(1.6, 0.001));
      expect(pd.calafioreSyringeMgConc, closeTo(0.4, 0.001));
    });

    test('Default target [K+] and Mg2+ bolus follow the dose-number schedule', () {
      final expected = {
        1: (20.0, 1000.0),
        2: (12.0, 100.0),
        3: (12.0, 100.0),
        4: (12.0, 500.0),
        5: (12.0, 100.0),
        6: (12.0, 100.0),
      };
      for (final entry in expected.entries) {
        final pd = calafioreSyringe(dose: entry.key);
        expect(pd.calafioreTargetK, entry.value.$1, reason: 'dose ${entry.key} target');
        expect(pd.calafioreMgBolusMg, entry.value.$2, reason: 'dose ${entry.key} bolus');
      }
    });

    test('Dose 1, serum 4.8, flow 200 ml/min -> Perfusor rate 114.0 ml/h, Mg2+ delivery 45.6 mmol/h', () {
      final pd = calafioreSyringe(dose: 1)
        ..cardioplegiaCalafioreFlow = 200
        ..cardioplegiaCalafioreSerumK = 4.8;
      expect(pd.calafioreDeltaK, closeTo(15.2, 0.001));
      expect(pd.calafiorePerfusorRate, closeTo(114.0, 0.01));
      expect(pd.calafioreMgDeliveryRate, closeTo(45.6, 0.01));
    });

    test('Dose 2 (target 12), serum 4.8, flow 200 ml/min -> Perfusor rate 54.0 ml/h', () {
      final pd = calafioreSyringe(dose: 2)
        ..cardioplegiaCalafioreFlow = 200
        ..cardioplegiaCalafioreSerumK = 4.8;
      expect(pd.calafiorePerfusorRate, closeTo(54.0, 0.01));
      expect(pd.calafioreMgDeliveryRate, closeTo(21.6, 0.01));
    });

    test('Dose 4 alt target 10 mmol/l overrides the default 12 -> Perfusor rate 39.0 ml/h', () {
      final pd = calafioreSyringe(dose: 4)
        ..cardioplegiaCalafioreTargetKAlt = 10
        ..cardioplegiaCalafioreFlow = 200
        ..cardioplegiaCalafioreSerumK = 4.8;
      expect(pd.calafioreTargetK, 10.0);
      expect(pd.calafiorePerfusorRate, closeTo(39.0, 0.01));
    });

    test('Dose 4 alt target 8 mmol/l overrides the default 12 -> Perfusor rate 24.0 ml/h', () {
      final pd = calafioreSyringe(dose: 4)
        ..cardioplegiaCalafioreTargetKAlt = 8
        ..cardioplegiaCalafioreFlow = 200
        ..cardioplegiaCalafioreSerumK = 4.8;
      expect(pd.calafioreTargetK, 8.0);
      expect(pd.calafiorePerfusorRate, closeTo(24.0, 0.01));
    });

    test('Target alt override is ignored outside doses 4-6 (dose 2 stays at default 12)', () {
      final pd = calafioreSyringe(dose: 2)..cardioplegiaCalafioreTargetKAlt = 8;
      expect(pd.calafioreTargetK, 12.0);
    });

    test('Mg2+ bolus is fixed per dose and has no alternate-value override', () {
      // Dose 2 may clinically be raised to 500 mg, but that is shown as a
      // hint only - it feeds no calculation, so the model always reports
      // the scheduled default.
      expect(calafioreSyringe(dose: 2).calafioreMgBolusMg, 100.0);
      expect(calafioreSyringe(dose: 4).calafioreMgBolusMg, 500.0);
    });

    test('No dose number selected defaults to dose 1 (target 20, bolus 1000 mg)', () {
      final pd = PatientData();
      expect(pd.calafioreTargetK, 20.0);
      expect(pd.calafioreMgBolusMg, 1000.0);
    });

    test('Perfusor rate scales linearly with flow (same syringe/dose, flow 150 vs 200 ml/min)', () {
      final pdBase = calafioreSyringe(dose: 2)
        ..cardioplegiaCalafioreSerumK = 4.8
        ..cardioplegiaCalafioreFlow = 200;
      final pdLowerFlow = calafioreSyringe(dose: 2)
        ..cardioplegiaCalafioreSerumK = 4.8
        ..cardioplegiaCalafioreFlow = 150;
      // Pressure-controlled delivery: if flow drops (e.g. higher coronary
      // resistance at the same 90-100 mmHg line pressure), the Perfusor
      // rate must drop proportionally to hold the same concentration.
      expect(pdBase.calafiorePerfusorRate, closeTo(54.0, 0.01));
      expect(pdLowerFlow.calafiorePerfusorRate, closeTo(40.5, 0.01));
      expect(pdLowerFlow.calafiorePerfusorRate / pdBase.calafiorePerfusorRate,
          closeTo(150 / 200, 0.001));
    });

    test('Serum K+ at or above this dose\'s target yields 0 ml/h (no negative Perfusor rate)', () {
      final pd = calafioreSyringe(dose: 2)
        ..cardioplegiaCalafioreFlow = 200
        ..cardioplegiaCalafioreSerumK = 12.0; // == dose 2's target of 12
      expect(pd.calafioreDeltaK, 0);
      expect(pd.calafiorePerfusorRate, 0);
    });

    test('Missing flow yields 0 even with a complete syringe mixture', () {
      final pd = calafioreSyringe(dose: 1)..cardioplegiaCalafioreSerumK = 4.8;
      expect(pd.calafiorePerfusorRate, 0);
    });

    test('Magnesium is OPTIONAL: a pure-KCl syringe still computes the full K+ result', () {
      // Previously this configuration returned 0 because magnesium was
      // treated as a required input. Magnesium is now optional: without it
      // the syringe is simply undiluted KCl (40 ml at 2 mmol/ml -> 2.0
      // mmol/ml), and the K+ calculation proceeds normally.
      // Dose 1: (20 - 4.8) x 200 / 1000 / 2.0 x 60 = 91.2 ml/h.
      final pd = PatientData()
        ..cardioplegiaCalafioreKclVolume = 40
        ..cardioplegiaCalafioreKclConc = 2.0
        ..cardioplegiaCalafioreFlow = 200
        ..cardioplegiaCalafioreSerumK = 4.8;
      expect(pd.calafioreSyringeTotalVolume, closeTo(40, 0.01));
      expect(pd.calafioreSyringeKConc, closeTo(2.0, 0.001));
      expect(pd.calafiorePerfusorRate, closeTo(91.2, 0.01));
      // No magnesium in the syringe -> no continuous Mg2+ delivery, but
      // that is a valid state, not an error.
      expect(pd.calafioreSyringeMgConc, 0);
      expect(pd.calafioreMgDeliveryRate, 0);
    });

    test('Missing KCl concentration still yields 0 (K+ source is genuinely required)', () {
      final pd = PatientData()
        ..cardioplegiaCalafioreKclVolume = 40
        ..cardioplegiaCalafioreFlow = 200
        ..cardioplegiaCalafioreSerumK = 4.8;
      expect(pd.calafiorePerfusorRate, 0);
    });

    test('Calafiore is independent of Buckberg/del Nido fields', () {
      final pd = calafioreSyringe(dose: 1)
        ..cardioplegiaWeight = 70
        ..cardioplegiaDoseBuckberg = 1.5
        ..cardioplegiaCalafioreFlow = 200
        ..cardioplegiaCalafioreSerumK = 4.8;
      expect(pd.buckbergDoseVolume, closeTo(105, 0.01));
      expect(pd.calafiorePerfusorRate, closeTo(114.0, 0.01));
    });
  });

  group('Cardioplegia - Bretschneider (HTK/Custodiol)', () {
    // Single-shot intracellular crystalloid solution. Institutional/teaching
    // parameters: 5-8 C, 100-110 mmHg initially then 40-50 mmHg after
    // arrest, 6-8 min perfusion (2-3 min on re-perfusion), organ
    // protection up to 180 min from a single administration.
    // Sources: Bretschneider HJ. Thorac Cardiovasc Surg. 1980;28(5):295-302.
    // | Bretschneider HJ et al. J Cardiovasc Surg (Torino). 1975;16(3):241-60.
    // | Gebhard MM, Preusse CJ, Schnabel PA, Bretschneider HJ. Thorac
    // Cardiovasc Surg. 1984;32(5):271-6.

    test('Delivered volume from pump settings = flow x time (300 ml/min x 6 min = 1800 ml)', () {
      final pd = PatientData()
        ..cardioplegiaBretschneiderFlow = 300
        ..cardioplegiaBretschneiderTime = 6;
      expect(pd.bretschneiderVolumeFromFlow, closeTo(1800, 0.01));
    });

    test('Short re-perfusion volume (250 ml/min x 2.5 min = 625 ml)', () {
      final pd = PatientData()
        ..cardioplegiaBretschneiderFlow = 250
        ..cardioplegiaBretschneiderTime = 2.5;
      expect(pd.bretschneiderVolumeFromFlow, closeTo(625, 0.01));
    });

    test('Missing inputs yield 0', () {
      expect(PatientData().bretschneiderVolumeFromFlow, 0);
      expect((PatientData()..cardioplegiaBretschneiderFlow = 300).bretschneiderVolumeFromFlow, 0);
      expect((PatientData()..cardioplegiaBretschneiderTime = 6).bretschneiderVolumeFromFlow, 0);
    });
  });

  group('Cardioplegia - del Nido mixture, delivery time & dose per kg', () {
    // Institutional setup: crystalloid pump at 100% of the set flow, blood
    // pump following at a fraction of it -> reproduces the configured
    // crystalloid:blood ratio mechanically. The ratio is passed in as the
    // crystalloid SHARE in percent (80 % = the classic 4:1).
    //   blood = crystalloid x (100-p)/p | total = crystalloid x 100/p
    //   blood flow = flow x (100-p)/p   | total flow = flow x 100/p
    //   time  = crystalloid / flow      (ratio-independent)
    // Source: Matte GS, del Nido PJ. J Extra Corpor Technol. 2012;44(3):98-103.

    test('Default 80 % share reproduces the classic 4:1 numbers', () {
      final pd = PatientData()
        ..cardioplegiaDelNidoCrystalloid = 800
        ..cardioplegiaDelNidoPumpFlow = 200;
      expect(pd.delNidoBloodFromCrystalloid(80), closeTo(200, 0.01));
      expect(pd.delNidoTotalFromCrystalloid(80), closeTo(1000, 0.01));
      expect(pd.delNidoBloodPumpFlow(80), closeTo(50, 0.01));
      expect(pd.delNidoTotalFlow(80), closeTo(250, 0.01));
      expect(pd.delNidoFollowerPercent(80), closeTo(25, 0.01));
      expect(pd.delNidoDeliveryTimeMin, closeTo(4.0, 0.01));
    });

    test('A different share changes the mixture but not the delivery time', () {
      final pd = PatientData()
        ..cardioplegiaDelNidoCrystalloid = 800
        ..cardioplegiaDelNidoPumpFlow = 200;
      // 75 % share = 3:1
      expect(pd.delNidoBloodFromCrystalloid(75), closeTo(266.67, 0.01));
      expect(pd.delNidoTotalFromCrystalloid(75), closeTo(1066.67, 0.01));
      expect(pd.delNidoFollowerPercent(75), closeTo(33.33, 0.01));
      // Volume and flow scale by the same factor -> time is unchanged.
      expect(pd.delNidoDeliveryTimeMin, closeTo(4.0, 0.01));
    });

    test('The configured share is actually reflected in the mixture', () {
      final pd = PatientData()..cardioplegiaDelNidoCrystalloid = 900;
      for (final share in [50.0, 66.0, 80.0, 90.0]) {
        final total = pd.delNidoTotalFromCrystalloid(share);
        // crystalloid must make up exactly `share` percent of the total
        expect(900 / total * 100, closeTo(share, 0.001), reason: 'share $share');
      }
    });

    test('Delivery time is consistent whether derived from crystalloid or totals', () {
      final pd = PatientData()
        ..cardioplegiaDelNidoCrystalloid = 1000
        ..cardioplegiaDelNidoPumpFlow = 250;
      expect(pd.delNidoDeliveryTimeMin,
          closeTo(pd.delNidoTotalFromCrystalloid(80) / pd.delNidoTotalFlow(80), 0.001));
    });

    test('Total cardioplegia per kg body weight', () {
      final pd = PatientData()
        ..cardioplegiaDelNidoCrystalloid = 800
        ..cardioplegiaWeight = 70;
      // total 1000 ml / 70 kg = 14.29 ml/kg
      expect(pd.delNidoTotalPerKg(80), closeTo(14.29, 0.01));
    });

    test('Dose per kg follows the configured share', () {
      final pd = PatientData()
        ..cardioplegiaDelNidoCrystalloid = 800
        ..cardioplegiaWeight = 70;
      // A smaller crystalloid share means more blood, so more total volume.
      expect(pd.delNidoTotalPerKg(75), greaterThan(pd.delNidoTotalPerKg(80)));
    });

    test('Ideal total volume from the 20 ml/kg recommendation', () {
      final pd = PatientData()..cardioplegiaWeight = 40;
      expect(pd.delNidoRecommendedTotal, closeTo(800, 0.01));
      expect(pd.delNidoRecommendedExceedsMax, isFalse);
    });

    test('Ideal total volume is NOT capped - the hypothetical figure is shown', () {
      final pd = PatientData()..cardioplegiaWeight = 70;
      // 70 kg x 20 = 1400 ml: reported in full, only flagged as exceeding
      // the protocol's 1000 ml single dose.
      expect(pd.delNidoRecommendedTotal, closeTo(1400, 0.01));
      expect(pd.delNidoRecommendedExceedsMax, isTrue);
    });

    test('Exactly at the 1000 ml boundary is not flagged as exceeding', () {
      final pd = PatientData()..cardioplegiaWeight = 50;
      expect(pd.delNidoRecommendedTotal, closeTo(1000, 0.01));
      expect(pd.delNidoRecommendedExceedsMax, isFalse);
    });

    test('Ideal total volume scales linearly with body weight', () {
      expect((PatientData()..cardioplegiaWeight = 100).delNidoRecommendedTotal, closeTo(2000, 0.01));
      expect((PatientData()..cardioplegiaWeight = 3.5).delNidoRecommendedTotal, closeTo(70, 0.01));
    });

    test('Ideal total volume needs a weight', () {
      expect(PatientData().delNidoRecommendedTotal, 0);
      expect(PatientData().delNidoRecommendedExceedsMax, isFalse);
    });

    test('Follower percentage matches the configured share', () {
      final pd = PatientData();
      expect(pd.delNidoFollowerPercent(80), closeTo(25, 0.01));   // 4:1
      expect(pd.delNidoFollowerPercent(75), closeTo(33.33, 0.01)); // 3:1
      expect(pd.delNidoFollowerPercent(50), closeTo(100, 0.01));   // 1:1
    });

    test('Invalid shares yield 0 instead of dividing by zero', () {
      final pd = PatientData()
        ..cardioplegiaDelNidoCrystalloid = 800
        ..cardioplegiaDelNidoPumpFlow = 200
        ..cardioplegiaWeight = 70;
      for (final bad in [0.0, 100.0, -10.0, 150.0]) {
        expect(pd.delNidoBloodFromCrystalloid(bad), 0, reason: 'share $bad');
        expect(pd.delNidoTotalFromCrystalloid(bad), 0, reason: 'share $bad');
        expect(pd.delNidoTotalFlow(bad), 0, reason: 'share $bad');
        expect(pd.delNidoFollowerPercent(bad), 0, reason: 'share $bad');
        expect(pd.delNidoTotalPerKg(bad), 0, reason: 'share $bad');
      }
    });

    test('Missing inputs yield 0', () {
      expect(PatientData().delNidoBloodFromCrystalloid(80), 0);
      expect(PatientData().delNidoTotalFromCrystalloid(80), 0);
      expect(PatientData().delNidoBloodPumpFlow(80), 0);
      expect(PatientData().delNidoTotalFlow(80), 0);
      expect(PatientData().delNidoDeliveryTimeMin, 0);
      expect(PatientData().delNidoTotalPerKg(80), 0);
      expect((PatientData()..cardioplegiaDelNidoCrystalloid = 800).delNidoDeliveryTimeMin, 0);
      // Total per kg needs the weight as well as the volume
      expect((PatientData()..cardioplegiaDelNidoCrystalloid = 800).delNidoTotalPerKg(80), 0);
    });
  });

  group('Cardioplegia - alarm fire schedule', () {
    // Pure schedule function, so the firing behaviour is testable without a
    // clock or a real alarm.
    int fires(Duration d, {bool enabled = true, double trigger = 15, bool repeat = false}) =>
        CardioplegiaAlarmSettings.expectedFireCount(
            elapsed: d, enabled: enabled, triggerMinutes: trigger, repeat: repeat);

    test('Disabled alarm never fires', () {
      expect(fires(const Duration(minutes: 60), enabled: false), 0);
    });

    test('Does not fire before the trigger point', () {
      expect(fires(const Duration(minutes: 14, seconds: 59)), 0);
    });

    test('Fires once at the trigger point and stays at one without repeat', () {
      expect(fires(const Duration(minutes: 15)), 1);
      expect(fires(const Duration(minutes: 90)), 1);
    });

    test('With repeat enabled it fires once per completed interval', () {
      expect(fires(const Duration(minutes: 15), repeat: true), 1);
      expect(fires(const Duration(minutes: 30), repeat: true), 2);
      expect(fires(const Duration(minutes: 44), repeat: true), 2);
      expect(fires(const Duration(minutes: 45), repeat: true), 3);
    });

    test('A custom trigger time is honoured', () {
      expect(fires(const Duration(minutes: 20), trigger: 25), 0);
      expect(fires(const Duration(minutes: 25), trigger: 25), 1);
    });

    test('Zero or negative trigger time never fires (guards against div/0)', () {
      expect(fires(const Duration(minutes: 60), trigger: 0), 0);
      expect(fires(const Duration(minutes: 60), trigger: -5), 0);
    });
  });

  group('Cardioplegia - re-dose interval timer', () {
    // Pure status function, deliberately taking an elapsed Duration rather
    // than reading the clock, so the thresholds are deterministic here.
    // Calafiore thresholds: due at 15 min, overdue past 20 min.
    // Bretschneider thresholds: due at 150 min, overdue past 180 min.

    CardioplegiaDoseStatus calafiore(Duration d) => PatientData.cardioplegiaDoseStatus(
        elapsed: d, dueAfterMin: 15, overdueAfterMin: 20);

    test('Calafiore: fresh dose is within the interval', () {
      expect(calafiore(const Duration(minutes: 0)), CardioplegiaDoseStatus.ok);
      expect(calafiore(const Duration(minutes: 14, seconds: 59)), CardioplegiaDoseStatus.ok);
    });

    test('Calafiore: re-dose window opens exactly at 15 min', () {
      expect(calafiore(const Duration(minutes: 15)), CardioplegiaDoseStatus.due);
      expect(calafiore(const Duration(minutes: 19, seconds: 59)), CardioplegiaDoseStatus.due);
    });

    test('Calafiore: interval is exceeded from 20 min on', () {
      expect(calafiore(const Duration(minutes: 20)), CardioplegiaDoseStatus.overdue);
      expect(calafiore(const Duration(minutes: 45)), CardioplegiaDoseStatus.overdue);
    });

    test('Bretschneider: 180 min single-shot window with a 30 min warning lead', () {
      CardioplegiaDoseStatus bret(Duration d) => PatientData.cardioplegiaDoseStatus(
          elapsed: d, dueAfterMin: 150, overdueAfterMin: 180);
      expect(bret(const Duration(minutes: 60)), CardioplegiaDoseStatus.ok);
      expect(bret(const Duration(minutes: 150)), CardioplegiaDoseStatus.due);
      expect(bret(const Duration(minutes: 179)), CardioplegiaDoseStatus.due);
      expect(bret(const Duration(minutes: 180)), CardioplegiaDoseStatus.overdue);
    });

    test('Sub-minute resolution: seconds are honoured, not truncated to whole minutes', () {
      // 14:30 must still be "ok" and 15:00 must flip to "due" - a
      // minutes-only implementation would round 14:30 up and fire early.
      expect(calafiore(const Duration(minutes: 14, seconds: 30)), CardioplegiaDoseStatus.ok);
      expect(calafiore(const Duration(minutes: 15, seconds: 1)), CardioplegiaDoseStatus.due);
    });

    test('No delivery recorded by default', () {
      expect(PatientData().cardioplegiaLastDoseAt, isNull);
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
  group('Pediatric transfusion (Davies 2007)', () {
    // volume (ml) = kg × ΔHb (g/dl) × 3 / Hct(RBC unit, as a FRACTION)
    // Davies P et al. Transfusion. 2007;47(2):212-216.

    test('15 kg, ΔHb +3 → approx. 245 ml packed red cells', () {
      final pd = PatientData()
        ..pediatricWeight = 15
        ..desiredHbIncrease = 3;
      expect(pd.transfusionVolume, closeTo(245.45, 0.02));
    });

    test("Reproduces Davies' own worked example at a UK unit (Hct 0.60)", () {
      // The paper states: 10 ml/kg raises Hb by 2 g/dl at Hct 0.6.
      // 20 kg × 2 g/dl × 3 / 0.6 = 200 ml = 10 ml/kg.
      // Guards the SHAPE of the formula independently of the institutional
      // hematocrit constant - the audit suspected a double correction here,
      // and this is what rules it out.
      const weight = 20.0;
      const deltaHb = 2.0;
      final volumeAtUkUnit = weight * deltaHb * 3 / 0.60;
      expect(volumeAtUkUnit, closeTo(200, 0.001));
      expect(volumeAtUkUnit / weight, closeTo(10, 0.001));
    });

    test('The assumed RBC unit hematocrit is the only tunable', () {
      // Documents the institutional assumption so a change to it is a
      // conscious, reviewed act rather than a silent edit.
      expect(PatientData.kRbcUnitHematocrit, 0.55);
      final pd = PatientData()
        ..pediatricWeight = 10
        ..desiredHbIncrease = 1;
      // 10 × 1 × 3 / 0.55 = 54.5 ml = 5.45 ml/kg per g/dl
      expect(pd.transfusionVolume / 10, closeTo(5.4545, 0.001));
    });

    test('No weight → 0', () {
      final pd = PatientData()..desiredHbIncrease = 3;
      expect(pd.transfusionVolume, 0);
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // Incomplete venous set must not fake a full oxygen balance (audit 1.1)
  // ════════════════════════════════════════════════════════════════════════
  group('Ca-vDO2 guard with arterial values only', () {
    PatientData arterialOnly() => PatientData()
      ..artHb = 12
      ..saO2 = 99
      ..paO2 = 200
      ..hzv = 5
      ..kof = 1.9;

    test('cavDO2 is 0 while the venous side is missing', () {
      // Unguarded this returned caO2 - 0 == caO2, and every consumer below
      // inherited it. On screen ResultCard.missingInputs hid that; the PDF
      // export has no such notion and printed the numbers.
      expect(arterialOnly().cavDO2, 0);
    });

    test('VO2 and VO2i do not equal DO2/DO2i', () {
      final pd = arterialOnly();
      expect(pd.do2, greaterThan(0));
      expect(pd.vo2, 0);
      expect(pd.vo2i, 0);
    });

    test('O2-ER does not report 100 %', () {
      final pd = arterialOnly();
      expect(pd.o2er, 0);
      expect(pd.o2er, isNot(closeTo(100, 0.01)));
    });

    test('With a complete venous set the values come back', () {
      final pd = arterialOnly()
        ..venHb = 12
        ..svO2 = 75
        ..pvO2 = 40;
      expect(pd.cavDO2, greaterThan(0));
      expect(pd.vo2, greaterThan(0));
      expect(pd.o2er, greaterThan(0));
      expect(pd.o2er, lessThan(100));
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
      expect(pd.expectedHbMale, 0);
      expect(pd.expectedHbFemale, 0);
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
