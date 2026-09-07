// Tests for ThemeNotifier
// =======================
// The default was changed to dark in v0.4.36. That value lives in three
// places — the field initialiser, the fallback in load() and its catch
// branch — and if they drifted apart the effective default would silently
// depend on whether SharedPreferences is reachable. A named constant plus
// these tests keep them together.
//
// The second point is the one that is easy to get wrong: switching the
// default must not swallow an explicit choice. Someone who picks "System"
// has to keep it across restarts, even though the same stored value used to
// be indistinguishable from "nothing stored yet".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:perfusion_calc/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const key = 'app_theme_mode';
  final theme = ThemeNotifier.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await theme.setMode(ThemeNotifier.kDefaultMode);
  });

  group('Default', () {
    test('Dark, on every platform', () {
      expect(ThemeNotifier.kDefaultMode, ThemeMode.dark);
    });

    test('Nothing stored yet → dark', () async {
      SharedPreferences.setMockInitialValues({});
      await theme.load();
      expect(theme.mode, ThemeMode.dark);
      expect(theme.isDark, isTrue);
    });

    test('An unreadable stored value → dark, not light', () async {
      // A corrupted or older entry must not land on the brightest option of
      // the three.
      SharedPreferences.setMockInitialValues({key: 'nonsense'});
      await theme.load();
      expect(theme.mode, ThemeMode.dark);
    });
  });

  group('An explicit choice survives', () {
    test('System stays system', () async {
      // The point of the change: only the ABSENCE of a stored value falls
      // back to dark. A deliberate "System" is not overridden.
      SharedPreferences.setMockInitialValues({key: 'system'});
      await theme.load();
      expect(theme.mode, ThemeMode.system);
    });

    test('Light stays light', () async {
      SharedPreferences.setMockInitialValues({key: 'light'});
      await theme.load();
      expect(theme.mode, ThemeMode.light);
      expect(theme.isDark, isFalse);
    });

    test('Dark stays dark', () async {
      SharedPreferences.setMockInitialValues({key: 'dark'});
      await theme.load();
      expect(theme.mode, ThemeMode.dark);
    });

    test('Every mode is written and read back unchanged', () async {
      for (final mode in ThemeMode.values) {
        await theme.setMode(mode);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(key), isNotNull, reason: '$mode not stored');
        await theme.load();
        expect(theme.mode, mode, reason: '$mode did not survive the round trip');
      }
    });
  });

  group('isDark', () {
    test('Follows the explicit modes', () async {
      await theme.setMode(ThemeMode.dark);
      expect(theme.isDark, isTrue);
      await theme.setMode(ThemeMode.light);
      expect(theme.isDark, isFalse);
    });
  });

  group('Notification', () {
    test('Only on a real change', () async {
      await theme.setMode(ThemeMode.light);
      var calls = 0;
      void listener() => calls++;
      theme.addListener(listener);
      await theme.setMode(ThemeMode.dark);
      expect(calls, 1);
      await theme.setMode(ThemeMode.dark);
      expect(calls, 1, reason: 'no rebuild for an unchanged mode');
      theme.removeListener(listener);
    });

    test('The system brightness handler only fires in system mode', () async {
      await theme.setMode(ThemeMode.dark);
      var calls = 0;
      void listener() => calls++;
      theme.addListener(listener);
      theme.handlePlatformBrightnessChanged();
      expect(calls, 0, reason: 'a fixed mode does not care about the OS');
      await theme.setMode(ThemeMode.system);
      calls = 0;
      theme.handlePlatformBrightnessChanged();
      expect(calls, 1);
      theme.removeListener(listener);
    });
  });
}
