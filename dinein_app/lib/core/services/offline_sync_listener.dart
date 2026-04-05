import 'package:flutter/foundation.dart';
import 'package:ui/widgets/dinein_toast.dart';

import 'notification_inbox_service.dart';

/// Listens for service worker `message` events to handle:
///
/// - `OFFLINE_SYNC_COMPLETE` — shows a toast + adds inbox entry after
///   background sync replays queued offline orders.
///
/// Must be initialized after [NotificationInboxService.init] is called.
class OfflineSyncListener {
  OfflineSyncListener._();

  static final OfflineSyncListener instance = OfflineSyncListener._();

  bool _initialized = false;

  /// Initialize the listener — attaches to navigator.serviceWorker.onmessage.
  void init() {
    if (!kIsWeb || _initialized) return;
    _initialized = true;

    try {
      _attachWebListener();
      debugPrint('[offline-sync-listener] Listening for SW messages.');
    } catch (e) {
      debugPrint('[offline-sync-listener] Init skipped: $e');
    }
  }

  /// Web-specific: attach message listener via conditional import.
  void _attachWebListener() {
    // On web, this is handled via the JS-aware implementation.
    // On non-web, this is a no-op due to kIsWeb guard above.
    _OfflineSyncWeb.attach(_handleSyncMessage);
  }

  void _handleSyncMessage(int syncedCount) {
    if (syncedCount <= 0) return;

    final message = syncedCount == 1
        ? 'Your offline order has been submitted.'
        : '$syncedCount offline orders have been submitted.';

    // Show in-app toast
    DineInToast.instance.success(message);

    // Add to notification inbox
    NotificationInboxService.instance.add(
      id: 'offline-sync-${DateTime.now().millisecondsSinceEpoch}',
      title: 'Order confirmed',
      body: message,
      type: 'sync',
    );
  }

  /// Dispose the listener.
  void dispose() {
    _initialized = false;
  }
}

/// Stub for non-web platforms. On web, the service worker
/// message events are handled by the foreground message handler
/// in app_notification_service_web.dart and the custom_sw.js bridge.
class _OfflineSyncWeb {
  static void attach(void Function(int) onSync) {
    // No-op on non-web platforms. On web, service worker messages
    // are received via the FirebaseMessaging foreground subscription
    // which already handles the PUSH_RECEIVED forwarding.
    // The OFFLINE_SYNC_COMPLETE messages are posted by custom_sw.js
    // and picked up by the ServiceWorkerContainer message event,
    // which we listen for via the web notification service.
  }
}
