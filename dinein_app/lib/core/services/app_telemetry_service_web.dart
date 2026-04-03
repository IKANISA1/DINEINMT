import 'app_telemetry_shared.dart';

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
