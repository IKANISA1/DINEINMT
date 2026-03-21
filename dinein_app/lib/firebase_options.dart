// File generated for Firebase configuration.
// Firebase project: gen-lang-client-0172279957
// Project number: 1074154147498

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  /// Returns `true` when the current platform has a real (non-placeholder)
  /// Firebase configuration available.
  static bool get hasCurrentPlatformConfig {
    try {
      final opts = currentPlatform;
      return !opts.apiKey.contains('REPLACE');
    } catch (_) {
      return false;
    }
  }

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web — '
        'this is a mobile-only app.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for '
          '${defaultTargetPlatform.name}',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBZWg0JT-v2Qpirp63RbsPqzB4JY2onfJw',
    appId: '1:1074154147498:android:1dd401b016b8c501dc4ad3',
    messagingSenderId: '1074154147498',
    projectId: 'gen-lang-client-0172279957',
    storageBucket: 'gen-lang-client-0172279957.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC3wczTXHP3fkryFydOTu6RIbxZ5vRUbg0',
    appId: '1:1074154147498:ios:f9338408dab88c45dc4ad3',
    messagingSenderId: '1074154147498',
    projectId: 'gen-lang-client-0172279957',
    storageBucket: 'gen-lang-client-0172279957.firebasestorage.app',
    iosBundleId: 'com.dineinmalta.app',
  );
}
