// Physiologische Normbereiche für Plausibilitätsprüfung
// =====================================================
// Diese Werte werden NUR zur sanften Warnung in der UI verwendet.
// Die eigentlichen Berechnungen akzeptieren weiterhin Werte außerhalb
// dieser Bereiche (z.B. um in Schulungen bewusst Extremfälle durchzuspielen).
//
// Quellen zu den Ranges:
//   Herold G. Innere Medizin. 2023. Standardwerte Erwachsene.
//   Silbernagl & Despopoulos, Physiologie-Taschenatlas. 9. Aufl. 2018.
//   Kasper DL et al. Harrison's Principles of Internal Medicine. 20th ed.
//
// Die Bereiche sind bewusst WEIT gefasst: nicht "Normalbereich für einen
// gesunden 25-Jährigen", sondern "plausibler Wertebereich für einen realen
// Patienten im kardiochirurgischen Kontext". Ein Hb von 7 g/dl ist nicht
// normal, aber plausibel (anämischer Patient); ein Hb von 50 g/dl dagegen
// ist nie plausibel (Tippfehler).

/// Ein klinisch plausibler Wertebereich für ein Eingabefeld.
/// Werte außerhalb werden in der UI als Warnung (gelber Rand) markiert,
/// führen aber nicht zum Abbruch der Berechnung.
class Range {
  final double min;
  final double max;
  final String unit;
  final String? note; // optionaler Hinweistext im Tooltip
  const Range(this.min, this.max, this.unit, {this.note});

  /// true, wenn der Wert innerhalb des plausiblen Bereichs liegt.
  /// null-Werte gelten als "nicht eingegeben" und damit nicht unplausibel.
  bool contains(double? v) {
    if (v == null) return true;
    return v >= min && v <= max;
  }

  /// Für Tooltip-Anzeige: "5–20 g/dl"
  String get display => '$min–$max $unit';
}

/// Zentrale Sammlung aller Normbereiche, nach klinischem Kontext gruppiert.
/// Zum Anpassen einfach die Werte hier ändern — die UI übernimmt sofort.
class Ranges {
  // ── Anthropometrie ──────────────────────────────────────────────────────
  static const height = Range(30, 230, 'cm',
      note: 'Körpergröße Säuglinge bis Riesenwuchs');
  static const weight = Range(0.5, 300, 'kg',
      note: 'Neugeborene bis adipositas permagna');
  static const pediatricWeight = Range(0.5, 50, 'kg',
      note: 'Pädiatrischer Bereich');
  static const bsa = Range(0.1, 3.5, 'm²',
      note: 'Säugling bis sehr großer Erwachsener');

  // ── Hämatologie ─────────────────────────────────────────────────────────
  static const hb = Range(4, 22, 'g/dl',
      note: 'Schwere Anämie bis Polyglobulie');
  static const hct = Range(10, 65, '%',
      note: 'Schwere Anämie bis Polyglobulie');
  static const primingVolume = Range(0, 3000, 'ml',
      note: 'Typisch 1200–1800 ml Adult, 300–600 ml Pädiatrie');

  // ── Sauerstofftransport ─────────────────────────────────────────────────
  static const paO2 = Range(20, 600, 'mmHg',
      note: 'Hypoxämie bis 100% O2-Beatmung');
  static const pvO2 = Range(10, 80, 'mmHg',
      note: 'Gemischt-venös typisch 35–45');
  static const saO2 = Range(50, 100, '%',
      note: 'Schwere Hypoxämie bis Normalbefund');
  static const svO2 = Range(30, 90, '%',
      note: 'Normal 65–75%, kritisch <50%');

  // ── Hämodynamik ─────────────────────────────────────────────────────────
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

  // ── Elektrolyte / BGA ───────────────────────────────────────────────────
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

  // ── Schlauchlänge ───────────────────────────────────────────────────────
  static const tubeLength = Range(10, 500, 'cm',
      note: 'Übliche Längen HLM-Schlauchsysteme');

  // ── Charrière ───────────────────────────────────────────────────────────
  static const ch = Range(1, 40, 'Ch');
  static const mm = Range(0.3, 15, 'mm');

  // ── Pädiatrie ───────────────────────────────────────────────────────────
  static const desiredHbIncrease = Range(0.5, 8, 'g/dl',
      note: 'Üblicher Ziel-Hb-Anstieg');
}
