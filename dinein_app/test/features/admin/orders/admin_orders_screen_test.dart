import 'package:core_pkg/config/country_config.dart';
import 'package:core_pkg/config/country_runtime.dart';
import 'package:core_pkg/constants/enums.dart';
import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/providers/order_providers.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';
import 'package:dinein_app/features/admin/orders/admin_orders_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.now();

  List<Order> buildOrders() => [
    Order(
      id: 'order-1',
      venueId: 'venue-1',
      venueName: 'Harbor Table',
      items: const [
        OrderItem(
          menuItemId: 'item-1',
          name: 'Grilled Fish',
          price: 1500,
          quantity: 2,
        ),
      ],
      total: 3000,
      status: OrderStatus.placed,
      createdAt: now,
      paymentMethod: PaymentMethod.cash,
    ),
    Order(
      id: 'order-2',
      venueId: 'venue-1',
      venueName: 'Harbor Table',
      items: const [
        OrderItem(
          menuItemId: 'item-2',
          name: 'Pasta',
          price: 1200,
          quantity: 1,
        ),
      ],
      total: 1200,
      status: OrderStatus.served,
      createdAt: now.subtract(const Duration(hours: 1)),
      paymentMethod: PaymentMethod.cash,
    ),
  ];

  Future<void> pumpOrdersScreen(
    WidgetTester tester, {
    required List<Order> orders,
    CountryConfig config = CountryConfig.mt,
  }) async {
    CountryRuntime.configure(config);

    await tester.binding.setSurfaceSize(const Size(1440, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allOrdersProvider.overrideWith((ref) async => orders),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const AdminOrdersScreen(),
        ),
      ),
    );

    // Let animations + async provider complete
    await tester.pumpAndSettle();
  }

  testWidgets('admin orders screen renders header and order data', (
    tester,
  ) async {
    await pumpOrdersScreen(tester, orders: buildOrders());

    // Verify the header renders
    expect(find.text('Orders'), findsWidgets);

    // Verify the order data is visible — at least one order card with venue name
    expect(find.text('Harbor Table'), findsWidgets);

    // Verify 3-column stats grid labels (rendered via .toUpperCase())
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('COMPLETED'), findsOneWidget);
    expect(find.text('ISSUES'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('admin orders screen renders empty state with zero orders', (
    tester,
  ) async {
    await pumpOrdersScreen(
      tester,
      orders: <Order>[],
      config: CountryConfig.rw,
    );

    // With no orders, the empty state should be visible
    final hasEmptyState = find.byType(EmptyState).evaluate().isNotEmpty;
    final hasZeroText = find.text('0').evaluate().isNotEmpty;
    final hasNoOrders = find.text('No orders').evaluate().isNotEmpty;

    expect(hasEmptyState || hasZeroText || hasNoOrders, isTrue,
        reason: 'Empty orders view should show EmptyState or zero counts');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('admin orders screen error state shows retry', (tester) async {
    CountryRuntime.configure(CountryConfig.mt);

    await tester.binding.setSurfaceSize(const Size(1440, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allOrdersProvider.overrideWith(
            (ref) => throw Exception('Network error'),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: AdminOrdersScreen()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Error state rendering
    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text('Could not load orders.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
