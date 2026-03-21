import 'auth_repository.dart';
import 'supabase_config.dart';

/// Thin wrapper around the deployed `dinein-api` edge function.
class DineinApiService {
  DineinApiService._();

  static Future<dynamic> invoke(
    String action, {
    Map<String, dynamic>? payload,
    bool useAdminSession = false,
  }) async {
    final headers = <String, String>{};
    final bodyPayload = <String, dynamic>{
      'action': action,
      if (payload != null) ...payload,
    };

    if (useAdminSession) {
      final adminSession = AuthRepository.instance.currentAdminSession;
      if (adminSession == null) {
        throw Exception('Admin session required');
      }
      headers['Authorization'] = 'Bearer ${adminSession.accessToken}';
    } else {
      // Only set Authorization header for real Supabase auth sessions.
      // Venue session tokens are custom JWTs that Supabase's gateway
      // rejects with 401, so we pass them inside the body payload instead.
      final userSession = AuthRepository.instance.currentSession;
      final accessToken = userSession?.accessToken;
      if (accessToken != null && accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
      } else {
        // Inject venue session into request body (not header).
        // The edge function handler reads body.venue_session for auth.
        final venueSession = AuthRepository.instance.currentVenueSession;
        if (venueSession != null &&
            venueSession.accessToken.isNotEmpty &&
            !bodyPayload.containsKey('venue_session')) {
          bodyPayload['venue_session'] = {
            'access_token': venueSession.accessToken,
            'venue_id': venueSession.venueId,
            'contact_phone': venueSession.whatsAppNumber,
          };
        }
      }
    }

    final response = await SupabaseConfig.client.functions.invoke(
      'dinein-api',
      headers: headers.isEmpty ? null : headers,
      body: bodyPayload,
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
}
