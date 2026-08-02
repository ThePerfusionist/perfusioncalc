// Begrenzung der +/- Schrittknöpfe
// =================================
// Ausgelagert aus der privaten State-Klasse in common.dart, damit es
// testbar ist (Audit R-3) — dasselbe Muster wie bei formatElapsed.
//
// Warum das einen eigenen Test verdient: Die Logik hat zwei Ausnahmen, die
// beim Lesen niemand nachprüft, und beide sind klinisch relevant.
//
// Die erste Fassung klemmte jeden Schritt hart auf [min, max]. Das behob das
// gemeldete Problem (Dekrement aus dem leeren Gewichtsfeld ergab -0,1 kg),
// überschrieb aber eine schriftlich festgehaltene Designabsicht: der Kopf
// von ranges.dart sagt ausdrücklich, dass Berechnungen Werte außerhalb der
// Range akzeptieren, "to deliberately work through extreme cases in
// training" — dafür existiert die orange Warnung. Mit hartem Klemmen ließ
// sich ein Hb zwar auf 3 g/dl tippen, aber nicht mehr unter 4 schrittweise
// senken, und genau das will ein Lehrmittel können.

import '../models/ranges.dart';

/// Begrenzt einen +/- Schritt auf das physikalisch Mögliche — nicht auf das
/// Plausible.
///
/// [fromEmpty] beschreibt den Zustand VOR dem Schritt: war das Feld leer,
/// wird von 0 aus gerechnet, und ein Dekrement soll dann nicht in den
/// negativen Bereich fallen, sondern auf die Untergrenze aufsetzen.
///
/// Ansonsten wird nur bei 0 gestoppt, und auch das nur, wo negative Werte
/// keinen Sinn ergeben. Ranges mit negativer Untergrenze — Base Excess,
/// ZVD — behalten ihre negativen Werte; ein Klemmen auf 0 wäre dort
/// klinisch falsch.
double clampStep(double v, Range? range, {required bool fromEmpty}) {
  if (range == null) return v;
  if (fromEmpty && v < range.min) return range.min;
  if (v < 0 && range.min >= 0) return 0;
  return v;
}
