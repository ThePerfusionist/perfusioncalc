// Input filter for numeric fields
// ===============================
// Why a dedicated class instead of FilteringTextInputFormatter.allow():
//
// `allow` does NOT filter the whole string; it filters character by
// character, or rather segment by segment — it runs splitMapJoin over the
// text, keeps the matches and discards the rest. A regex anchored with ^…$
// that does not match the whole string therefore yields ZERO matches, and
// what remains is an EMPTY field.
//
// In practice that meant (v0.4.2 through v0.4.7): 82.5 kg are in the weight
// field, the thumb lands next to the digit on a tablet — and the field is
// empty. Not the character rejected, but the entry gone. In an OR situation
// data loss is the worse of the two possible malfunctions.
//
// The state before that was wrong in a different way: the filter let "1.2.3"
// and "--5" through, _safeParse returned null, and the field looked filled
// while the calculation had nothing.
//
// This class does the obvious thing: if the new whole string matches the
// pattern it is accepted, otherwise the old one stays. The keystroke has no
// effect, nothing is lost.

import 'package:flutter/services.dart';

/// Accepts decimal numbers — optional minus, digits, one separator (period
/// or comma), digits.
///
/// Partial input has to stay allowed, otherwise the field could not be typed
/// into: `''`, `'-'`, `'1.'` are valid intermediate states on the way to
/// `'-1.5'`. The final check is done by `_safeParse` in `common.dart` — this
/// formatter is the first line of defence, not the only one.
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
