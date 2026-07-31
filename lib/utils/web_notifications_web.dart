// Browser Notification API wrapper (web build only).
//
// SCOPE - and its honest limit:
// A browser can only raise a notification while the page is alive. There is
// no way to schedule one for later without a service worker plus a push
// server, which would defeat the point of an offline-capable clinical tool.
// The web build therefore fires the reminder from the app's own one-second
// ticker, which keeps running while the tab is open - including when the tab
// is in the background (browsers throttle background timers to roughly once
// per minute, which is fine for a minute-resolution reminder).
//
// Consequence for the user, stated in the UI: on web the tab has to stay
// open. Closing the browser stops the reminder. Android schedules with the
// OS and is unaffected by this.

import 'dart:js_interop';
import 'package:web/web.dart' as web;

class WebNotifications {
  static bool get isSupported {
    try {
      // Touching the static getter throws if the API is missing (older or
      // hardened browsers, or a non-secure context).
      web.Notification.permission;
      return true;
    } catch (_) {
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
      return result.toDart == 'granted';
    } catch (_) {
      return false;
    }
  }

  static void show(String title, String body) {
    try {
      // A fixed tag makes a new reminder replace the previous one instead of
      // stacking up several identical notifications.
      web.Notification(
        title,
        web.NotificationOptions(body: body, tag: 'cardioplegia_redose'),
      );
    } catch (_) {
      // Never let a failed notification take down the calculation UI.
    }
  }
}
