import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'package:dinein_app/core/services/app_telemetry_shared.dart';
import 'firebase_runtime_service.dart';
import 'package:dinein_app/core/services/supabase_config.dart';

/// Initializes production telemetry without blocking app startup when provider
/// credentials are missing or still carry placeholder values.
class AppTelemetryService {
  AppTelemetryService._();

  static bool _initialized = false;
  static bool _enabled = false;

  static bool get isEnabled => _enabled;
  static String? get sessionId => currentGuestTelemetrySessionId();

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await initializeGuestTelemetrySession();
    final firebaseReady = await FirebaseRuntimeService.ensureInitialized();
    if (!firebaseReady) {
      return;
    }

    try {
      final crashlytics = FirebaseCrashlytics.instance;
      await crashlytics.setCrashlyticsCollectionEnabled(kReleaseMode);

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        crashlytics.recordFlutterFatalError(details);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        crashlytics.recordError(error, stack, fatal: true);
        return true;
      };

      _enabled = true;
      debugPrint('[telemetry] Firebase Crashlytics enabled.');
    } catch (error, stackTrace) {
      debugPrint('[telemetry] Firebase initialization skipped: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> trackGuestEvent(
    String eventName, {
    String? route,
    String? venueId,
    String? menuItemId,
    String? orderId,
    Map<String, Object?> details = const {},
  }) {
    if (!SupabaseConfig.isConfigured || !SupabaseConfig.isInitialized) {
      return Future<void>.value();
    }
    return recordGuestTelemetryEvent(
      eventName,
      route: route,
      venueId: venueId,
      menuItemId: menuItemId,
      orderId: orderId,
      details: details,
    );
  }
}
