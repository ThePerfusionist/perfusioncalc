// Non-web stub for the browser Notification API.
//
// Mobile/desktop builds route notifications through
// flutter_local_notifications instead (see notification_service.dart), so
// every entry point here is a no-op. The stub exists purely so the shared
// service can call these without conditional code at every call site.

class WebNotifications {
  static String? lastError;

  /// Whether the browser exposes the Notification API at all.
  static bool get isSupported => false;

  /// Whether the user has already granted permission.
  static bool get isGranted => false;

  /// Current permission state, for diagnostics ('granted'/'denied'/'default').
  static String get permission => 'unsupported';

  static Future<bool> requestPermission() async => false;

  static Future<void> show(String title, String body) async {}
}
