import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Conditional import for web-specific connectivity detection
import 'connectivity_provider_stub.dart'
    if (dart.library.js_interop) 'connectivity_provider_web.dart' as platform;

/// Whether the device currently has network connectivity.
///
/// On web: listens to `navigator.onLine` and the browser online/offline events.
/// On mobile: defaults to `true` (use platform connectivity plugins
/// for richer detection if needed).
final connectivityProvider = NotifierProvider<ConnectivityNotifier, bool>(
  ConnectivityNotifier.new,
);

/// Notifier that tracks online/offline status.
class ConnectivityNotifier extends Notifier<bool> {
  StreamSubscription<bool>? _subscription;

  @override
  bool build() {
    if (!kIsWeb) return true;

    // Listen for connectivity changes
    _subscription = platform.connectivityStream().listen((online) {
      if (state != online) {
        state = online;
        debugPrint('[connectivity] ${online ? "online" : "offline"}');
      }
    });

    // Clean up on dispose
    ref.onDispose(() => _subscription?.cancel());

    // Initial state from platform
    return platform.isOnline();
  }
}
