import 'dart:async';
import 'dart:math';

import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/infrastructure/firebase_runtime_service.dart';
import 'package:dinein_app/core/router/app_router.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web/web.dart' as web;

import 'supabase_config.dart';
import 'notification_inbox_service.dart';
import 'package:ui/widgets/dinein_toast.dart';

const _venueOrdersRoute = AppRoutePaths.venueOrders;
const _venueWavesRoute = AppRoutePaths.venueWaves;
const _webVapidKey = String.fromEnvironment('FCM_WEB_VAPID_KEY');

Future<void> firebaseMessagingBackgroundHandler(Object message) async {}

class AppNotificationService {
  AppNotificationService._();

  static const _deviceKeyStorageKey = 'dinein.push.device_key';
  static const _secureStorageTimeout = Duration(seconds: 1);
  static const _secureStorage = FlutterSecureStorage();

  static bool get venuePushAvailable => _validatedVapidKey != null;

  static bool _initialized = false;
  static Future<void>? _initializing;
  static bool _messagingAvailable = false;
  static bool _missingVapidLogged = false;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static VenueAccessSession? _activeVenueSession;
  static VenueNotificationSettings? _activeVenueSettings;

  static Future<void> initialize() async {
    if (_initialized) return;
    if (_initializing != null) return _initializing!;

    _initializing = _initializeInternal();
    await _initializing;
  }

  static Future<void> _initializeInternal() async {
    final firebaseReady = await FirebaseRuntimeService.ensureInitialized();
    if (!firebaseReady) {
      _initializing = null;
      return;
    }

    try {
      _messagingAvailable = await FirebaseMessaging.instance.isSupported();
      if (!_messagingAvailable) {
        debugPrint('[notifications:web] Firebase Messaging is unsupported.');
        _initializing = null;
        return;
      }

      _foregroundSubscription = FirebaseMessaging.onMessage.listen(
        _handleForegroundMessage,
      );
      _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh
          .listen(_handleTokenRefresh);

      _initialized = true;
      debugPrint('[notifications:web] Firebase Messaging initialized.');
    } catch (error, stackTrace) {
      debugPrint('[notifications:web] Initialization skipped: $error');
      debugPrintStack(stackTrace: stackTrace);
      _messagingAvailable = false;
      _initialized = false;
    } finally {
      _initializing = null;
    }
  }

  static Future<void> handleVenueSessionUpdated(
    VenueAccessSession session,
  ) async {
    _activeVenueSession = session;
    await initialize();
    if (!_messagingAvailable) return;

    try {
      final settings = await _fetchVenueNotificationSettings(session);
      _activeVenueSettings = settings;
      await _syncVenuePushRegistration(session, settings);
    } catch (error, stackTrace) {
      debugPrint('[notifications:web] Venue sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> handleVenuePreferencesUpdated(
    VenueAccessSession session,
    VenueNotificationSettings settings,
  ) async {
    _activeVenueSession = session;
    _activeVenueSettings = settings;
    await initialize();
    if (!_messagingAvailable) return;

    try {
      await _syncVenuePushRegistration(session, settings);
    } catch (error, stackTrace) {
      debugPrint('[notifications:web] Preference sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> handleVenueSessionCleared(
    VenueAccessSession session,
  ) async {
    final currentSession = _activeVenueSession;
    _activeVenueSession = null;
    _activeVenueSettings = null;

    await initialize();
    if (!_messagingAvailable) return;

    try {
      await _unregisterPushDevice(currentSession ?? session);
    } catch (error, stackTrace) {
      debugPrint('[notifications:web] Device unregister failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
  }

  static Future<void> _handleTokenRefresh(String token) async {
    final session = _activeVenueSession;
    final settings = _activeVenueSettings;
    if (session == null || settings == null || token.trim().isEmpty) return;

    try {
      await _registerPushDevice(session, settings, token: token.trim());
    } catch (error, stackTrace) {
      debugPrint('[notifications:web] Token refresh sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? _stringData(message.data, 'title');
    if (title == null || title.trim().isEmpty) {
      return;
    }

    final body =
        notification?.body ??
        _stringData(message.data, 'body') ??
        'Open DineIn to review the latest venue activity.';

    // Resolve the navigation route from notification data
    final eventType = _stringData(message.data, 'event_type');
    final route = switch (eventType) {
      'new_order' => _venueOrdersRoute,
      'bell_request' => _venueWavesRoute,
      _ => _stringData(message.data, 'route'),
    };

    // Always add to notification inbox for persistence
    final notifType = switch (eventType) {
      'new_order' => 'order',
      'bell_request' => 'bell',
      _ => 'info',
    };

    await NotificationInboxService.instance.init();
    await NotificationInboxService.instance.add(
      id: message.messageId ?? '${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      body: body,
      url: route,
      type: notifType,
    );

    // Tab is visible → show in-app toast with contextual type
    if (web.document.hidden != true) {
      final toastType = switch (eventType) {
        'new_order' => ToastType.success,
        'bell_request' => ToastType.warning,
        _ => ToastType.info,
      };
      DineInToast.instance.show(
        message: '$title — $body',
        type: toastType,
        actionLabel: route != null ? 'VIEW' : null,
        onAction: route != null ? () => _navigateFromNotificationData(message.data) : null,
      );
      return;
    }

    // Tab is hidden → show OS notification
    if (web.Notification.permission != 'granted') {
      return;
    }

    try {
      web.Notification(
        title,
        web.NotificationOptions(
          body: body,
          icon: '/icons/Icon-192.png',
          badge: '/icons/Icon-maskable-192.png',
          tag: _notificationTag(message.data),
          requireInteraction: true,
        ),
      );
    } catch (error) {
      debugPrint('[notifications:web] Foreground notification skipped: $error');
    }
  }

  static Future<void> _syncVenuePushRegistration(
    VenueAccessSession session,
    VenueNotificationSettings settings,
  ) async {
    final vapidKey = _validatedVapidKey;
    if (vapidKey == null) {
      if (!_missingVapidLogged) {
        debugPrint(
          '[notifications:web] FCM_WEB_VAPID_KEY is missing; web push '
          'registration is disabled.',
        );
        _missingVapidLogged = true;
      }
      await _unregisterPushDevice(session);
      return;
    }

    if (!settings.orderPushEnabled) {
      await _unregisterPushDevice(session);
      return;
    }

    final permission = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      provisional: false,
      sound: true,
    );
    final authorized =
        permission.authorizationStatus == AuthorizationStatus.authorized ||
        permission.authorizationStatus == AuthorizationStatus.provisional;
    if (!authorized) {
      await _unregisterPushDevice(session);
      return;
    }

    final token = await FirebaseMessaging.instance.getToken(vapidKey: vapidKey);
    if (token == null || token.trim().isEmpty) {
      debugPrint('[notifications:web] FCM token unavailable.');
      return;
    }

    await _registerPushDevice(session, settings, token: token.trim());
  }

  static Future<void> _registerPushDevice(
    VenueAccessSession session,
    VenueNotificationSettings settings, {
    required String token,
  }) async {
    final deviceKey = await _deviceKey();
    await _invokeVenueAction(
      session,
      'register_push_device',
      payload: {
        'venueId': session.venueId,
        'deviceKey': deviceKey,
        'pushToken': token,
        'platform': 'web',
        'notificationsEnabled': settings.orderPushEnabled,
        'orderPushEnabled': settings.orderPushEnabled,
        'whatsAppUpdatesEnabled': settings.whatsAppUpdatesEnabled,
        'locale': WidgetsBinding.instance.platformDispatcher.locale
            .toLanguageTag(),
        'timeZone': DateTime.now().timeZoneName,
      },
    );
  }

  static Future<void> _unregisterPushDevice(VenueAccessSession session) async {
    final deviceKey = await _deviceKey();
    await _invokeVenueAction(
      session,
      'unregister_push_device',
      payload: {'venueId': session.venueId, 'deviceKey': deviceKey},
    );
  }

  static Future<VenueNotificationSettings> _fetchVenueNotificationSettings(
    VenueAccessSession session,
  ) async {
    final data = await _invokeVenueAction(
      session,
      'get_venue_notification_settings',
      payload: {'venueId': session.venueId},
    );
    return data is Map<String, dynamic>
        ? VenueNotificationSettings.fromJson(data)
        : const VenueNotificationSettings();
  }

  static Future<dynamic> _invokeVenueAction(
    VenueAccessSession session,
    String action, {
    Map<String, dynamic>? payload,
  }) async {
    final response = await SupabaseConfig.client.functions.invoke(
      'dinein-api',
      body: {
        'action': action,
        'venue_session': {'access_token': session.accessToken},
        if (payload != null) ...payload,
      },
    );

    final raw = response.data;
    if (raw is Map<String, dynamic>) {
      if (raw['error'] case final Object error) {
        throw Exception(error.toString());
      }
      if (raw.containsKey('data')) {
        return raw['data'];
      }
    }

    return raw;
  }

  static Future<String> _deviceKey() async {
    final existing = await _tryReadSecureValue(_deviceKeyStorageKey);
    if (existing != null && existing.trim().isNotEmpty) {
      return existing.trim();
    }

    final generated = _randomDeviceKey();
    await _tryWriteSecureValue(_deviceKeyStorageKey, generated);
    return generated;
  }

  static String _randomDeviceKey() {
    final random = Random.secure();
    final values = List<int>.generate(24, (_) => random.nextInt(256));
    return values
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  static Future<String?> _tryReadSecureValue(String key) async {
    try {
      return await _secureStorage.read(key: key).timeout(_secureStorageTimeout);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _tryWriteSecureValue(String key, String value) async {
    try {
      await _secureStorage
          .write(key: key, value: value)
          .timeout(_secureStorageTimeout);
    } catch (_) {
      // Ignore storage failures in test environments.
    }
  }

  static String? get _validatedVapidKey {
    final key = _webVapidKey.trim();
    if (key.isEmpty) return null;
    if (key.contains('REPLACE_WITH_ACTUAL_')) return null;
    if (key.toLowerCase().contains('your-vapid')) return null;
    if (key.length < 64) return null;
    return key;
  }

  static String? _stringData(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  static String _notificationTag(Map<String, dynamic> data) {
    final eventType = _stringData(data, 'event_type') ?? 'venue-alert';
    return 'dinein-$eventType';
  }

  static void _navigateFromNotificationData(Map<String, dynamic> data) {
    final route = _stringData(data, 'route');
    final eventType = _stringData(data, 'event_type');

    final resolvedRoute = switch (eventType) {
      'new_order' => _venueOrdersRoute,
      'bell_request' => _venueWavesRoute,
      _ => route,
    };

    if (resolvedRoute == null || resolvedRoute.isEmpty) return;

    try {
      appRouter.go(resolvedRoute);
    } catch (error) {
      debugPrint('[notifications:web] Navigation failed: $error');
    }
  }

  static Future<void> handleForegroundNotificationTap(
    Map<String, dynamic> data,
  ) async {
    _navigateFromNotificationData(data);
  }
}
