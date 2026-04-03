import 'package:flutter/foundation.dart';

import 'auth_repository.dart';
import '../config/country_runtime.dart';
import 'supabase_config.dart';

class DineinApiInvocation {
  final Map<String, String> headers;
  final Map<String, dynamic> body;

  const DineinApiInvocation({required this.headers, required this.body});
}

/// Thin wrapper around the deployed `dinein-api` edge function.
class DineinApiService {
  DineinApiService._();

  @visibleForTesting
  static DineinApiInvocation buildInvocation(
    String action, {
    Map<String, dynamic>? payload,
    bool useAdminSession = false,
    String? userAccessToken,
    String? venueAccessToken,
    String? adminAccessToken,
  }) {
    final headers = <String, String>{};
    final bodyPayload = <String, dynamic>{
      'action': action,
      'country': CountryRuntime.config.country.code,
      if (payload != null) ...payload,
    };

    if (useAdminSession) {
      if (adminAccessToken == null || adminAccessToken.isEmpty) {
        throw Exception('Admin session required');
      }
      headers['Authorization'] = 'Bearer $adminAccessToken';
      return DineinApiInvocation(headers: headers, body: bodyPayload);
    }

    if (userAccessToken != null && userAccessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $userAccessToken';
    }

    // Venue owner auth must travel in the body because the access token is a
    // custom JWT, not a Supabase user session. Keep including it even when a
    // regular user session exists in the same browser.
    if (venueAccessToken != null &&
        venueAccessToken.isNotEmpty &&
        !bodyPayload.containsKey('venue_session')) {
      bodyPayload['venue_session'] = {'access_token': venueAccessToken};
    }

    return DineinApiInvocation(headers: headers, body: bodyPayload);
  }

  static Future<dynamic> invoke(
    String action, {
    Map<String, dynamic>? payload,
    bool useAdminSession = false,
  }) async {
    final request = buildInvocation(
      action,
      payload: payload,
      useAdminSession: useAdminSession,
      userAccessToken: AuthRepository.instance.currentSession?.accessToken,
      venueAccessToken:
          AuthRepository.instance.currentVenueSession?.accessToken,
      adminAccessToken:
          AuthRepository.instance.currentAdminSession?.accessToken,
    );

    final response = await SupabaseConfig.client.functions.invoke(
      'dinein-api',
      headers: request.headers.isEmpty ? null : request.headers,
      body: request.body,
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
