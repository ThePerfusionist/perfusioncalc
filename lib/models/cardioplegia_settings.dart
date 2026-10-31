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
//
// The Calafiore Perfusor syringe (v0.4.38) follows the same reasoning: it is
// drawn up the same way for every case, so its composition and the unit the
// concentrations are entered in are kept here and survive restarts. The
// Calafiore methods on PatientData receive it as a CalafioreSyringe.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'calafiore_syringe.dart';

class CardioplegiaSettings extends ChangeNotifier {
  static const _kDelNidoCrystalloidPercent = 'cpl_delnido_cryst_percent';
  static const _kCalafioreKclVolume = 'cpl_calafiore_kcl_volume';
  static const _kCalafioreKclConc = 'cpl_calafiore_kcl_conc';
  static const _kCalafioreMgVolume = 'cpl_calafiore_mg_volume';
  static const _kCalafioreMgConc = 'cpl_calafiore_mg_conc';
  static const _kCalafioreKclInPercent = 'cpl_calafiore_kcl_unit_percent';
  static const _kCalafioreMgInPercent = 'cpl_calafiore_mg_unit_percent';

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

  // ── Calafiore Perfusor syringe ───────────────────────────────────────────
  // Every field starts blank: there is no shipped default composition, so a
  // fresh install shows exactly what it showed before this was persisted.
  // A hard-coded default would quietly feed a Perfusor rate nobody entered.
  CalafioreSyringe _calafioreSyringe = CalafioreSyringe.empty;

  /// Display unit of the two stock concentration fields. Purely an entry
  /// convenience - the stored concentration is always mmol/ml.
  bool _calafioreKclInPercent = false;
  bool _calafioreMgInPercent = false;

  CalafioreSyringe get calafioreSyringe => _calafioreSyringe;
  bool get calafioreKclInPercent => _calafioreKclInPercent;
  bool get calafioreMgInPercent => _calafioreMgInPercent;

  Future<void> load() async {
    final SharedPreferences p;
    try {
      p = await SharedPreferences.getInstance();
    } catch (_) {
      // SharedPreferences unavailable (e.g. in tests) -> keep the defaults.
      return;
    }

    // CLAMPED, not taken raw: the setter does bound the value, but that
    // does not guarantee the stored one is inside the band — an older
    // version, a different device or a tampered entry can deliver 100.
    // delNidoBloodPercent would then be zero and the ratio undefined.
    // TransfusionSettings.load() clamps for the same reason; that it was
    // missing here was an asymmetry between two classes of the same
    // pattern.
    final stored = _readDouble(p, _kDelNidoCrystalloidPercent);
    if (stored != null) _delNidoCrystalloidPercent = _clamp(stored);

    // The syringe values are SANITISED, not clamped. They are free entries
    // whose Ranges only warn and never block, so clamping a stored 120 ml to
    // the 100 ml plausibility limit would silently change a value the user
    // deliberately typed. What load() must keep out is what no entry can
    // produce and what would break the arithmetic: NaN, Infinity and
    // negative numbers. Those become "not entered".
    _calafioreSyringe = CalafioreSyringe(
      kclVolume: sanitizeSyringeValue(_readDouble(p, _kCalafioreKclVolume)),
      kclStockConc: sanitizeSyringeValue(_readDouble(p, _kCalafioreKclConc)),
      mgVolume: sanitizeSyringeValue(_readDouble(p, _kCalafioreMgVolume)),
      mgStockConc: sanitizeSyringeValue(_readDouble(p, _kCalafioreMgConc)),
    );
    _calafioreKclInPercent = _readBool(p, _kCalafioreKclInPercent) ?? false;
    _calafioreMgInPercent = _readBool(p, _kCalafioreMgInPercent) ?? false;
  }

  /// Per key, so one entry of the wrong type (e.g. written by a different
  /// app version) costs only that entry instead of aborting the whole load.
  static double? _readDouble(SharedPreferences p, String key) {
    try {
      return p.getDouble(key);
    } catch (_) {
      return null;
    }
  }

  static bool? _readBool(SharedPreferences p, String key) {
    try {
      return p.getBool(key);
    } catch (_) {
      return null;
    }
  }

  static double _clamp(double v) =>
      v < kMinPercent ? kMinPercent : (v > kMaxPercent ? kMaxPercent : v);

  /// null for anything that cannot be a syringe volume or concentration
  /// (null, NaN, Infinity, negative); the value itself otherwise. Public so
  /// the rule is testable on its own.
  @visibleForTesting
  static double? sanitizeSyringeValue(double? v) =>
      (v == null || !v.isFinite || v < 0) ? null : v;

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

  // ── Calafiore syringe setters ────────────────────────────────────────────
  // null clears the field AND removes the stored entry, so an emptied field
  // stays empty after the next start instead of resurrecting an old value.

  Future<void> setCalafioreKclVolume(double? v) => _setSyringe(
      _kCalafioreKclVolume, v,
      (s, x) => CalafioreSyringe(kclVolume: x, kclStockConc: s.kclStockConc,
          mgVolume: s.mgVolume, mgStockConc: s.mgStockConc));

  /// [v] in mmol/ml - the screen converts from % before calling this.
  Future<void> setCalafioreKclConc(double? v) => _setSyringe(
      _kCalafioreKclConc, v,
      (s, x) => CalafioreSyringe(kclVolume: s.kclVolume, kclStockConc: x,
          mgVolume: s.mgVolume, mgStockConc: s.mgStockConc));

  Future<void> setCalafioreMgVolume(double? v) => _setSyringe(
      _kCalafioreMgVolume, v,
      (s, x) => CalafioreSyringe(kclVolume: s.kclVolume, kclStockConc: s.kclStockConc,
          mgVolume: x, mgStockConc: s.mgStockConc));

  /// [v] in mmol/ml - the screen converts from % before calling this.
  Future<void> setCalafioreMgConc(double? v) => _setSyringe(
      _kCalafioreMgConc, v,
      (s, x) => CalafioreSyringe(kclVolume: s.kclVolume, kclStockConc: s.kclStockConc,
          mgVolume: s.mgVolume, mgStockConc: x));

  Future<void> setCalafioreKclInPercent(bool v) async {
    if (_calafioreKclInPercent == v) return;
    _calafioreKclInPercent = v;
    notifyListeners();
    await _persistBool(_kCalafioreKclInPercent, v);
  }

  Future<void> setCalafioreMgInPercent(bool v) async {
    if (_calafioreMgInPercent == v) return;
    _calafioreMgInPercent = v;
    notifyListeners();
    await _persistBool(_kCalafioreMgInPercent, v);
  }

  Future<void> _setSyringe(
    String key,
    double? raw,
    CalafioreSyringe Function(CalafioreSyringe current, double? value) apply,
  ) async {
    final v = sanitizeSyringeValue(raw);
    final next = apply(_calafioreSyringe, v);
    if (next == _calafioreSyringe) return;
    _calafioreSyringe = next;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      if (v == null) {
        await p.remove(key);
      } else {
        await p.setDouble(key, v);
      }
    } catch (_) {
      // Persisting failed -> the value still applies for this session.
    }
  }

  Future<void> _persistBool(String key, bool v) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(key, v);
    } catch (_) {
      // Persisting failed -> the choice still applies for this session.
    }
  }
}
