// Scheduled local notifications for the cardioplegia re-dose timer
// =================================================================
//
// WHY THIS REPLACES THE PREVIOUS IN-APP ALERT
// The earlier implementation used SystemSound.play(SystemSoundType.alert)
// plus HapticFeedback. That was a mistake for this use case:
//   * SystemSoundType.alert is effectively a no-op on Android - which is
//     exactly why no sound was heard on a Samsung S23+, even with the app
//     in the foreground.
//   * An in-app ticker can never fire while the app is backgrounded or the
//     screen is off, so it could not do what a re-dose reminder has to do.
//
// The reliable approach is to SCHEDULE the notification with the OS the
// moment a delivery is recorded, rather than trying to fire it ourselves
// when the moment arrives. The OS then delivers it regardless of whether
// PerfusionCalc is in the foreground, backgrounded, or the screen is off.
//
// Channel importance is set to max with a full-screen intent so the alert
// can wake the device; scheduling uses exact alarms
// (AndroidScheduleMode.exactAllowWhileIdle) so Doze does not defer it.
//
// PLATFORM SETUP THIS DEPENDS ON (already applied in this repo):
//   android/app/src/main/AndroidManifest.xml - POST_NOTIFICATIONS,
//     SCHEDULE_EXACT_ALARM, USE_EXACT_ALARM, VIBRATE, WAKE_LOCK,
//     RECEIVE_BOOT_COMPLETED + the two flutter_local_notifications receivers
//   android/app/build.gradle.kts - core library desugaring
//   pubspec.yaml - flutter_local_notifications, timezone
//
// KNOWN VENDOR CAVEAT (Samsung in particular): aggressive battery
// management ("Sleeping apps"/"Deep sleeping apps", Adaptive Battery) can
// still suppress or delay scheduled alarms. The app therefore surfaces the
// permission state in the UI and asks the user to exclude PerfusionCalc
// from battery optimisation - see the hint texts in the cardioplegia tab.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'web_notifications_stub.dart'
    if (dart.library.js_interop) 'web_notifications_web.dart';

class CardioplegiaNotifications {
  static final CardioplegiaNotifications instance = CardioplegiaNotifications._();
  CardioplegiaNotifications._();

  static const String _channelId = 'cardioplegia_redose';
  static const String _channelName = 'Cardioplegia re-dose reminder';
  static const String _channelDescription =
      'Reminds you when the cardioplegia re-dose interval has elapsed.';

  /// Notification ids reserved for this feature. A fixed block keeps
  /// cancelling deterministic: cancelAll() would also clear notifications
  /// from any future feature, so we only ever cancel our own ids.
  static const int _baseId = 4200;
  static const int maxScheduledOccurrences = 12;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialised = false;

  /// Last initialisation error, surfaced in the UI. Swallowing this
  /// silently made a failed init indistinguishable from a denied
  /// permission: the button appeared to do nothing and no reminder ever
  /// arrived, with no clue why.
  String? lastError;

  /// True once initialise() has run and the platform accepted it. When
  /// false (e.g. web, or a platform without the plugin) every method below
  /// degrades to a no-op instead of throwing.
  bool get isAvailable => _initialised;

  /// Small-icon candidates, tried in order.
  ///
  /// The plugin VALIDATES this name inside initialize() and throws if it
  /// cannot be resolved via Resources.getIdentifier(name, "drawable", pkg).
  /// A single unresolvable name therefore disables the entire service - so
  /// we fall back to the launcher icon, which is guaranteed to exist, rather
  /// than losing notifications over a cosmetic detail.
  static const List<String> _iconCandidates = [
    'ic_notification',        // dedicated monochrome icon (preferred)
    '@drawable/ic_notification',
    '@mipmap/ic_launcher',    // always present in a Flutter app
  ];

  /// Which icon actually worked - surfaced for diagnostics.
  String? activeIcon;

  Future<void> initialise() async {
    if (_initialised) return;

    // Web uses the browser Notification API instead of the plugin, which has
    // no web implementation. Nothing to initialise beyond checking that the
    // API exists - permission is requested on demand.
    if (kIsWeb) {
      if (WebNotifications.isSupported) {
        _initialised = true;
        activeIcon = 'web';
        lastError = null;
      } else {
        lastError = 'Browser Notification API unavailable '
            '(${WebNotifications.permission}). A secure context (https or '
            'localhost) is required.';
      }
      return;
    }

    // Timezone setup is guarded separately: if it fails we can still post
    // immediate notifications, only scheduling would be affected.
    try {
      tzdata.initializeTimeZones();
      // UTC on purpose, and it is not a limitation here.
      //
      // The previous code read tz.local.name and passed it to
      // setLocalLocation - but before setLocalLocation runs, tz.local IS
      // UTC by definition, so it asked for the zone it was about to set and
      // the catch branch was unreachable. It looked like device-timezone
      // detection and never was one.
      //
      // Nothing is lost: every reminder is scheduled as now + Duration and
      // handed to TZDateTime.from() as an absolute instant. Across a DST
      // boundary UTC is in fact the more robust choice - a wall-clock zone
      // would shift the fire time by an hour. If a real device zone is ever
      // needed (e.g. for daily reminders at a fixed local time), add the
      // flutter_timezone package; tz.local.name cannot supply it.
      tz.setLocalLocation(tz.UTC);
    } catch (e) {
      debugPrint('[CardioplegiaNotifications] timezone setup failed: $e');
    }

    // NEU-2: flutter_local_notifications_windows/_linux are registered via
    // generated_plugins.cmake since the v22 migration, but no windows:/
    // linux: settings are passed below - the plugin then throws
    // ArgumentError for the running platform. The icon-candidate loop
    // catches it and the UI blames a broken notification icon, which sends
    // the diagnosis in exactly the wrong direction.
    //
    // Desktop is not a shipping target: the Windows offline bundle is the
    // WEB app behind Caddy, not a Flutter desktop build. So bail out with
    // an honest message rather than pretending to initialise.
    // defaultTargetPlatform, not Platform.isWindows: this file is also
    // compiled for web, where importing dart:io breaks the build.
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux)) {
      lastError = 'Scheduled notifications are not supported on this '
          'platform. Use the in-app alert instead.';
      _initialised = false;
      return;
    }

    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    Object? lastFailure;
    for (final icon in _iconCandidates) {
      try {
        // v20+: initialize() takes named parameters; the settings object is
        // now passed as `settings:`.
        final ok = await _plugin.initialize(
          settings: InitializationSettings(
            android: AndroidInitializationSettings(icon),
            iOS: darwin,
            macOS: darwin,
          ),
        );
        if (ok == false) {
          lastFailure = 'initialize() returned false for icon "$icon"';
          continue;
        }
        activeIcon = icon;
        _initialised = true;
        lastError = null;
        break;
      } catch (e) {
        // Most likely an unresolvable icon resource - try the next one.
        debugPrint('[CardioplegiaNotifications] init failed with icon "$icon": $e');
        lastFailure = e;
      }
    }

    if (!_initialised) {
      lastError = lastFailure?.toString() ?? 'unknown initialisation failure';
      return;
    }

    // Create the channel up front so its importance/sound/vibration are
    // registered before the first notification is scheduled. On Android a
    // channel's importance cannot be raised later - it would need a
    // reinstall - so getting this right at creation matters.
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.createNotificationChannel(const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ));
    } catch (e) {
      // A missing channel does not justify disabling the whole service:
      // Android recreates a default channel on first post.
      debugPrint('[CardioplegiaNotifications] channel creation failed: $e');
    }
  }

  /// Asks for notification permission (Android 13+ / iOS). Returns true if
  /// notifications may be posted.
  Future<bool> requestPermission() async {
    // Retry initialisation rather than returning a dead false - otherwise a
    // transient init failure permanently disables the button.
    if (!_initialised) await initialise();
    if (!_initialised) return false;
    if (kIsWeb) {
      final ok = await WebNotifications.requestPermission();
      lastError = ok ? null : WebNotifications.lastError;
      return ok;
    }
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission() ?? false;
        // Exact alarms are a separate, user-revocable permission on
        // Android 12+; without it the OS silently downgrades to inexact
        // delivery, which for a 15-minute clinical reminder is not good
        // enough - so we ask for it explicitly.
        await android.requestExactAlarmsPermission();
        return granted;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, badge: true, sound: true) ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('[CardioplegiaNotifications] permission request failed: $e');
      return false;
    }
  }

  Future<bool> areNotificationsEnabled() async {
    if (!_initialised) await initialise();
    if (!_initialised) return false;
    if (kIsWeb) return WebNotifications.isGranted;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) return await android.areNotificationsEnabled() ?? false;
      // iOS/macOS: no query API, assume granted unless the request said
      // otherwise. Windows/Linux never get here - initialise() returns
      // early for them, so _initialised is false and this method already
      // returned above.
      return true;
    } catch (_) {
      return false;
    }
  }

  NotificationDetails _details({required bool sound, required bool vibration}) {
    final android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: sound,
      enableVibration: vibration,
      // NOTE: fullScreenIntent is deliberately NOT set. It makes the system
      // launch an activity when the notification fires, which needs the
      // USE_FULL_SCREEN_INTENT permission on Android 14+ and is the most
      // likely reason a SCHEDULED notification crashed the app while the
      // immediate test notification worked (the full-screen path is
      // suppressed while the app is already in the foreground).
      // Importance.max + the alarm category still produce a heads-up alert
      // with sound and vibration that shows on the lock screen.
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      ticker: 'Cardioplegia',
    );
    final darwin = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: sound,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    return NotificationDetails(android: android, iOS: darwin, macOS: darwin);
  }

  /// Schedules the re-dose reminder(s) for a delivery given at [from].
  ///
  /// [intervalMinutes] is the configured trigger time; when [repeat] is set
  /// the reminder is re-scheduled for each following interval (a bounded
  /// number of occurrences - Android caps how many alarms an app may hold).
  /// Re-runs initialisation if a previous attempt failed, so the feature
  /// can recover without an app restart.
  Future<void> ensureReady() async {
    if (!_initialised) await initialise();
  }

  Future<void> scheduleReminders({
    required DateTime from,
    required double intervalMinutes,
    required bool repeat,
    required bool sound,
    required bool vibration,
    required String title,
    required String body,
  }) async {
    await ensureReady();
    if (!_initialised || intervalMinutes <= 0) return;
    // Web cannot schedule ahead of time (see web_notifications_web.dart);
    // there the running ticker raises the notification when the moment
    // arrives, so there is nothing to register here.
    if (kIsWeb) return;
    await cancelAll();
    try {
      final occurrences = repeat ? maxScheduledOccurrences : 1;
      final details = _details(sound: sound, vibration: vibration);
      for (var i = 1; i <= occurrences; i++) {
        final when = tz.TZDateTime.from(
          from.add(Duration(seconds: (intervalMinutes * 60 * i).round())),
          tz.local,
        );
        // Skip anything already in the past (e.g. settings changed long
        // after the delivery) - the OS would fire it immediately.
        if (when.isBefore(tz.TZDateTime.now(tz.local))) continue;
        final body_ = repeat && occurrences > 1
            ? '$body (${i * intervalMinutes.round()} min)'
            : body;
        try {
          // v20+: all parameters are named. v19 removed
          // uiLocalNotificationDateInterpretation (it only applied to iOS 10
          // and older, which the plugin no longer supports).
          await _plugin.zonedSchedule(
            id: _baseId + i,
            title: title,
            body: body_,
            scheduledDate: when,
            notificationDetails: details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );
        } on PlatformException catch (e) {
          // Exact alarms need a separate, user-revocable permission on
          // Android 12+. If it is missing the platform throws instead of
          // degrading, so fall back to inexact delivery rather than losing
          // the reminder entirely.
          debugPrint('[CardioplegiaNotifications] exact alarm rejected ($e) - falling back to inexact');
          await _plugin.zonedSchedule(
            id: _baseId + i,
            title: title,
            body: body_,
            scheduledDate: when,
            notificationDetails: details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
        }
      }
    } catch (e, st) {
      debugPrint('[CardioplegiaNotifications] scheduling failed: $e');
      debugPrint('$st');
    }
  }

  /// Cancels every reminder this feature owns.
  Future<void> cancelAll() async {
    if (!_initialised || kIsWeb) return;
    try {
      for (var i = 1; i <= maxScheduledOccurrences; i++) {
        await _plugin.cancel(id: _baseId + i);
      }
    } catch (e) {
      debugPrint('[CardioplegiaNotifications] cancel failed: $e');
    }
  }

  /// Posts an immediate notification. Used by the "test alert" button on
  /// every platform, and on web additionally by the ticker when the trigger
  /// point is reached, since web cannot schedule ahead.
  Future<void> showNow({
    required bool sound,
    required bool vibration,
    required String title,
    required String body,
  }) async {
    await ensureReady();
    if (!_initialised) return;
    if (kIsWeb) {
      await WebNotifications.show(title, body);
      // Propagate so the UI can show why nothing appeared.
      lastError = WebNotifications.lastError;
      return;
    }
    try {
      await _plugin.show(
        id: _baseId,
        title: title,
        body: body,
        notificationDetails: _details(sound: sound, vibration: vibration),
      );
    } catch (e) {
      debugPrint('[CardioplegiaNotifications] test notification failed: $e');
    }
  }
}
