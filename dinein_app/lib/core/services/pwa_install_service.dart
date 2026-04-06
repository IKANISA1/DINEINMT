import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:dinein_app/core/services/app_telemetry.dart';

// Conditional import — uses the web implementation on web, stub elsewhere
import 'pwa_install_stub.dart'
    if (dart.library.js_interop) 'pwa_install_web.dart' as platform;

/// Engagement-based PWA install prompt service (G-21).
///
/// Rules (per STARTER RULES §2):
/// - Never show on first paint.
/// - Show only after meaningful engagement:
///   • After order placed, OR
///   • After 2+ items added to cart, OR
///   • After ~45s browsing.
/// - Never show repeatedly (max once per session).
/// - Only runs on web platform.
///
/// **Browser requirement:** `prompt()` MUST be called from a user gesture
/// (click/tap). Timer-based and programmatic triggers will throw
/// `NotAllowedError`. This service marks *eligibility* via [_showBanner],
/// then the UI shows a banner/button the user taps.
class PwaInstallService {
  PwaInstallService._();

  static bool _promptShown = false;
  static bool _isInstallable = false;
  static bool _showBanner = false;
  static Timer? _engagementTimer;

  /// Stream controller that fires when the install banner should appear.
  static final _bannerController = StreamController<bool>.broadcast();

  /// Listen for install banner visibility changes.
  static Stream<bool> get bannerStream => _bannerController.stream;

  /// Whether the install banner should currently be shown.
  static bool get shouldShowBanner =>
      kIsWeb && _showBanner && _isInstallable && !_promptShown;

  /// Initialize the engagement timer. Call once from app startup.
  static void init() {
    if (!kIsWeb) return;

    _checkInstallable();

    // Start a 45-second engagement timer.
    // When it fires, we DON'T call prompt() (browser forbids it without
    // a gesture). Instead we flag eligibility so the UI can show a banner.
    _engagementTimer?.cancel();
    _engagementTimer = Timer(const Duration(seconds: 45), () {
      _checkInstallable();
      _markEligible(reason: 'engagement_timer');
    });
  }

  /// Call when a significant engagement event happens.
  /// This marks the user eligible and shows the install banner.
  /// [reason] is for logging: 'order_placed', 'cart_2_items', 'engagement_timer'
  static void triggerIfEligible({required String reason}) {
    if (!kIsWeb) return;
    if (_promptShown) return;

    _checkInstallable();
    if (!_isInstallable) return;

    _markEligible(reason: reason);
  }

  /// Internal: mark as eligible and notify listeners to show the banner.
  static void _markEligible({required String reason}) {
    if (_showBanner || _promptShown) return;
    if (!_isInstallable) return;

    _showBanner = true;
    _engagementTimer?.cancel();

    debugPrint('[pwa-install] Eligible for install prompt (reason: $reason)');
    unawaited(
      AppTelemetryService.trackGuestEvent(
        'pwa_install_prompt_eligible',
        details: {'reason': reason},
      ),
    );

    _bannerController.add(true);
  }

  /// Call this from a user gesture (tap handler) to actually trigger the
  /// browser install prompt. Returns true if the prompt was shown.
  static bool promptFromUserGesture() {
    if (!kIsWeb || _promptShown || !_isInstallable) return false;

    _promptShown = true;
    _showBanner = false;
    _bannerController.add(false);

    debugPrint('[pwa-install] Triggering install prompt from user gesture');
    unawaited(
      AppTelemetryService.trackGuestEvent(
        'pwa_install_prompt_triggered',
        details: {},
      ),
    );

    try {
      platform.triggerInstallPrompt();
      return true;
    } catch (e) {
      debugPrint('[pwa-install] Error: $e');
      return false;
    }
  }

  /// Dismiss the install banner without triggering the prompt.
  static void dismissBanner() {
    _showBanner = false;
    _promptShown = true; // Don't show again this session
    _bannerController.add(false);
  }

  /// Whether an install prompt is available and hasn't been shown yet.
  static bool get canPrompt => kIsWeb && _isInstallable && !_promptShown;

  /// Clean up resources.
  static void dispose() {
    _engagementTimer?.cancel();
  }

  static void _checkInstallable() {
    if (!kIsWeb) return;
    try {
      _isInstallable = platform.hasDeferredPrompt();
    } catch (_) {
      _isInstallable = false;
    }
  }

  /// Update PWA app icon badge with cart item count.
  static void updateCartBadgeCount(int count) {
    if (!kIsWeb) return;
    try {
      if (count > 0) {
        platform.setAppBadge(count);
      } else {
        platform.clearAppBadge();
      }
    } catch (_) {}
  }
}
