import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

class FirebaseRuntimeService {
  FirebaseRuntimeService._();

  static Future<bool>? _initializing;
  static bool _initialized = false;

  static Future<bool> ensureInitialized() {
    if (_initialized) return Future.value(true);
    if (_initializing != null) return _initializing!;

    _initializing = _initialize();
    return _initializing!;
  }

  static Future<bool> _initialize() async {
    if (!DefaultFirebaseOptions.hasCurrentPlatformConfig) {
      debugPrint(
        '[firebase] Initialization skipped: platform config is missing or '
        'still contains placeholder values.',
      );
      _initializing = null;
      return false;
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _initialized = true;
      _initializing = null;
      return true;
    } catch (error, stackTrace) {
      debugPrint('[firebase] Initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _initializing = null;
      return false;
    }
  }
}
