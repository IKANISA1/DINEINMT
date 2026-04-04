import 'app_telemetry_shared.dart';

const _webGuestTelemetryEnabled = bool.fromEnvironment(
  'ENABLE_WEB_GUEST_TELEMETRY',
  defaultValue: true,
);

class AppTelemetryService {
  AppTelemetryService._();

  static bool get isEnabled => true;
  static String? get sessionId => currentGuestTelemetrySessionId();

  static Future<void> initialize() async {
    await initializeGuestTelemetrySession();
  }

  static Future<void> trackGuestEvent(
    String eventName, {
    String? route,
    String? venueId,
    String? menuItemId,
    String? orderId,
    Map<String, Object?> details = const {},
  }) {
    if (!_webGuestTelemetryEnabled) {
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
