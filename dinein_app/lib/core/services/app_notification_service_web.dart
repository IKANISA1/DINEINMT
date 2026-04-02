import '../models/models.dart';

Future<void> firebaseMessagingBackgroundHandler(Object message) async {}

class AppNotificationService {
  AppNotificationService._();

  static Future<void> initialize() async {}

  static Future<void> handleVenueSessionUpdated(
    VenueAccessSession session,
  ) async {}

  static Future<void> handleVenuePreferencesUpdated(
    VenueAccessSession session,
    VenueNotificationSettings settings,
  ) async {}

  static Future<void> handleVenueSessionCleared(
    VenueAccessSession session,
  ) async {}

  static Future<void> dispose() async {}
}
