import 'dart:async';

import 'package:core_pkg/constants/enums.dart';
import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/providers/providers.dart';
import 'package:dinein_app/features/venue/reports/venue_item_report_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ui/widgets/shared_widgets.dart';

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
    status: VenueStatus.active,
    orderingEnabled: true,
    country: Country.mt,
  );

  final testOrders = [
    Order(
      id: 'order_1',
      venueId: testVenue.id,
      venueName: testVenue.name,
      items: const [
        OrderItem(
          menuItemId: 'item_1',
          name: 'Dry-Aged Ribeye',
          price: 48,
          quantity: 2,
        ),
        OrderItem(
          menuItemId: 'item_2',
          name: 'Truffle Pappardelle',
          price: 32,
          quantity: 1,
        ),
      ],
      total: 128,
      status: OrderStatus.served,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      paymentMethod: PaymentMethod.cash,
      tableNumber: '4',
    ),
    Order(
      id: 'order_2',
      venueId: testVenue.id,
      venueName: testVenue.name,
      items: const [
        OrderItem(
          menuItemId: 'item_1',
          name: 'Dry-Aged Ribeye',
          price: 48,
          quantity: 1,
        ),
      ],
      total: 48,
      status: OrderStatus.received,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      paymentMethod: PaymentMethod.cash,
      tableNumber: '7',
    ),
  ];

  Widget buildReport({
    Venue? venue = testVenue,
    List<Order>? orders,
    bool venueError = false,
    bool ordersError = false,
  }) {
    return ProviderScope(
      overrides: [
        currentVenueProvider.overrideWith((ref) {
          if (venueError) throw Exception('Network error');
          return Future.value(venue);
        }),
        if (venue != null)
          venueOrdersProvider(venue.id).overrideWith((ref) {
            if (ordersError) {
              return Stream<List<Order>>.error(Exception('DB error'));
            }
            return Stream.value(orders ?? testOrders);
          }),
      ],
      child: MaterialApp(
        home: const Scaffold(body: VenueItemReportScreen()),
      ),
    );
  }

  // ─── Loading State ───

  testWidgets('shows skeleton loader while venue is loading', (tester) async {
    final completer = Completer<Venue?>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentVenueProvider.overrideWith((ref) => completer.future),
        ],
        child: MaterialApp(
          home: const Scaffold(body: VenueItemReportScreen()),
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(SkeletonLoader), findsWidgets);

    // Complete to avoid dangling future
    completer.complete(null);
    await tester.pumpAndSettle();
  });

  // ─── Error States ───

  testWidgets('shows venue ErrorState when venue fails', (tester) async {
    await tester.pumpWidget(buildReport(venueError: true));
    await tester.pumpAndSettle();

    expect(find.text('Could not load venue data.'), findsOneWidget);
  });

  testWidgets('shows orders ErrorState when orders fail', (tester) async {
    await tester.pumpWidget(buildReport(ordersError: true));
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Could not load orders.'), findsOneWidget);
  });

  // ─── Empty State (no venue) ───

  testWidgets('shows EmptyState when venue is null', (tester) async {
    await tester.pumpWidget(buildReport(venue: null));
    await tester.pumpAndSettle();

    expect(find.text('No Venue Access'), findsOneWidget);
    expect(find.text('No venue linked to this account.'), findsOneWidget);
  });

  // ─── Data Populated ───

  testWidgets('renders report header with data', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildReport());
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Item Report'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('renders time period filter chips', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildReport());
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('DAY'), findsOneWidget);
    expect(find.text('WEEK'), findsOneWidget);
    expect(find.text('MONTH'), findsOneWidget);
    expect(find.text('CUSTOM'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  // ─── Empty Orders ───

  testWidgets('renders empty state when no orders exist', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildReport(orders: const <Order>[]));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    // Should still render the report structure
    expect(find.text('Item Report'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  // ─── Order Aggregation Logic ───

  group('Order item aggregation', () {
    test('counts total items across orders', () {
      final allItems = testOrders.expand((o) => o.items).toList();

      // item_1 appears in both orders: 2 + 1 = 3
      final item1Count = allItems
          .where((i) => i.menuItemId == 'item_1')
          .fold<int>(0, (sum, i) => sum + i.quantity);

      // item_2 appears in one order: 1
      final item2Count = allItems
          .where((i) => i.menuItemId == 'item_2')
          .fold<int>(0, (sum, i) => sum + i.quantity);

      expect(item1Count, 3);
      expect(item2Count, 1);
    });

    test('calculates revenue per item', () {
      final allItems = testOrders.expand((o) => o.items).toList();

      // item_1: (2 * 48) + (1 * 48) = 144
      final item1Revenue = allItems
          .where((i) => i.menuItemId == 'item_1')
          .fold<double>(0, (sum, i) => sum + (i.price * i.quantity));

      // item_2: 1 * 32 = 32
      final item2Revenue = allItems
          .where((i) => i.menuItemId == 'item_2')
          .fold<double>(0, (sum, i) => sum + (i.price * i.quantity));

      expect(item1Revenue, 144.0);
      expect(item2Revenue, 32.0);
    });
  });
}
