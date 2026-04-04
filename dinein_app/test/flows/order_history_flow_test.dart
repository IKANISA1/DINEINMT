import 'package:core_pkg/constants/enums.dart';
import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/providers/providers.dart';
import 'package:dinein_app/features/guest/order/order_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('order history keeps its header and empty-state CTA', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userOrdersProvider.overrideWith((ref) async => const <Order>[]),
        ],
        child: const MaterialApp(home: Scaffold(body: OrderHistoryScreen())),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('ORDER'), findsOneWidget);
    expect(find.textContaining('HISTORY'), findsOneWidget);
    expect(find.text('No orders yet'), findsOneWidget);
    expect(find.text('DISCOVER VENUES'), findsOneWidget);
  });

  testWidgets('order history renders venue-led order cards', (tester) async {
    final order = Order(
      id: 'order_1',
      orderNumber: '10000001',
      venueId: 'venue_1',
      venueName: 'Harbor Table',
      venueImageUrl:
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9sN2VN8AAAAASUVORK5CYII=',
      items: const [
        OrderItem(
          menuItemId: 'item_1',
          name: 'Oyster Plate',
          price: 18,
          quantity: 1,
        ),
        OrderItem(
          menuItemId: 'item_2',
          name: 'Sea Bass',
          price: 24,
          quantity: 1,
        ),
      ],
      total: 42,
      status: OrderStatus.received,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      paymentMethod: PaymentMethod.cash,
    );

    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userOrdersProvider.overrideWith((ref) async => [order]),
        ],
        child: const MaterialApp(home: Scaffold(body: OrderHistoryScreen())),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('#10000001'), findsOneWidget);
    expect(find.text('Harbor Table'), findsOneWidget);
    expect(find.textContaining('Oyster Plate'), findsOneWidget);
    expect(find.text('€42.00'), findsOneWidget);
  });
}
