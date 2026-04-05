import 'dart:js_interop';

import 'package:flutter/foundation.dart';

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

    try {
      _setAppBadge(count);
    } catch (e) {
      debugPrint('[badge] setAppBadge not supported: $e');
    }
  }

  /// Clear the app badge.
  void clearBadge() {
    if (!kIsWeb) return;

    try {
      _clearAppBadge();
    } catch (e) {
      debugPrint('[badge] clearAppBadge not supported: $e');
    }
  }
}

// ─── JS Interop ─────────────────────────────────────

@JS('navigator.setAppBadge')
external void _setAppBadge(int count);

@JS('navigator.clearAppBadge')
external void _clearAppBadge();
