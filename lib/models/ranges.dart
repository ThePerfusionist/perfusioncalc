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
  final String? note; // optional hint text shown in the tooltip
  const Range(this.min, this.max, this.unit, {this.note});

  /// true if the value is within the plausible range.
  /// null values count as "not entered" and therefore not implausible.
  bool contains(double? v) {
    if (v == null) return true;
    return v >= min && v <= max;
  }

  /// For tooltip display: "5–20 g/dl"
  String get display => '$min–$max $unit';
}

/// Central collection of all normal ranges, grouped by clinical context.
/// To adjust, just change the values here — the UI picks them up immediately.
class Ranges {
  // ── Anthropometry ────────────────────────────────────────────────────────
  static const height = Range(30, 230, 'cm',
      note: 'Körpergröße Säuglinge bis Riesenwuchs');
  static const weight = Range(0.5, 300, 'kg',
      note: 'Neugeborene bis adipositas permagna');
  static const pediatricWeight = Range(0.5, 50, 'kg',
      note: 'Pädiatrischer Bereich');
  static const bsa = Range(0.1, 3.5, 'm²',
      note: 'Säugling bis sehr großer Erwachsener');

  // ── Hematology ───────────────────────────────────────────────────────────
  static const hb = Range(4, 22, 'g/dl',
      note: 'Schwere Anämie bis Polyglobulie');
  static const hct = Range(10, 65, '%',
      note: 'Schwere Anämie bis Polyglobulie');
  static const primingVolume = Range(0, 3000, 'ml',
      note: 'Typisch 1200–1800 ml Adult, 300–600 ml Pädiatrie');
  static const circulatingVolume = Range(300, 8000, 'ml',
      note: 'Patientenblutvolumen + Priming, pädiatrisch bis adult');

  // ── Oxygen transport ─────────────────────────────────────────────────────
  static const paO2 = Range(20, 600, 'mmHg',
      note: 'Hypoxämie bis 100% O2-Beatmung');
  static const pvO2 = Range(10, 80, 'mmHg',
      note: 'Gemischt-venös typisch 35–45');
  static const saO2 = Range(50, 100, '%',
      note: 'Schwere Hypoxämie bis Normalbefund');
  static const svO2 = Range(30, 90, '%',
      note: 'Normal 65–75%, kritisch <50%');

  // ── Hemodynamics ─────────────────────────────────────────────────────────
  static const co = Range(0.5, 12, 'l/min',
      note: 'Schock bis Hyperdynamie');
  static const ci = Range(0.5, 6.0, 'l/min/m²',
      note: 'Normal 2.5–4.0');
  static const map = Range(30, 180, 'mmHg',
      note: 'Normal 70–100');
  static const cvp = Range(-5, 30, 'mmHg',
      note: 'Normal 2–8');
  static const pap = Range(5, 80, 'mmHg',
      note: 'Normal systolisch 15–30');
  static const lap = Range(0, 30, 'mmHg',
      note: 'Normal 6–12');

  // ── Electrolytes / blood gas ─────────────────────────────────────────────
  static const natrium = Range(110, 160, 'mmol/l',
      note: 'Normal 135–145');
  static const kalium = Range(1.5, 8.0, 'mmol/l',
      note: 'Normal 3.5–5.0');
  static const calzium = Range(0.3, 2.0, 'mmol/l',
      note: 'Ionisiertes Ca, Normal 1.1–1.3');
  static const baseExcess = Range(-30, 30, 'mmol/l',
      note: 'Normal ±2');
  static const pH = Range(6.8, 7.8, '',
      note: 'Normal 7.35–7.45');
  static const temperature = Range(15, 42, '°C',
      note: 'Tiefe Hypothermie bis Hyperthermie');

  // ── Tube length ──────────────────────────────────────────────────────────
  static const tubeLength = Range(10, 500, 'cm',
      note: 'Übliche Längen HLM-Schlauchsysteme');

  // ── Charrière ────────────────────────────────────────────────────────────
  static const ch = Range(1, 40, 'Ch');
  static const mm = Range(0.3, 15, 'mm');

  // ── Pediatrics ───────────────────────────────────────────────────────────
  static const desiredHbIncrease = Range(0.5, 8, 'g/dl',
      note: 'Üblicher Ziel-Hb-Anstieg');

  // ── Cardioplegia ─────────────────────────────────────────────────────────
  static const cardioplegiaDoseBuckberg = Range(1, 2, 'ml/kg',
      note: 'Induktions-/Erhaltungsdosis nach Buckberg 1987');
  static const cardioplegiaDoseDelNido = Range(15, 20, 'ml/kg',
      note: 'Einzeldosis nach Matte & del Nido 2012, max. 1000 ml');
  static const cardioplegiaCalafioreFlow = Range(50, 500, 'ml/min',
      note: 'Druckgesteuert (z.B. 90–100 mmHg); flusskontrolliertes Referenzprotokoll 200–300 ml/min');
  static const cardioplegiaCalafioreKclVolume = Range(5, 100, 'ml',
      note: 'Institutionelles Beispiel: 40 ml KCl 14,9 % (4 Ampullen à 10 ml)');
  static const cardioplegiaCalafioreMgVolume = Range(0, 50, 'ml',
      note: 'Optional. Institutionelles Beispiel: 10 ml MgSO4 (1 Ampulle à 10 ml)');
  static const cardioplegiaCalafioreKclConc = Range(0.5, 3, 'mmol/ml',
      note: 'KCl 14,9 % entspricht 2 mmol/ml');
  static const cardioplegiaCalafioreKclConcPercent = Range(3.5, 22.5, '%',
      note: 'KCl 14,9 % (Standard) entspricht 2 mmol/ml');
  static const cardioplegiaCalafioreMgConc = Range(0.5, 3, 'mmol/ml',
      note: '500 mg/ml MgSO4-Heptahydrat entspricht 20 mmol pro 10-ml-Ampulle (≈2,0 mmol/ml)');
  static const cardioplegiaCalafioreMgConcPercent = Range(10, 60, '%',
      note: '500 mg/ml MgSO4-Heptahydrat entspricht ca. 50 % (w/v)');

  // ── Bretschneider (HTK/Custodiol) ────────────────────────────────────────
  static const cardioplegiaBretschneiderFlow = Range(50, 600, 'ml/min',
      note: 'Druckgesteuert: initial 100–110 mmHg, nach Herzstillstand 40–50 mmHg');
  static const cardioplegiaBretschneiderTimeInitial = Range(6, 8, 'min',
      note: 'Erstperfusion (Induktion) 6–8 min');
  static const cardioplegiaBretschneiderTimeReperfusion = Range(2, 3, 'min',
      note: 'Nachperfusion ca. 2–3 min');
}
