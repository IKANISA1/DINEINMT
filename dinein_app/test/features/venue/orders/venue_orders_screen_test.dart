import 'package:core_pkg/constants/enums.dart';
import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/providers/providers.dart';
import 'package:dinein_app/features/venue/orders/venue_orders_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const testVenue = Venue(
    id: 'venue_1',
    name: 'Harbor Table',
    slug: 'harbor-table',
    category: 'Mediterranean',
    description: 'Seafront dining.',
    address: 'Valletta Waterfront',
  );

  final testOrders = [
    Order(
      id: 'order_placed',
      venueId: testVenue.id,
      venueName: testVenue.name,
      items: const [
        OrderItem(
          menuItemId: 'item_1',
          name: 'Pasta Carbonara',
          price: 14,
          quantity: 2,
        ),
      ],
      total: 28,
      status: OrderStatus.placed,
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      paymentMethod: PaymentMethod.cash,
      tableNumber: '3',
    ),
    Order(
      id: 'order_received',
      venueId: testVenue.id,
      venueName: testVenue.name,
      items: const [
        OrderItem(
          menuItemId: 'item_2',
          name: 'Margherita Pizza',
          price: 12,
          quantity: 1,
        ),
      ],
      total: 12,
      status: OrderStatus.received,
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
      paymentMethod: PaymentMethod.cash,
      tableNumber: '5',
    ),
    Order(
      id: 'order_served',
      venueId: testVenue.id,
      venueName: testVenue.name,
      items: const [
        OrderItem(
          menuItemId: 'item_3',
          name: 'Tiramisu',
          price: 9,
          quantity: 1,
        ),
      ],
      total: 9,
      status: OrderStatus.served,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      paymentMethod: PaymentMethod.cash,
      tableNumber: '1',
    ),
  ];

  Widget buildOrdersScreen({
    Venue? venue = testVenue,
    List<Order>? orders,
  }) {
    return ProviderScope(
      overrides: [
        currentVenueProvider.overrideWith((ref) async => venue),
        if (venue != null)
          venueOrdersProvider(
            venue.id,
          ).overrideWith((ref) => Stream.value(orders ?? testOrders)),
      ],
      child: const MaterialApp(home: Scaffold(body: VenueOrdersScreen())),
    );
  }

  // ─── Empty / Null States ───

  testWidgets('shows empty state when venue is null', (tester) async {
    await tester.pumpWidget(buildOrdersScreen(venue: null));
    await tester.pumpAndSettle();

    expect(find.text('No Venue Access'), findsOneWidget);
    expect(
      find.text('No venue linked to this account.'),
      findsOneWidget,
    );
  });

  // ─── Data-Populated Orders ───

  testWidgets('renders Orders header with data', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildOrdersScreen());
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Orders'), findsOneWidget);
  });

  testWidgets('renders ALL status filter tab', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildOrdersScreen());
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // The ALL tab should always be visible
    expect(find.text('ALL'), findsOneWidget);
  });

  testWidgets('renders order cards with table numbers as guest names', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildOrdersScreen());
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Order cards show 'Table X' as guest name when userName is null
    expect(find.text('Table 3'), findsWidgets);
    expect(find.text('Table 5'), findsWidgets);
  });

  testWidgets('renders order item chips with quantity prefix', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildOrdersScreen());
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Order card item chips show "Nx ItemName"
    expect(find.text('2x Pasta Carbonara'), findsWidgets);
    expect(find.text('1x Margherita Pizza'), findsWidgets);
  });

  // ─── Empty Orders State ───

  testWidgets('renders "No orders found" when orders list is empty', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildOrdersScreen(orders: const <Order>[]));
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('No orders found'), findsOneWidget);
  });

  // ─── Status Badges ───

  testWidgets('renders NEW badge for placed orders', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildOrdersScreen());
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Placed orders show "NEW" status badge
    expect(find.text('NEW'), findsWidgets);
  });
}
