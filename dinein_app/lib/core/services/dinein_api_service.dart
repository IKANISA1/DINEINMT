import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_repository.dart';
import 'package:core_pkg/config/country_runtime.dart';
import 'supabase_config.dart';

/// User-friendly exception thrown by [DineinApiService].
///
/// Carries a short [message] safe to display in UI, plus the original [cause]
/// for logging/Crashlytics.
class DineinApiException implements Exception {
  final String message;
  final String action;
  final Object? cause;

  const DineinApiException(this.message, {required this.action, this.cause});

  @override
  String toString() => 'DineinApiException($action): $message';
}

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
    Map<String, String>? extraHeaders,
    bool useAdminSession = false,
    String? userAccessToken,
    String? venueAccessToken,
    String? adminAccessToken,
  }) {
    final headers = <String, String>{
      if (extraHeaders != null) ...extraHeaders,
    };
    final bodyPayload = <String, dynamic>{
      'action': action,
      'country': CountryRuntime.config.country.code,
      if (payload != null) ...payload,
    };

    if (useAdminSession) {
      if (adminAccessToken == null || adminAccessToken.isEmpty) {
        throw DineinApiException(
          'Admin session expired. Please sign in again.',
          action: action,
        );
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
    Map<String, String>? extraHeaders,
    bool useAdminSession = false,
  }) async {
    final request = buildInvocation(
      action,
      payload: payload,
      extraHeaders: extraHeaders,
      useAdminSession: useAdminSession,
      userAccessToken: AuthRepository.instance.currentSession?.accessToken,
      venueAccessToken:
          AuthRepository.instance.currentVenueSession?.accessToken,
      adminAccessToken:
          AuthRepository.instance.currentAdminSession?.accessToken,
    );

    try {
      final response = await SupabaseConfig.client.functions.invoke(
        'dinein-api',
        headers: request.headers.isEmpty ? null : request.headers,
        body: request.body,
      );

      final raw = response.data;
      if (raw is Map<String, dynamic>) {
        if (raw['error'] case final Object error) {
          throw DineinApiException(
            error.toString(),
            action: action,
            cause: raw,
          );
        }
        if (raw.containsKey('data')) {
          return raw['data'];
        }
      }

      return raw;
    } on DineinApiException {
      rethrow;
    } on SocketException catch (e) {
      throw DineinApiException(
        'No internet connection. Please check your network and try again.',
        action: action,
        cause: e,
      );
    } on AuthException catch (e) {
      throw DineinApiException(
        'Your session has expired. Please sign in again.',
        action: action,
        cause: e,
      );
    } on FunctionException catch (e) {
      throw DineinApiException(
        'Service temporarily unavailable. Please try again shortly.',
        action: action,
        cause: e,
      );
    } catch (e) {
      // FormatException, TypeError, TimeoutException, etc.
      throw DineinApiException(
        'Something went wrong. Please try again.',
        action: action,
        cause: e,
      );
    }
  }
}
