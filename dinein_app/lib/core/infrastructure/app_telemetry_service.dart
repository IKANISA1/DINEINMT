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

  static Future<void> reportError(
    Object error,
    StackTrace stackTrace, {
    required String context,
    bool fatal = false,
    Map<String, Object?> details = const {},
  }) async {
    if (!_enabled) {
      _debugFallback(context, error, stackTrace, details: details, fatal: fatal);
      return;
    }

    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        fatal: fatal,
        reason: context,
        information: _crashlyticsInformation(details),
      );
    } catch (telemetryError, telemetryStackTrace) {
      _debugFallback(
        '$context (telemetry fallback)',
        telemetryError,
        telemetryStackTrace,
        details: {'original_error': error.toString(), ...details},
        fatal: fatal,
      );
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

  static Iterable<Object> _crashlyticsInformation(
    Map<String, Object?> details,
  ) sync* {
    for (final entry in details.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) continue;
      yield '$key=${entry.value}';
    }
  }

  static void _debugFallback(
    String context,
    Object error,
    StackTrace stackTrace, {
    required Map<String, Object?> details,
    required bool fatal,
  }) {
    final suffix = details.isEmpty ? '' : ' details=$details';
    debugPrint(
      '[telemetry] ${fatal ? 'fatal' : 'non-fatal'} error in $context: '
      '$error$suffix',
    );
    debugPrintStack(stackTrace: stackTrace);
  }
}
