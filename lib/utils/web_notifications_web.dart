// Browser Notification API wrapper (web build only).
//
// TWO DELIVERY PATHS, IN THIS ORDER
// 1. The Notification constructor - works on every desktop browser and needs
//    no service worker, so it costs nothing to try first.
// 2. ServiceWorkerRegistration.showNotification() - required on Chrome for
//    Android, where the constructor throws "Illegal constructor. Use
//    ServiceWorkerRegistration.showNotification() instead". Flutter ships a
//    service worker for the PWA, so this is normally available there.
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

import 'dart:js_interop';
import 'package:web/web.dart' as web;

class WebNotifications {
  /// Last failure, surfaced in the UI. Swallowing these silently previously
  /// made a broken notification indistinguishable from a working one.
  static String? lastError;

  /// Holds the most recent notification object. Without a live reference,
  /// dart2js may treat the constructor call as dead code in release builds
  /// and optimise it away - the notification then simply never appears.
  static web.Notification? _last;

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
    final options = web.NotificationOptions(body: body, tag: 'cardioplegia_redose');

    // Path 1: the plain constructor. Works on every desktop browser and
    // needs no service worker, so it is tried first - going through the
    // service worker there would only add its timeout for no benefit.
    try {
      // The result is kept in a field on purpose: without a live reference
      // dart2js may treat this constructor call as dead code in a release
      // build and drop it, and the notification then never appears.
      _last = web.Notification(title, options);
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
