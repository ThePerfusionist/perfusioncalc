// Physiological normal ranges for plausibility checking
// =========================================================
// These values are used ONLY for gentle warnings in the UI.
// The actual calculations still accept values outside these ranges
// (e.g. to deliberately work through extreme cases in training).
//
// Sources for the ranges:
//   Herold G. Innere Medizin. 2023. Adult standard values.
//   Silbernagl & Despopoulos, Physiologie-Taschenatlas. 9th ed. 2018.
//   Kasper DL et al. Harrison's Principles of Internal Medicine. 20th ed.
//
// The ranges are deliberately WIDE: not "normal range for a healthy
// 25-year-old", but "plausible value range for a real patient in a
// cardiac surgery context". An Hb of 7 g/dl is not normal, but it is
// plausible (anemic patient); an Hb of 50 g/dl, on the other hand,
// is never plausible (typo).

/// A clinically plausible value range for an input field.
/// Values outside it are flagged in the UI as a warning (yellow border),
/// but do not stop the calculation.
class Range {
  final double min;
  final double max;
  final String unit;

  /// i18n key of an optional hint shown in the plausibility tooltip.
  ///
  /// A key, not a finished string: these notes used to be German literals
  /// that warnTooltipFor() appended to an otherwise translated tooltip, so
  /// an English user got a mixed-language message.
  final String? noteKey;

  const Range(this.min, this.max, this.unit, {this.noteKey});

  /// true if the value is within the plausible range.
  /// null values count as "not entered" and therefore not implausible.
  bool contains(double? v) {
    if (v == null) return true;
    return v >= min && v <= max;
  }

  /// For tooltip display: "5–20 g/dl".
  ///
  /// Whole numbers print without a decimal tail - Range(30, 230, 'cm')
  /// rendered as "30.0–230.0 cm" before, and that string appears in every
  /// plausibility tooltip.
  static String _n(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  String get display => '${_n(min)}–${_n(max)} $unit';
}

/// Central collection of all normal ranges, grouped by clinical context.
/// To adjust, just change the values here — the UI picks them up immediately.
class Ranges {
  // ── Anthropometry ────────────────────────────────────────────────────────
  static const height = Range(30, 230, 'cm',
      noteKey: 'range_note_height');
  static const weight = Range(0.5, 300, 'kg',
      noteKey: 'range_note_weight');
  static const pediatricWeight = Range(0.5, 50, 'kg',
      noteKey: 'range_note_pediatric_weight');
  static const bsa = Range(0.1, 3.5, 'm²',
      noteKey: 'range_note_bsa');

  // ── Hematology ───────────────────────────────────────────────────────────
  static const hb = Range(4, 22, 'g/dl',
      noteKey: 'range_note_hb');
  static const hct = Range(10, 65, '%',
      noteKey: 'range_note_hct');
  static const primingVolume = Range(0, 3000, 'ml',
      noteKey: 'range_note_priming_volume');
  static const circulatingVolume = Range(300, 8000, 'ml',
      noteKey: 'range_note_circulating_volume');

  // ── Oxygen transport ─────────────────────────────────────────────────────
  static const paO2 = Range(20, 600, 'mmHg',
      noteKey: 'range_note_pa_o2');
  static const pvO2 = Range(10, 80, 'mmHg',
      noteKey: 'range_note_pv_o2');
  static const saO2 = Range(50, 100, '%',
      noteKey: 'range_note_sa_o2');
  static const svO2 = Range(30, 90, '%',
      noteKey: 'range_note_sv_o2');

  // ── Hemodynamics ─────────────────────────────────────────────────────────
  static const co = Range(0.5, 12, 'l/min',
      noteKey: 'range_note_co');
  static const ci = Range(0.5, 6.0, 'l/min/m²',
      noteKey: 'range_note_ci');
  static const map = Range(30, 180, 'mmHg',
      noteKey: 'range_note_map');
  static const cvp = Range(-5, 30, 'mmHg',
      noteKey: 'range_note_cvp');
  static const pap = Range(5, 80, 'mmHg',
      noteKey: 'range_note_pap');
  static const lap = Range(0, 30, 'mmHg',
      noteKey: 'range_note_lap');

  // ── Electrolytes / blood gas ─────────────────────────────────────────────
  static const natrium = Range(110, 160, 'mmol/l',
      noteKey: 'range_note_natrium');
  static const kalium = Range(1.5, 8.0, 'mmol/l',
      noteKey: 'range_note_kalium');
  static const calzium = Range(0.3, 2.0, 'mmol/l',
      noteKey: 'range_note_calzium');
  static const baseExcess = Range(-30, 30, 'mmol/l',
      noteKey: 'range_note_base_excess');
  static const pH = Range(6.8, 7.8, '',
      noteKey: 'range_note_ph');
  static const temperature = Range(15, 42, '°C',
      noteKey: 'range_note_temperature');

  // ── Tube length ──────────────────────────────────────────────────────────
  static const tubeLength = Range(10, 500, 'cm',
      noteKey: 'range_note_tube_length');

  // ── Charrière ────────────────────────────────────────────────────────────
  static const ch = Range(1, 40, 'Ch');
  static const mm = Range(0.3, 15, 'mm');

  // ── Pediatrics ───────────────────────────────────────────────────────────
  /// Hematocrit of a red cell concentrate. German products in additive
  /// solution are specified at 50-70 %; the band here is a little wider so
  /// unusual products can still be entered.
  static const rbcUnitHematocrit = Range(40, 80, '%',
      noteKey: 'range_note_rbc_unit_hematocrit');

  static const desiredHbIncrease = Range(0.5, 8, 'g/dl',
      noteKey: 'range_note_desired_hb_increase');

  // ── Cardioplegia ─────────────────────────────────────────────────────────
  static const cardioplegiaDoseBuckberg = Range(1, 2, 'ml/kg',
      noteKey: 'range_note_cardioplegia_dose_buckberg');
  static const cardioplegiaDoseDelNido = Range(15, 20, 'ml/kg',
      noteKey: 'range_note_cardioplegia_dose_del_nido');
  static const cardioplegiaDelNidoCrystalloid = Range(100, 1600, 'ml',
      noteKey: 'range_note_cardioplegia_del_nido_crystalloid');
  static const cardioplegiaDelNidoPumpFlow = Range(50, 600, 'ml/min',
      noteKey: 'range_note_cardioplegia_del_nido_pump_flow');
  static const cardioplegiaDelNidoCrystPercent = Range(50, 95, '%',
      noteKey: 'range_note_cardioplegia_del_nido_cryst_percent');
  static const cardioplegiaCalafioreFlow = Range(50, 500, 'ml/min',
      noteKey: 'range_note_cardioplegia_calafiore_flow');
  static const cardioplegiaCalafioreKclVolume = Range(5, 100, 'ml',
      noteKey: 'range_note_cardioplegia_calafiore_kcl_volume');
  static const cardioplegiaCalafioreMgVolume = Range(0, 50, 'ml',
      noteKey: 'range_note_cardioplegia_calafiore_mg_volume');
  static const cardioplegiaCalafioreKclConc = Range(0.5, 3, 'mmol/ml',
      noteKey: 'range_note_cardioplegia_calafiore_kcl_conc');
  static const cardioplegiaCalafioreKclConcPercent = Range(3.5, 22.5, '%',
      noteKey: 'range_note_cardioplegia_calafiore_kcl_conc_percent');
  static const cardioplegiaCalafioreMgConc = Range(0.5, 3, 'mmol/ml',
      noteKey: 'range_note_cardioplegia_calafiore_mg_conc');
  static const cardioplegiaCalafioreMgConcPercent = Range(10, 60, '%',
      noteKey: 'range_note_cardioplegia_calafiore_mg_conc_percent');

  // ── Bretschneider (HTK/Custodiol) ────────────────────────────────────────
  static const cardioplegiaBretschneiderFlow = Range(50, 600, 'ml/min',
      noteKey: 'range_note_cardioplegia_bretschneider_flow');
  static const cardioplegiaBretschneiderTime = Range(2, 8, 'min',
      noteKey: 'range_note_cardioplegia_bretschneider_time');
}
