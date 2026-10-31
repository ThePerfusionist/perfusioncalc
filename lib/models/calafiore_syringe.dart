// Calafiore Perfusor syringe composition
// ======================================
// Pure value object: no Flutter, no persistence, no singletons. It is held
// by CardioplegiaSettings (which persists it) and handed to the Calafiore
// methods on PatientData as an explicit parameter - the same split as the
// del Nido mixing ratio, so the formulas stay unit-testable without any
// stored state and PatientData keeps holding nothing that outlives a
// session.
//
// Why the syringe is a setting and not case data: it is drawn up the same
// way for every case from the same ampoules (institutionally 4 x 10 ml KCl
// 14.9 % + 1 x 10 ml MgSO4 . 7H2O 500 mg/ml). Re-entering it after every
// app start was busywork, and busywork invites typos in a value that
// scales the Perfusor rate linearly.

import 'package:flutter/foundation.dart' show immutable;

@immutable
class CalafioreSyringe {
  /// ml, TOTAL KCl volume drawn into the syringe.
  final double? kclVolume;

  /// mmol/ml, concentration of the KCl stock (ampoule), canonical unit.
  final double? kclStockConc;

  /// ml, TOTAL MgSO4 volume drawn in. OPTIONAL - blank means pure KCl.
  final double? mgVolume;

  /// mmol/ml, concentration of the MgSO4 stock (ampoule). OPTIONAL.
  final double? mgStockConc;

  const CalafioreSyringe({
    this.kclVolume,
    this.kclStockConc,
    this.mgVolume,
    this.mgStockConc,
  });

  /// Nothing entered yet.
  static const CalafioreSyringe empty = CalafioreSyringe();

  /// True when at least one field carries a value.
  bool get hasAnyInput =>
      kclVolume != null ||
      kclStockConc != null ||
      mgVolume != null ||
      mgStockConc != null;

  /// Total volume of the prepared syringe. The MgSO4 component is optional:
  /// if it is left blank the syringe is pure KCl and every downstream
  /// calculation still works (the K+ concentration is then simply
  /// undiluted).
  double get totalVolume => _safe((kclVolume ?? 0) + (mgVolume ?? 0));

  /// Resulting [K+] in the syringe (mmol/ml) after the (optional) MgSO4
  /// volume has diluted the KCl stock. 0 while the KCl inputs are missing.
  double get resultingKConc {
    final total = totalVolume;
    final v = kclVolume;
    final c = kclStockConc;
    if (total <= 0 || v == null || c == null) return 0;
    return _safe(v * c / total);
  }

  /// Resulting [Mg2+] in the syringe (mmol/ml). Returns 0 when no magnesium
  /// was added - that is a valid configuration, not a missing input.
  double get resultingMgConc {
    final total = totalVolume;
    final v = mgVolume;
    final c = mgStockConc;
    if (total <= 0 || v == null || c == null) return 0;
    return _safe(v * c / total);
  }

  /// Same guard as PatientData._safe: no NaN/Infinity on screen, and -0.0
  /// normalised to +0.0 so it never renders as "-0.00".
  static double _safe(double v) {
    if (v.isNaN || v.isInfinite) return 0;
    return v + 0.0;
  }

  @override
  bool operator ==(Object other) =>
      other is CalafioreSyringe &&
      other.kclVolume == kclVolume &&
      other.kclStockConc == kclStockConc &&
      other.mgVolume == mgVolume &&
      other.mgStockConc == mgStockConc;

  @override
  int get hashCode => Object.hash(kclVolume, kclStockConc, mgVolume, mgStockConc);
}
