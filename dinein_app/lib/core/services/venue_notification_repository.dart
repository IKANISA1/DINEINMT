import '../models/models.dart';
import 'app_notification_service.dart'
    if (dart.library.html) 'app_notification_service_web.dart';
import 'auth_repository.dart';
import 'dinein_api_service.dart';

class VenueNotificationRepository {
  VenueNotificationRepository._();

  static final instance = VenueNotificationRepository._();

  Map<String, dynamic> _venueSessionPayload() {
    final session = AuthRepository.instance.currentVenueSession;
    if (session == null || session.accessToken.isEmpty) return const {};
    return {
      'venue_session': {'access_token': session.accessToken},
    };
  }

  Future<VenueNotificationSettings> getSettings(String venueId) async {
    final data = await DineinApiService.invoke(
      'get_venue_notification_settings',
      payload: {'venueId': venueId, ..._venueSessionPayload()},
    );

    return data is Map<String, dynamic>
        ? VenueNotificationSettings.fromJson(data)
        : const VenueNotificationSettings();
  }

  Future<VenueNotificationSettings> updateSettings(
    String venueId,
    VenueNotificationSettings settings,
  ) async {
    final data = await DineinApiService.invoke(
      'update_venue_notification_settings',
      payload: {
        'venueId': venueId,
        'settings': settings.toJson(),
        ..._venueSessionPayload(),
      },
    );

    final next = data is Map<String, dynamic>
        ? VenueNotificationSettings.fromJson(data)
        : settings;
    final session = AuthRepository.instance.currentVenueSession;
    if (session != null && session.venueId == venueId) {
      await AppNotificationService.handleVenuePreferencesUpdated(session, next);
    }
    return next;
  }
}
