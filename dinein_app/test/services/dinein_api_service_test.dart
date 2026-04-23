import 'package:core_pkg/config/country_config.dart';
import 'package:core_pkg/config/country_runtime.dart';
import 'package:dinein_app/core/services/dinein_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const appRuntimeActions = <String>{
    'backfill_menu_images',
    'create_admin_menu_groups',
    'create_menu_item',
    'create_profile',
    'create_venue',
    'delete_admin_menu_group',
    'delete_menu_item',
    'enrich_venue_profile',
    'generate_menu_item_image',
    'get_admin_dashboard_kpis',
    'get_admin_menu_catalog',
    'get_admin_menu_group_assignments',
    'get_admin_menu_queue',
    'get_all_orders',
    'get_all_venues',
    'get_bell_requests',
    'get_menu_item_by_id',
    'get_menu_items',
    'get_order_by_id',
    'get_orders_for_user',
    'get_orders_for_venue',
    'get_user_role',
    'get_venue_by_id',
    'get_venue_by_slug',
    'get_venue_for_owner',
    'get_venue_notification_settings',
    'get_venues',
    'image_health',
    'ingest_menu_document',
    'issue_order_realtime_access',
    'mark_order_paid',
    'place_order',
    'resolve_bell_request',
    'send_wave',
    'set_menu_item_highlights',
    'toggle_menu_item_availability',
    'track_guest_event',
    'update_menu_item',
    'update_order_status',
    'update_venue',
    'update_venue_notification_settings',
    'upload_menu_item_image',
    'upload_venue_image',
  };

  setUp(() {
    CountryRuntime.configure(CountryConfig.mt);
  });

  test(
    'buildInvocation keeps venue session auth in the payload for venue-only requests',
    () {
      final request = DineinApiService.buildInvocation(
        'get_orders_for_venue',
        payload: {'venueId': 'venue-1'},
        venueAccessToken: 'venue-token',
      );

      expect(request.headers, isEmpty);
      expect(request.body['country'], 'MT');
      expect(request.body['venue_session'], {'access_token': 'venue-token'});
    },
  );

  test(
    'buildInvocation includes both user auth and venue session when both exist',
    () {
      final request = DineinApiService.buildInvocation(
        'update_order_status',
        payload: {'orderId': 'order-1'},
        userAccessToken: 'user-token',
        venueAccessToken: 'venue-token',
      );

      expect(request.headers['Authorization'], 'Bearer user-token');
      expect(request.body['venue_session'], {'access_token': 'venue-token'});
    },
  );

  test(
    'buildInvocation throws DineinApiException when admin session is missing',
    () {
      expect(
        () => DineinApiService.buildInvocation(
          'get_all_venues',
          useAdminSession: true,
          adminAccessToken: null,
        ),
        throwsA(isA<DineinApiException>()),
      );
    },
  );

  test('buildInvocation strips venue session payloads from admin requests', () {
    final request = DineinApiService.buildInvocation(
      'update_venue',
      useAdminSession: true,
      adminAccessToken: 'admin-token',
      payload: {
        'venueId': 'venue-1',
        'venue_session': {'access_token': 'venue-token'},
      },
    );

    expect(request.headers['Authorization'], 'Bearer admin-token');
    expect(request.body.containsKey('venue_session'), isFalse);
  });

  test('functionNameForAction routes core actions to core-api', () {
    expect(DineinApiService.functionNameForAction('health'), 'core-api');
    expect(
      DineinApiService.functionNameForAction('create_profile'),
      'core-api',
    );
    expect(
      DineinApiService.functionNameForAction('track_guest_event'),
      'core-api',
    );
  });

  test('functionNameForAction routes order actions to orders-api', () {
    expect(
      DineinApiService.functionNameForAction('get_orders_for_venue'),
      'orders-api',
    );
    expect(DineinApiService.functionNameForAction('place_order'), 'orders-api');
    expect(
      DineinApiService.functionNameForAction('mark_order_paid'),
      'orders-api',
    );
  });

  test('functionNameForAction routes menu actions to menu-api', () {
    expect(
      DineinApiService.functionNameForAction('get_menu_items'),
      'menu-api',
    );
    expect(
      DineinApiService.functionNameForAction('create_menu_item'),
      'menu-api',
    );
    expect(
      DineinApiService.functionNameForAction('generate_menu_item_image'),
      'menu-api',
    );
  });

  test('functionNameForAction routes venue actions to venue-api', () {
    expect(DineinApiService.functionNameForAction('get_venues'), 'venue-api');
    expect(
      DineinApiService.functionNameForAction('search_google_maps'),
      'venue-api',
    );
    expect(
      DineinApiService.functionNameForAction('register_push_device'),
      'venue-api',
    );
  });

  test('functionNameForAction routes admin menu actions to admin-api', () {
    expect(
      DineinApiService.functionNameForAction('get_admin_menu_queue'),
      'admin-api',
    );
    expect(
      DineinApiService.functionNameForAction('create_admin_menu_groups'),
      'admin-api',
    );
    expect(
      DineinApiService.functionNameForAction('delete_admin_menu_group'),
      'admin-api',
    );
  });

  test('all live Flutter runtime actions are explicitly routed', () {
    final unmapped = appRuntimeActions
        .where((action) => !DineinApiService.hasExplicitRouteForAction(action))
        .toList(growable: false);

    expect(unmapped, isEmpty);
  });

  test(
    'functionNameForAction keeps deprecated compatibility fallback for unmapped actions',
    () {
      expect(
        DineinApiService.functionNameForAction('some_future_action'),
        'dinein-api',
      );
    },
  );
}
