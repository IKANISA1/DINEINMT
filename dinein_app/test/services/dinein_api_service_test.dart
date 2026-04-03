import 'package:dinein_app/core/config/country_config.dart';
import 'package:dinein_app/core/config/country_runtime.dart';
import 'package:dinein_app/core/services/dinein_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
