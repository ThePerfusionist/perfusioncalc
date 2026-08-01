// Alarm settings for the cardioplegia re-dose interval timer
// ============================================================
// Architecture deliberately mirrors LocaleNotifier (i18n/app_strings.dart)
// and ThemeNotifier (theme/app_theme.dart): a singleton ChangeNotifier whose
// values are persisted in SharedPreferences and loaded once in main() before
// the first frame, so the user's choices survive app restarts.
//
// Scope (this description was two releases out of date and claimed the
// opposite of what the code does):
//
//   Android/iOS  scheduled OS notification via flutter_local_notifications
//                (utils/notification_service.dart), fires with the app in
//                the background and wakes the screen.
//   Web          the app's own one-second ticker raises a browser
//                notification while the tab is alive; there is no push
//                server, so closing the browser ends the reminder.
//   Windows/Linux not supported - notification_service bails out early.
//
// On top of that, and on every platform, an in-app banner
// (widgets/in_app_alert.dart) is shown. It exists because a system
// notification can be swallowed silently by "do not disturb" or full-screen
// mode without any error surfacing.
//
// Volume is intentionally NOT offered as a setting: the alert follows the
// device's notification volume, and neither the OS notification channel nor
// HapticFeedback exposes a programmatic volume - a slider would move a
// number with no audible effect.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CardioplegiaAlarmSettings extends ChangeNotifier {
  static const _kEnabled = 'cpl_alarm_enabled';
  static const _kMinutes = 'cpl_alarm_minutes';
  static const _kSound = 'cpl_alarm_sound';
  static const _kVibration = 'cpl_alarm_vibration';
  static const _kRepeat = 'cpl_alarm_repeat';

  static final CardioplegiaAlarmSettings instance = CardioplegiaAlarmSettings._();
  CardioplegiaAlarmSettings._();

  /// Master switch. Off by default so the app never makes noise unasked.
  bool _enabled = false;

  /// Minutes after the recorded delivery at which the alert fires.
  /// Default 15 = the lower bound of the Calafiore re-dose window.
  double _triggerMinutes = 15;

  bool _sound = true;
  bool _vibration = true;

  /// Re-fire every [_triggerMinutes] instead of only once, for cases where
  /// the first alert may be missed during a busy phase.
  bool _repeat = false;

  bool get enabled => _enabled;
  double get triggerMinutes => _triggerMinutes;
  bool get sound => _sound;
  bool get vibration => _vibration;
  bool get repeat => _repeat;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _enabled = p.getBool(_kEnabled) ?? false;
      _triggerMinutes = p.getDouble(_kMinutes) ?? 15;
      _sound = p.getBool(_kSound) ?? true;
      _vibration = p.getBool(_kVibration) ?? true;
      _repeat = p.getBool(_kRepeat) ?? false;
    } catch (_) {
      // SharedPreferences unavailable (e.g. in tests) -> keep defaults.
    }
  }

  /// Takes an ASYNC writer and awaits it. With a synchronous
  /// `void Function(SharedPreferences)` the returned Future was dropped on
  /// the floor, so the surrounding try/catch caught nothing: a failing
  /// setBool/setDouble threw into the void instead of being swallowed
  /// deliberately.
  Future<void> _save(Future<void> Function(SharedPreferences p) write) async {
    try {
      final p = await SharedPreferences.getInstance();
      await write(p);
    } catch (_) {
      // Persisting failed -> the choice still applies for this session.
    }
  }

  Future<void> setEnabled(bool v) async {
    if (_enabled == v) return;
    _enabled = v;
    notifyListeners();
    await _save((p) => p.setBool(_kEnabled, v));
  }

  /// Clamped to a plausible band: below 1 min the alert would be useless,
  /// above 240 min it is past every protocol's window.
  Future<void> setTriggerMinutes(double v) async {
    final clamped = v < 1 ? 1.0 : (v > 240 ? 240.0 : v);
    if (_triggerMinutes == clamped) return;
    _triggerMinutes = clamped;
    notifyListeners();
    await _save((p) => p.setDouble(_kMinutes, clamped));
  }

  Future<void> setSound(bool v) async {
    if (_sound == v) return;
    _sound = v;
    notifyListeners();
    await _save((p) => p.setBool(_kSound, v));
  }

  Future<void> setVibration(bool v) async {
    if (_vibration == v) return;
    _vibration = v;
    notifyListeners();
    await _save((p) => p.setBool(_kVibration, v));
  }

  Future<void> setRepeat(bool v) async {
    if (_repeat == v) return;
    _repeat = v;
    notifyListeners();
    await _save((p) => p.setBool(_kRepeat, v));
  }

  /// How many times the alert should have fired by [elapsed].
  /// Pure function so the firing schedule is unit-testable without a clock:
  ///   - alarm off, or before the trigger point -> 0
  ///   - non-repeating -> 1 once the trigger point is passed
  ///   - repeating -> one per completed trigger interval
  static int expectedFireCount({
    required Duration elapsed,
    required bool enabled,
    required double triggerMinutes,
    required bool repeat,
  }) {
    if (!enabled || triggerMinutes <= 0) return 0;
    final minutes = elapsed.inSeconds / 60.0;
    if (minutes < triggerMinutes) return 0;
    if (!repeat) return 1;
    return (minutes / triggerMinutes).floor();
  }
}
