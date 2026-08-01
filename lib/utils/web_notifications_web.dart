// Browser Notification API wrapper (web build only).
//
// TWO DELIVERY PATHS, IN THIS ORDER
// 1. The Notification constructor - works on every desktop browser and needs
//    no service worker, so it costs nothing to try first.
// 2. ServiceWorkerRegistration.showNotification() - required on Chrome for
//    Android, where the constructor throws "Illegal constructor. Use
//    ServiceWorkerRegistration.showNotification() instead". Flutter ships a
//    service worker for the PWA, so this is normally available there.
//    NOTE: a click on a notification raised this way is delivered to the
//    worker, not to this page, so `onclick` below cannot work for it. The
//    'notificationclick' handler in web/sw.js focuses (or opens) the window
//    instead - do not remove one without the other.
//
// Ordering matters: trying the service worker first would add its timeout on
// desktop setups that do not need it at all.
//
// SCOPE - and its honest limit:
// A browser can only raise a notification while the page is alive. There is
// no way to schedule one for later without a push server, which would defeat
// the point of an offline-capable clinical tool. The web build therefore
// fires the reminder from the app's own one-second ticker, which keeps
// running while the tab is open - including in a background tab (browsers
// throttle those to roughly once per minute, fine for a minute-resolution
// reminder). Closing the browser stops the reminder; Android schedules with
// the OS and is unaffected.
//
// Note that a system notification can still be suppressed by OS settings or
// "do not disturb" without any error surfacing here - which is why the app
// also shows its own in-app banner (widgets/in_app_alert.dart).

// WHY THIS FILE STILL EXISTS AFTER PLUGIN v22 (audit NEU-5)
// flutter_local_notifications gained web support in 22.0.0, so there are now
// two ways to raise a web notification. This one is kept deliberately:
// the plugin cannot schedule ahead on web either (no push server, same
// browser limitation as described above), so it would buy no capability -
// while the ticker-driven path here is what the cardioplegia screen is built
// around, and it carries the lastError diagnostics the UI shows. Every call
// site branches on kIsWeb, so nothing collides.
// If this is ever revisited, note that a web bugfix has to be considered
// twice - the missing notificationclick handler in web/sw.js was exactly
// such a case.

import 'dart:js_interop';
import 'package:web/web.dart' as web;

class WebNotifications {
  /// Last failure, surfaced in the UI. Swallowing these silently previously
  /// made a broken notification indistinguishable from a working one.
  static String? lastError;

  static bool get isSupported {
    try {
      // Touching the static getter throws if the API is missing (older or
      // hardened browsers, or a non-secure context).
      web.Notification.permission;
      return true;
    } catch (e) {
      lastError = 'Notification API unavailable: $e';
      return false;
    }
  }

  static String get permission {
    try {
      return web.Notification.permission;
    } catch (_) {
      return 'unsupported';
    }
  }

  static bool get isGranted => permission == 'granted';

  static Future<bool> requestPermission() async {
    try {
      final result = await web.Notification.requestPermission().toDart;
      final granted = result.toDart == 'granted';
      if (!granted) lastError = 'Permission not granted (${result.toDart}).';
      return granted;
    } catch (e) {
      lastError = 'Permission request failed: $e';
      return false;
    }
  }

  static Future<void> show(String title, String body) async {
    if (!isGranted) {
      lastError = 'Notifications not permitted (state: $permission).';
      return;
    }
    // A fixed tag makes a new reminder replace the previous one instead of
    // stacking up identical notifications.
    // Without `icon` Chrome falls back to a generic browser symbol; the
    // 192px app icon is already in the service worker's app-shell precache
    // (same ?v=9 query), so this costs no extra request.
    final options = web.NotificationOptions(
      body: body,
      tag: 'cardioplegia_redose',
      icon: 'icons/Icon-192.png?v=9',
    );

    // Path 1: the plain constructor. Works on every desktop browser and
    // needs no service worker, so it is tried first - going through the
    // service worker there would only add its timeout for no benefit.
    try {
      final n = web.Notification(title, options);
      // Clicking the notification brings the app's window to the front.
      // This also gives the object a genuine use: a write-only field would
      // be flagged as unused by the analyzer, and an unused result could in
      // principle be dropped by the compiler.
      n.onclick = ((web.Event _) {
        web.window.focus();
        n.close();
      }).toJS;
      lastError = null;
      return;
    } catch (e) {
      // Chrome for Android throws here ("Illegal constructor"), which is
      // exactly the case the service worker path below covers.
      lastError = 'Notification constructor failed: $e';
    }

    // Path 2: service worker - required on Chrome for Android.
    try {
      final reg = await web.window.navigator.serviceWorker.ready.toDart
          // Without a registered service worker `ready` never completes, so
          // never await it unbounded.
          .timeout(const Duration(seconds: 2));
      await reg.showNotification(title, options).toDart;
      lastError = null;
    } catch (e) {
      lastError = 'Notification failed. Constructor and service worker both '
          'unavailable: $e';
    }
  }
}
