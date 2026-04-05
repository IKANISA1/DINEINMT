import 'package:flutter/foundation.dart';

import 'web_badge_service_stub.dart'
    if (dart.library.js_interop) 'web_badge_service_web.dart' as impl;

/// Web Badging API integration.
///
/// Sets the app icon badge (unread count) for installed PWAs.
/// No-op on platforms that don't support the Badging API.
class WebBadgeService {
  WebBadgeService._();

  static final WebBadgeService instance = WebBadgeService._();

  /// Set the app badge to [count].
  /// If [count] is 0, clears the badge.
  void setBadge(int count) {
    if (!kIsWeb) return;
    if (count <= 0) {
      clearBadge();
      return;
    }
    impl.setAppBadge(count);
  }

  /// Clear the app badge.
  void clearBadge() {
    if (!kIsWeb) return;
    impl.clearAppBadge();
  }
}
