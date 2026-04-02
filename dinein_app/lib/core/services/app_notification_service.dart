import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/models.dart';
import '../router/app_router.dart';
import '../router/app_routes.dart';
import 'firebase_runtime_service.dart';
import 'supabase_config.dart';

const _venueOrdersRoute = AppRoutePaths.venueOrders;
const _venueWavesRoute = AppRoutePaths.venueWaves;

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await FirebaseRuntimeService.ensureInitialized();
}

class AppNotificationService {
  AppNotificationService._();

  static const _deviceKeyStorageKey = 'dinein.push.device_key';
  static const _secureStorageTimeout = Duration(seconds: 1);
  static const _secureStorage = FlutterSecureStorage();

  static const AndroidNotificationChannel _venueAlertChannel =
      AndroidNotificationChannel(
        'venue_operational_alerts',
        'Venue Operational Alerts',
        description: 'New order and table alert notifications for venue staff.',
        importance: Importance.max,
      );

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static Future<void>? _initializing;
  static bool _messagingAvailable = false;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
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
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      const initializationSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );

      await _localNotifications.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (response) {
          _handleNotificationTapPayload(response.payload);
        },
      );

      final androidImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidImplementation?.createNotificationChannel(
        _venueAlertChannel,
      );

      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: false,
            badge: true,
            sound: true,
          );

      _foregroundSubscription = FirebaseMessaging.onMessage.listen(
        _handleForegroundMessage,
      );
      _messageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        _handleOpenedRemoteMessage,
      );
      _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh
          .listen(_handleTokenRefresh);

      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        _handleOpenedRemoteMessage(initialMessage);
      }

      _messagingAvailable = true;
      _initialized = true;
      debugPrint('[notifications] Firebase Messaging initialized.');
    } catch (error, stackTrace) {
      debugPrint('[notifications] Initialization skipped: $error');
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
      debugPrint('[notifications] Venue sync failed: $error');
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
      debugPrint('[notifications] Preference sync failed: $error');
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
      debugPrint('[notifications] Device unregister failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _messageOpenedSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
  }

  static Future<void> _handleTokenRefresh(String token) async {
    final session = _activeVenueSession;
    final settings = _activeVenueSettings;
    if (session == null || settings == null || token.trim().isEmpty) return;

    try {
      await _registerPushDevice(session, settings, token: token.trim());
    } catch (error, stackTrace) {
      debugPrint('[notifications] Token refresh sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'Venue alert';
    final body =
        notification?.body ??
        message.data['body'] ??
        'Open DineIn to review the latest venue activity.';

    final payload = jsonEncode(message.data);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _venueAlertChannel.id,
        _venueAlertChannel.name,
        channelDescription: _venueAlertChannel.description,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  static void _handleOpenedRemoteMessage(RemoteMessage message) {
    _navigateFromNotificationData(message.data);
  }

  static void _handleNotificationTapPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      _navigateFromNotificationData(decoded);
    } catch (error) {
      debugPrint('[notifications] Invalid tap payload: $error');
    }
  }

  static void _navigateFromNotificationData(Map<String, dynamic> data) {
    final route = (data['route'] as String?)?.trim();
    final eventType = (data['event_type'] as String?)?.trim();

    final resolvedRoute = switch (eventType) {
      'new_order' => _venueOrdersRoute,
      'bell_request' => _venueWavesRoute,
      _ => route,
    };

    if (resolvedRoute == null || resolvedRoute.isEmpty) return;

    try {
      appRouter.go(resolvedRoute);
    } catch (error) {
      debugPrint('[notifications] Navigation failed: $error');
    }
  }

  static Future<void> _syncVenuePushRegistration(
    VenueAccessSession session,
    VenueNotificationSettings settings,
  ) async {
    final platform = _pushPlatform();
    if (platform == null) {
      debugPrint('[notifications] Push registration skipped on this platform.');
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

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.trim().isEmpty) {
      debugPrint('[notifications] FCM token unavailable.');
      return;
    }

    await _registerPushDevice(session, settings, token: token.trim());
  }

  static Future<void> _registerPushDevice(
    VenueAccessSession session,
    VenueNotificationSettings settings, {
    required String token,
  }) async {
    final platform = _pushPlatform();
    if (platform == null) return;

    final deviceKey = await _deviceKey();
    await _invokeVenueAction(
      session,
      'register_push_device',
      payload: {
        'venueId': session.venueId,
        'deviceKey': deviceKey,
        'pushToken': token,
        'platform': platform,
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
        'venue_session': {
          'access_token': session.accessToken,
        },
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

  static String? _pushPlatform() {
    if (kIsWeb) return null;

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => null,
    };
  }
}
