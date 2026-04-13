import 'package:core_pkg/constants/enums.dart';
import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/providers/providers.dart';
import 'package:dinein_app/features/venue/orders/venue_order_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Order _buildOrder({
  required String id,
  OrderStatus status = OrderStatus.served,
  PaymentMethod paymentMethod = PaymentMethod.cash,
  PaymentStatus? paymentStatus,
}) {
  return Order(
    id: id,
    venueId: 'venue-1',
    venueName: 'Harbor Table',
    items: const [
      OrderItem(
        menuItemId: 'item-1',
        name: 'Espresso',
        price: 2.5,
        quantity: 1,
      ),
    ],
    total: 2.5,
    status: status,
    createdAt: DateTime.now(),
    paymentMethod: paymentMethod,
    paymentStatus: paymentStatus,
    tableNumber: '3',
  );
}

Widget _buildScreen(Order order) {
  return ProviderScope(
    overrides: [orderByIdProvider(order.id).overrideWith((ref) async => order)],
    child: MaterialApp(home: VenueOrderDetailScreen(orderId: order.id)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows mark-as-paid action for unsettled orders', (tester) async {
    final order = _buildOrder(
      id: 'order-unpaid',
      paymentMethod: PaymentMethod.cash,
      paymentStatus: PaymentStatus.notRequired,
    );

    await tester.pumpWidget(_buildScreen(order));
    await tester.pumpAndSettle();

    expect(find.text('Payment status'), findsOneWidget);
    expect(find.text('Pay at venue'), findsOneWidget);
    expect(find.text('Mark as Paid'), findsOneWidget);
  });

  testWidgets('hides mark-as-paid action for confirmed payments', (
    tester,
  ) async {
    final order = _buildOrder(
      id: 'order-paid',
      paymentMethod: PaymentMethod.revolutLink,
      paymentStatus: PaymentStatus.confirmed,
    );

    await tester.pumpWidget(_buildScreen(order));
    await tester.pumpAndSettle();

    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('Mark as Paid'), findsNothing);
  });

  testWidgets('hides mark-as-paid action for cancelled orders', (tester) async {
    final order = _buildOrder(
      id: 'order-cancelled',
      status: OrderStatus.cancelled,
      paymentStatus: PaymentStatus.pending,
    );

    await tester.pumpWidget(_buildScreen(order));
    await tester.pumpAndSettle();

    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Mark as Paid'), findsNothing);
  });
}
