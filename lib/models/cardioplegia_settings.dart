// Institutional cardioplegia protocol settings
// ==============================================
// Same persisted-singleton pattern as LocaleNotifier / ThemeNotifier /
// CardioplegiaAlarmSettings: loaded once in main() before the first frame,
// so the configured mixing ratio survives app restarts.
//
// Why a setting and not a per-case value: the crystalloid:blood ratio is an
// institutional standard that stays the same from case to case. Keeping it
// out of PatientData also keeps that class free of external dependencies -
// its del Nido methods take the share as an explicit parameter instead, so
// the formulas stay pure and unit-testable without any stored state.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CardioplegiaSettings extends ChangeNotifier {
  static const _kDelNidoCrystalloidPercent = 'cpl_delnido_cryst_percent';

  /// 80 % corresponds to the classic 4:1 ratio (the del Nido standard).
  static const double kDefaultCrystalloidPercent = 80;

  /// Outside this band the mixture stops being a blood cardioplegia in any
  /// recognisable sense, and at 100 % the blood share would be zero and the
  /// ratio undefined.
  static const double kMinPercent = 50;
  static const double kMaxPercent = 95;

  static final CardioplegiaSettings instance = CardioplegiaSettings._();
  CardioplegiaSettings._();

  /// Crystalloid share of the finished cardioplegia, in percent.
  /// 80 % is the del Nido standard and corresponds to the classic 4:1
  /// crystalloid:blood ratio. The blood share is always the remainder.
  double _delNidoCrystalloidPercent = kDefaultCrystalloidPercent;

  double get delNidoCrystalloidPercent => _delNidoCrystalloidPercent;
  double get delNidoBloodPercent => 100 - _delNidoCrystalloidPercent;

  /// The ratio expressed as "parts crystalloid : 1 part blood" - what the
  /// protocol is usually quoted as (80 % -> 4.0).
  double get delNidoRatio {
    final blood = delNidoBloodPercent;
    if (blood <= 0) return 0;
    return _delNidoCrystalloidPercent / blood;
  }

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final stored = p.getDouble(_kDelNidoCrystalloidPercent);
      // CLAMPED, not taken raw: the setter does bound the value, but that
      // does not guarantee the stored one is inside the band — an older
      // version, a different device or a tampered entry can deliver 100.
      // delNidoBloodPercent would then be zero and the ratio undefined.
      // TransfusionSettings.load() clamps for the same reason; that it was
      // missing here was an asymmetry between two classes of the same
      // pattern.
      if (stored != null) _delNidoCrystalloidPercent = _clamp(stored);
    } catch (_) {
      // SharedPreferences unavailable (e.g. in tests) -> keep the default.
    }
  }

  static double _clamp(double v) =>
      v < kMinPercent ? kMinPercent : (v > kMaxPercent ? kMaxPercent : v);

  /// Clamped to [kMinPercent]..[kMaxPercent] — rationale documented there.
  Future<void> setDelNidoCrystalloidPercent(double v) async {
    final clamped = _clamp(v);
    if (_delNidoCrystalloidPercent == clamped) return;
    _delNidoCrystalloidPercent = clamped;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble(_kDelNidoCrystalloidPercent, clamped);
    } catch (_) {
      // Persisting failed -> the choice still applies for this session.
    }
  }
}
