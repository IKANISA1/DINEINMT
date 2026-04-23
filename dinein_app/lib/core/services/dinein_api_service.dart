import 'dart:async';
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

/// Thin wrapper around the deployed DineIn edge-function surfaces.
class DineinApiService {
  DineinApiService._();

  static const _edgeFunctionTimeout = Duration(seconds: 15);

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
    final headers = <String, String>{if (extraHeaders != null) ...extraHeaders};
    final bodyPayload = <String, dynamic>{
      'action': action,
      'country': CountryRuntime.config.country.code,
    };
    if (payload != null) {
      bodyPayload.addAll(payload);
    }

    if (useAdminSession) {
      if (adminAccessToken == null || adminAccessToken.isEmpty) {
        throw DineinApiException(
          'Admin session expired. Please sign in again.',
          action: action,
        );
      }
      bodyPayload.remove('venue_session');
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

  // All app-owned runtime actions must be registered here so the Flutter
  // client stays on the modular edge-function surface. Falling back to the
  // deprecated compatibility dispatcher is reserved for legacy callers only.
  static const Map<String, String> _actionToEdgeFunction = {
    // core-api
    'health': 'core-api',
    'create_profile': 'core-api',
    'get_user_role': 'core-api',
    'track_guest_event': 'core-api',

    // orders-api
    'get_orders_for_venue': 'orders-api',
    'get_orders_for_user': 'orders-api',
    'get_all_orders': 'orders-api',
    'get_admin_dashboard_kpis': 'orders-api',
    'get_order_by_id': 'orders-api',
    'issue_order_realtime_access': 'orders-api',
    'update_order_status': 'orders-api',
    'mark_order_paid': 'orders-api',
    'place_order': 'orders-api',

    // menu-api
    'get_menu_items': 'menu-api',
    'get_menu_item_by_id': 'menu-api',
    'toggle_menu_item_availability': 'menu-api',
    'create_menu_item': 'menu-api',
    'update_menu_item': 'menu-api',
    'delete_menu_item': 'menu-api',
    'set_menu_item_highlights': 'menu-api',
    'ingest_menu_document': 'menu-api',
    'generate_menu_item_image': 'menu-api',
    'backfill_menu_images': 'menu-api',
    'audit_menu_item_images': 'menu-api',
    'upload_menu_item_image': 'menu-api',
    'image_health': 'menu-api',

    // venue-api
    'get_venues': 'venue-api',
    'get_all_venues': 'venue-api',
    'create_venue': 'venue-api',
    'get_venue_by_slug': 'venue-api',
    'get_venue_by_id': 'venue-api',
    'get_venue_for_owner': 'venue-api',
    'update_venue': 'venue-api',
    'enrich_venue_profile': 'venue-api',
    'backfill_venue_profiles': 'venue-api',
    'generate_venue_profile_image': 'venue-api',
    'backfill_venue_profile_images': 'venue-api',
    'get_venue_notification_settings': 'venue-api',
    'update_venue_notification_settings': 'venue-api',
    'register_push_device': 'venue-api',
    'unregister_push_device': 'venue-api',
    'send_wave': 'venue-api',
    'get_bell_requests': 'venue-api',
    'resolve_bell_request': 'venue-api',
    'search_google_maps': 'venue-api',
    'upload_venue_image': 'venue-api',

    // admin-api
    'get_admin_menu_queue': 'admin-api',
    'get_admin_menu_catalog': 'admin-api',
    'get_admin_menu_group_assignments': 'admin-api',
    'create_admin_menu_groups': 'admin-api',
    'assign_admin_menu_group': 'admin-api',
    'delete_admin_menu_group': 'admin-api',
  };

  @visibleForTesting
  static bool hasExplicitRouteForAction(String action) =>
      _actionToEdgeFunction.containsKey(action);

  @visibleForTesting
  static String functionNameForAction(String action) =>
      _actionToEdgeFunction[action] ?? 'dinein-api';

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

    final functionName = functionNameForAction(action);

    try {
      final response = await SupabaseConfig.client.functions
          .invoke(
            functionName,
            headers: request.headers.isEmpty ? null : request.headers,
            body: request.body,
          )
          .timeout(_edgeFunctionTimeout);

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
    } on TimeoutException catch (e) {
      throw DineinApiException(
        'Request timed out. Please try again.',
        action: action,
        cause: e,
      );
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
      // Extract the real error message from the edge function response body
      // instead of hiding it behind a generic message.
      String message =
          'Service temporarily unavailable. Please try again shortly.';
      final details = e.details;
      if (details is Map) {
        final errorMsg = details['error'];
        if (errorMsg is String && errorMsg.isNotEmpty) {
          message = errorMsg;
        }
      } else if (details is String && details.isNotEmpty) {
        message = details;
      }
      throw DineinApiException(message, action: action, cause: e);
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
