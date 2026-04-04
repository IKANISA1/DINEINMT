import 'package:core_pkg/constants/enums.dart';
import 'package:dinein_app/core/services/order_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/mock_api_invoker.dart';

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

void main() {
  late MockApiInvoker mock;
  late OrderRepository repo;

  setUp(() {
    mock = MockApiInvoker();
    repo = OrderRepository.forTesting(invoker: mock.invoke);
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
      mock.registerResponse('update_order_status', null);

      await repo.updateOrderStatus('order-x', OrderStatus.received);

      final inv = mock.lastInvocation('update_order_status')!;
      expect(inv.payload?['orderId'], 'order-x');
      expect(inv.payload?['status'], 'received');
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
