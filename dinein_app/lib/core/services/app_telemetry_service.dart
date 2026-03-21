import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// Initializes production telemetry without blocking app startup when provider
/// credentials are missing or still carry placeholder values.
class AppTelemetryService {
  AppTelemetryService._();

  static bool _initialized = false;
  static bool _enabled = false;

  static bool get isEnabled => _enabled;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (!DefaultFirebaseOptions.hasCurrentPlatformConfig) {
      debugPrint(
        '[telemetry] Firebase disabled: platform config is missing or still '
        'contains placeholder values.',
      );
      return;
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

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
}
