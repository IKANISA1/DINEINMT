import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'package:dinein_app/firebase_options.dart';

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
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      _initialized = true;
      _initializing = null;
      return true;
    }

    if (!kIsWeb) {
      try {
        await Firebase.initializeApp();
        _initialized = true;
        _initializing = null;
        return true;
      } catch (error, stackTrace) {
        debugPrint('[firebase] Native initialization unavailable: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    if (!DefaultFirebaseOptions.hasCurrentPlatformConfig) {
      debugPrint(
        '[firebase] Initialization skipped: native config is unavailable and '
        'fallback firebase_options.dart does not contain usable values.',
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
      debugPrint('[firebase] Fallback initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _initializing = null;
      return false;
    }
  }
}
