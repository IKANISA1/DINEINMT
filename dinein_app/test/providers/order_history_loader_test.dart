import 'package:dinein_app/core/constants/enums.dart';
import 'package:dinein_app/core/models/models.dart';
import 'package:dinein_app/core/providers/order_history_loader.dart';
import 'package:dinein_app/core/services/order_receipt_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'OrderReceiptService returns tracked order ids from saved tokens',
    () async {
      await OrderReceiptService.instance.saveReceiptToken('order_b', 'token-b');
      await OrderReceiptService.instance.saveReceiptToken('order_a', 'token-a');

      final trackedOrderIds = await OrderReceiptService.instance
          .getTrackedOrderIds();

      expect(trackedOrderIds, ['order_a', 'order_b']);
    },
  );

  test(
    'loadAccessibleUserOrders returns tracked guest orders for anonymous users',
    () async {
      final guestOrder = _order(
        id: 'guest_order',
        createdAt: DateTime.parse('2026-03-22T12:00:00Z'),
      );

      final orders = await loadAccessibleUserOrders(
        userId: null,
        fetchOrdersForUser: (_) async => throw UnimplementedError(),
        fetchTrackedOrderIds: () async => ['guest_order'],
        fetchOrderById: (orderId) async =>
            orderId == 'guest_order' ? guestOrder : null,
        clearTrackedOrder: (_) async {},
      );

      expect(orders, [guestOrder]);
    },
  );

  test(
    'loadAccessibleUserOrders merges user and tracked orders, dedupes, and sorts',
    () async {
      final olderUserOrder = _order(
        id: 'shared_order',
        createdAt: DateTime.parse('2026-03-22T11:00:00Z'),
        status: OrderStatus.received,
      );
      final newerTrackedOrder = _order(
        id: 'guest_order',
        createdAt: DateTime.parse('2026-03-22T13:00:00Z'),
      );

      final clearedTrackedOrders = <String>[];
      final orders = await loadAccessibleUserOrders(
        userId: 'user_1',
        fetchOrdersForUser: (_) async => [olderUserOrder],
        fetchTrackedOrderIds: () async => [
          'shared_order',
          'guest_order',
          'stale',
        ],
        fetchOrderById: (orderId) async {
          return switch (orderId) {
            'shared_order' => olderUserOrder,
            'guest_order' => newerTrackedOrder,
            _ => null,
          };
        },
        clearTrackedOrder: (orderId) async => clearedTrackedOrders.add(orderId),
      );

      expect(orders, [newerTrackedOrder, olderUserOrder]);
      expect(clearedTrackedOrders, ['stale']);
    },
  );
}

Order _order({
  required String id,
  required DateTime createdAt,
  OrderStatus status = OrderStatus.placed,
}) {
  return Order(
    id: id,
    orderNumber: '12345678',
    venueId: 'venue_1',
    venueName: 'Mamma Mia Restaurant',
    items: const [
      OrderItem(
        menuItemId: 'item_1',
        name: 'Instant Coffee',
        price: 1,
        quantity: 1,
      ),
    ],
    total: 1.05,
    status: status,
    createdAt: createdAt,
    paymentMethod: PaymentMethod.cash,
    tableNumber: '12',
  );
}
