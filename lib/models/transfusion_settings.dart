// Institutional transfusion settings
// ===================================
// Same persisted-singleton pattern as LocaleNotifier / ThemeNotifier /
// CardioplegiaSettings: loaded once in main() before the first frame, so the
// configured value survives app restarts.
//
// Why a setting and not a per-case input: the hematocrit of a red cell
// concentrate is a property of the blood service's product, not of the
// patient. It is the same for every case in a given department and changes
// only when the supplier or the additive solution changes - exactly the
// profile of a setting.
//
// Why it must be configurable at all: Davies' formula divides by it, so it
// scales every pediatric transfusion volume linearly. German RBC
// concentrates in additive solution are specified at Hct 0.50-0.70, the UK
// standard Davies worked with is 0.60. Between 0.50 and 0.70 the calculated
// volume differs by 40 % - in a neonate that is the difference between an
// adequate transfusion and a volume overload. A hard-coded constant made
// that assumption invisible.
//
// Not stored in PatientData on purpose: that class stays free of external
// dependencies and holds nothing that outlives a session, which is also what
// the privacy policy states. The transfusion formula takes the hematocrit as
// an explicit parameter, so it remains pure and unit-testable.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TransfusionSettings extends ChangeNotifier {
  static const _kRbcUnitHematocritPercent = 'tx_rbc_unit_hct_percent';

  /// Davies 2007 quotes the UK standard as 0.60. The app has shipped with
  /// 0.55 since the pediatric tab existed, so that stays the default - a
  /// changed default would silently move the number for every existing user.
  static const double kDefaultRbcUnitHematocritPercent = 55;

  /// Below 40 % or above 80 % the product is no longer a red cell
  /// concentrate in any recognisable sense, and values near 0 would make the
  /// formula explode.
  static const double kMinPercent = 40;
  static const double kMaxPercent = 80;

  static final TransfusionSettings instance = TransfusionSettings._();
  TransfusionSettings._();

  double _rbcUnitHematocritPercent = kDefaultRbcUnitHematocritPercent;

  /// Hematocrit of the transfused red cell concentrate, in percent.
  double get rbcUnitHematocritPercent => _rbcUnitHematocritPercent;

  /// The same value as the fraction Davies' formula actually divides by.
  double get rbcUnitHematocritFraction => _rbcUnitHematocritPercent / 100.0;

  /// True while the configured value is the shipped default - lets the UI
  /// point out that this is an assumption nobody has confirmed yet.
  bool get isDefault =>
      _rbcUnitHematocritPercent == kDefaultRbcUnitHematocritPercent;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final stored = p.getDouble(_kRbcUnitHematocritPercent);
      if (stored != null) _rbcUnitHematocritPercent = _clamp(stored);
    } catch (_) {
      // SharedPreferences unavailable (e.g. in tests) -> keep the default.
    }
  }

  Future<void> setRbcUnitHematocritPercent(double v) async {
    final clamped = _clamp(v);
    if (_rbcUnitHematocritPercent == clamped) return;
    _rbcUnitHematocritPercent = clamped;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble(_kRbcUnitHematocritPercent, clamped);
    } catch (_) {
      // Persisting failed -> the choice still applies for this session.
    }
  }

  /// Back to the shipped default, for the "reset" affordance in the UI.
  Future<void> reset() =>
      setRbcUnitHematocritPercent(kDefaultRbcUnitHematocritPercent);

  static double _clamp(double v) =>
      v < kMinPercent ? kMinPercent : (v > kMaxPercent ? kMaxPercent : v);
}
