import 'dart:convert';

import 'package:core_pkg/constants/enums.dart';
import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/services/auth_repository.dart';
import 'package:dinein_app/core/services/order_repository.dart';
import 'package:dinein_app/core/services/order_receipt_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/mock_api_invoker.dart';
import '../fixtures/mock_secure_storage.dart';

/// Minimal order JSON matching Order.fromJson expectations.
Map<String, dynamic> _orderJson({
  String id = 'o1',
  String venueId = 'v1',
  String venueName = 'Test Venue',
  String status = 'placed',
  String paymentMethod = 'cash',
  List<Map<String, dynamic>>? items,
}) => {
  'id': id,
  'venue_id': venueId,
  'venue_name': venueName,
  'status': status,
  'payment_method': paymentMethod,
  'items':
      items ??
      [
        {
          'menu_item_id': 'item-1',
          'name': 'Espresso',
          'description': 'Single-shot espresso',
          'image_url': 'https://example.com/espresso.jpg',
          'price': 2.50,
          'quantity': 1,
        },
      ],
  'total': 2.50,
  'created_at': '2026-04-03T12:00:00Z',
};

VenueAccessSession _activeVenueSession({
  required String venueId,
  required String venueName,
  required String whatsAppNumber,
  required String accessToken,
}) {
  final now = DateTime.now().toUtc();
  return VenueAccessSession(
    venueId: venueId,
    venueName: venueName,
    whatsAppNumber: whatsAppNumber,
    accessToken: accessToken,
    issuedAt: now.subtract(const Duration(minutes: 5)),
    expiresAt: now.add(const Duration(days: 1)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockApiInvoker mock;
  late OrderRepository repo;

  setUp(() {
    MockSecureStorage.setup();
    MockSecureStorage.clear();
    mock = MockApiInvoker();
    repo = OrderRepository.forTesting(invoker: mock.invoke);
  });

  tearDown(() async {
    await AuthRepository.instance.clearVenueSession();
  });

  group('issueRealtimeAccess', () {
    test(
      'issues order-scoped access and forwards a saved receipt token',
      () async {
        await OrderReceiptService.instance.saveReceiptToken(
          'order-123',
          'receipt-token-123',
        );
        mock.registerResponse('issue_order_realtime_access', {
          'access_token': 'jwt-order-token',
          'expires_at': '2026-04-08T18:30:00Z',
        });

        final access = await repo.issueRealtimeAccess(orderId: 'order-123');

        final inv = mock.lastInvocation('issue_order_realtime_access')!;
        expect(inv.payload?['orderId'], 'order-123');
        expect(inv.payload?['receiptToken'], 'receipt-token-123');
        expect(inv.payload?.containsKey('venueId'), isFalse);
        expect(access.accessToken, 'jwt-order-token');
        expect(access.expiresAt, DateTime.parse('2026-04-08T18:30:00Z'));
      },
    );

    test('issues venue-scoped access without receipt data', () async {
      await AuthRepository.instance.saveVenueSession(
        _activeVenueSession(
          venueId: 'venue-789',
          venueName: 'Realtime Venue',
          whatsAppNumber: '+250795588248',
          accessToken: 'venue-session-token',
        ),
      );
      mock.registerResponse('issue_order_realtime_access', {
        'accessToken': 'jwt-venue-token',
        'expiresAt': '2026-04-08T19:00:00Z',
      });

      final access = await repo.issueRealtimeAccess(venueId: 'venue-789');

      final inv = mock.lastInvocation('issue_order_realtime_access')!;
      expect(inv.payload?['venueId'], 'venue-789');
      expect(inv.payload?['venue_session'], {
        'access_token': 'venue-session-token',
      });
      expect(inv.payload?.containsKey('orderId'), isFalse);
      expect(inv.payload?.containsKey('receiptToken'), isFalse);
      expect(access.accessToken, 'jwt-venue-token');
      expect(access.expiresAt, DateTime.parse('2026-04-08T19:00:00Z'));
    });

    test('rejects missing and mixed scopes', () {
      expect(() => repo.issueRealtimeAccess(), throwsA(isA<AssertionError>()));
      expect(
        () => repo.issueRealtimeAccess(orderId: 'o1', venueId: 'v1'),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('getOrdersForVenue', () {
    test('returns parsed order list', () async {
      mock.registerResponse('get_orders_for_venue', [
        _orderJson(id: 'o1', status: 'placed'),
        _orderJson(id: 'o2', status: 'served'),
      ]);

      final orders = await repo.getOrdersForVenue('v1');

      expect(orders, hasLength(2));
      expect(orders[0].id, 'o1');
      expect(orders[1].id, 'o2');
      expect(orders[0].items.single.description, 'Single-shot espresso');
      expect(
        orders[0].items.single.imageUrl,
        'https://example.com/espresso.jpg',
      );
    });

    test('passes venueId and pagination params', () async {
      mock.registerResponse('get_orders_for_venue', <dynamic>[]);

      await repo.getOrdersForVenue('my-venue', limit: 20, offset: 0);

      final inv = mock.lastInvocation('get_orders_for_venue')!;
      expect(inv.payload?['venueId'], 'my-venue');
      expect(inv.payload?['limit'], 20);
      expect(inv.payload?['offset'], 0);
    });

    test('restores the persisted venue session into the payload', () async {
      MockSecureStorage.setMockValue(
        'dinein.venue_session',
        jsonEncode(
          _activeVenueSession(
            venueId: 'my-venue',
            venueName: 'My Venue',
            whatsAppNumber: '+250795588248',
            accessToken: 'venue-token',
          ).toJson(),
        ),
      );
      mock.registerResponse('get_orders_for_venue', <dynamic>[]);

      await repo.getOrdersForVenue('my-venue');

      final inv = mock.lastInvocation('get_orders_for_venue')!;
      expect(inv.payload?['venue_session'], {'access_token': 'venue-token'});
    });

    test('returns empty list when no orders', () async {
      mock.registerResponse('get_orders_for_venue', <dynamic>[]);

      final orders = await repo.getOrdersForVenue('empty-venue');

      expect(orders, isEmpty);
    });
  });

  group('getOrdersForUser', () {
    test('returns parsed order list', () async {
      mock.registerResponse('get_orders_for_user', [_orderJson(id: 'u-o1')]);

      final orders = await repo.getOrdersForUser('user-123');

      expect(orders, hasLength(1));
      expect(orders[0].id, 'u-o1');
    });

    test('passes userId and pagination', () async {
      mock.registerResponse('get_orders_for_user', <dynamic>[]);

      await repo.getOrdersForUser('user-456', limit: 5, offset: 10);

      final inv = mock.lastInvocation('get_orders_for_user')!;
      expect(inv.payload?['userId'], 'user-456');
      expect(inv.payload?['limit'], 5);
      expect(inv.payload?['offset'], 10);
    });
  });

  group('getAllOrders', () {
    test('uses admin session', () async {
      mock.registerResponse('get_all_orders', <dynamic>[]);

      await repo.getAllOrders();

      final inv = mock.lastInvocation('get_all_orders')!;
      expect(inv.useAdminSession, isTrue);
    });

    test('returns parsed orders', () async {
      mock.registerResponse('get_all_orders', [
        _orderJson(id: 'all-1'),
        _orderJson(id: 'all-2'),
      ]);

      final orders = await repo.getAllOrders(limit: 50);

      expect(orders, hasLength(2));
      final inv = mock.lastInvocation('get_all_orders')!;
      expect(inv.payload?['limit'], 50);
    });
  });

  group('updateOrderStatus', () {
    test('sends correct action and payload', () async {
      await AuthRepository.instance.saveVenueSession(
        _activeVenueSession(
          venueId: 'venue-1',
          venueName: 'Updater',
          whatsAppNumber: '+35677186193',
          accessToken: 'update-token',
        ),
      );
      mock.registerResponse('update_order_status', null);

      await repo.updateOrderStatus('order-x', OrderStatus.received);

      final inv = mock.lastInvocation('update_order_status')!;
      expect(inv.payload?['orderId'], 'order-x');
      expect(inv.payload?['status'], 'received');
      expect(inv.payload?['venue_session'], {'access_token': 'update-token'});
    });

    test('supports all valid status transitions', () async {
      mock.registerResponse('update_order_status', null);

      for (final status in [
        OrderStatus.received,
        OrderStatus.served,
        OrderStatus.cancelled,
      ]) {
        await repo.updateOrderStatus('o-1', status);
      }

      expect(mock.callCount('update_order_status'), 3);
    });
  });

  group('error handling', () {
    test('propagates API errors', () async {
      mock.registerError(
        'get_orders_for_venue',
        Exception('Server unavailable'),
      );

      expect(() => repo.getOrdersForVenue('v1'), throwsA(isA<Exception>()));
    });
  });
}
