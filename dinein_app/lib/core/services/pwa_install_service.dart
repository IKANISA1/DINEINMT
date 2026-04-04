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
/// The JS side (index.html) captures the `beforeinstallprompt` event and
/// stores it at `window.__dineinDeferredInstallPrompt`. This service calls
/// `.prompt()` on that object via JS interop at the right moment.
class PwaInstallService {
  PwaInstallService._();

  static bool _promptShown = false;
  static bool _isInstallable = false;
  static Timer? _engagementTimer;

  /// Initialize the engagement timer. Call once from app startup.
  static void init() {
    if (!kIsWeb) return;

    _checkInstallable();

    // Start a 45-second engagement timer
    _engagementTimer?.cancel();
    _engagementTimer = Timer(const Duration(seconds: 45), () {
      _checkInstallable();
      triggerIfEligible(reason: 'engagement_timer');
    });
  }

  /// Call when a significant engagement event happens.
  /// [reason] is for logging: 'order_placed', 'cart_2_items', 'engagement_timer'
  static void triggerIfEligible({required String reason}) {
    if (!kIsWeb) return;
    if (_promptShown) return;

    _checkInstallable();
    if (!_isInstallable) return;

    _promptShown = true;
    _engagementTimer?.cancel();

    debugPrint('[pwa-install] Triggering install prompt (reason: $reason)');
    unawaited(
      AppTelemetryService.trackGuestEvent(
        'pwa_install_prompt_requested',
        details: {'reason': reason},
      ),
    );

    try {
      platform.triggerInstallPrompt();
    } catch (e) {
      debugPrint('[pwa-install] Error: $e');
    }
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
}
