// Eingabefilter für numerische Felder
// ===================================
// Warum eine eigene Klasse statt FilteringTextInputFormatter.allow():
//
// `allow` filtert NICHT den Gesamtstring, sondern zeichen- bzw.
// segmentweise - es läuft mit splitMapJoin über den Text, behält die
// Treffer und verwirft den Rest. Eine auf ^…$ verankerte Regex, die auf den
// Gesamtstring nicht passt, liefert dabei NULL Treffer, und dann bleibt ein
// LEERES Feld übrig.
//
// Konkret hieß das (v0.4.2 bis v0.4.7): 82,5 kg stehen im Gewichtsfeld, der
// Daumen trifft auf dem Tablet neben die Ziffer - und das Feld ist leer.
// Nicht das Zeichen abgelehnt, sondern die Eingabe weg. In einer
// OP-Situation ist Datenverlust die schlechtere der beiden möglichen
// Fehlfunktionen.
//
// Der Zustand davor war anders falsch: der Filter ließ "1.2.3" und "--5"
// stehen, _safeParse gab null zurück, und das Feld sah gefüllt aus, während
// die Rechnung nichts hatte.
//
// Diese Klasse macht das Naheliegende: Passt der neue Gesamtstring auf das
// Muster, wird er übernommen; sonst bleibt der alte stehen. Der Tastendruck
// verpufft, nichts geht verloren.

import 'package:flutter/services.dart';

/// Lässt Dezimalzahlen zu - optionales Minus, Ziffern, ein Trennzeichen
/// (Punkt oder Komma), Ziffern.
///
/// Teileingaben müssen erlaubt bleiben, sonst ließe sich das Feld nicht
/// tippen: `''`, `'-'`, `'1.'` sind gültige Zwischenzustände auf dem Weg zu
/// `'-1.5'`. Die endgültige Prüfung macht `_safeParse` in `common.dart` -
/// dieser Formatter ist die erste, nicht die einzige Verteidigungslinie.
class DecimalTextInputFormatter extends TextInputFormatter {
  static final RegExp _pattern = RegExp(r'^-?[0-9]*[.,]?[0-9]*$');

  const DecimalTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return _pattern.hasMatch(newValue.text) ? newValue : oldValue;
  }
}
