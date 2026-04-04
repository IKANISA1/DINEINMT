import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/services/venue_notification_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/mock_api_invoker.dart';

void main() {
  late MockApiInvoker mock;
  late VenueNotificationRepository repo;

  setUp(() {
    mock = MockApiInvoker();
    repo = VenueNotificationRepository.forTesting(invoker: mock.invoke);
  });

  group('getSettings', () {
    test('returns parsed settings from API', () async {
      mock.registerResponse('get_venue_notification_settings', {
        'order_push_enabled': true,
        'whatsapp_updates_enabled': false,
      });

      final settings = await repo.getSettings('v1');

      expect(settings.orderPushEnabled, isTrue);
      expect(settings.whatsAppUpdatesEnabled, isFalse);
      
      final inv = mock.lastInvocation('get_venue_notification_settings')!;
      expect(inv.payload?['venueId'], 'v1');
    });

    test('returns defaults when API returns null or non-map', () async {
      mock.registerResponse('get_venue_notification_settings', null);

      final settings = await repo.getSettings('v1');

      expect(settings.orderPushEnabled, isTrue); // default is true in new model
      expect(settings.whatsAppUpdatesEnabled, isTrue);
    });
  });

  group('updateSettings', () {
    test('sends payload and returns updated settings', () async {
      mock.registerResponse('update_venue_notification_settings', {
        'order_push_enabled': false,
        'whatsapp_updates_enabled': true,
      });

      final settings = await repo.updateSettings('v1', const VenueNotificationSettings(
        orderPushEnabled: false,
        whatsAppUpdatesEnabled: true,
      ));

      expect(settings.orderPushEnabled, isFalse);
      expect(settings.whatsAppUpdatesEnabled, isTrue);

      final inv = mock.lastInvocation('update_venue_notification_settings')!;
      expect(inv.payload?['venueId'], 'v1');
      expect((inv.payload?['settings'] as Map)['order_push_enabled'], isFalse);
      expect((inv.payload?['settings'] as Map)['whatsapp_updates_enabled'], isTrue);
    });
  });
}
