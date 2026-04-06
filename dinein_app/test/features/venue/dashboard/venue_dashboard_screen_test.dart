import 'package:core_pkg/constants/enums.dart';
import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/providers/providers.dart';
import 'package:dinein_app/features/venue/dashboard/venue_dashboard_screen.dart';
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
      id: 'order_1',
      venueId: testVenue.id,
      venueName: testVenue.name,
      items: const [
        OrderItem(
          menuItemId: 'item_1',
          name: 'Octopus Carpaccio',
          price: 18,
          quantity: 2,
        ),
        OrderItem(
          menuItemId: 'item_2',
          name: 'Grilled Sea Bass',
          price: 28,
          quantity: 1,
        ),
      ],
      total: 64,
      status: OrderStatus.received,
      createdAt: DateTime.now(),
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
          name: 'Octopus Carpaccio',
          price: 18,
          quantity: 1,
        ),
      ],
      total: 18,
      status: OrderStatus.placed,
      createdAt: DateTime.now(),
      paymentMethod: PaymentMethod.cash,
      tableNumber: '7',
    ),
  ];

  const testMenuItems = [
    MenuItem(
      id: 'item_1',
      venueId: 'venue_1',
      name: 'Octopus Carpaccio',
      description: 'Citrus, fennel, olive oil.',
      price: 18,
      category: 'Starters',
    ),
    MenuItem(
      id: 'item_2',
      venueId: 'venue_1',
      name: 'Grilled Sea Bass',
      description: 'Fresh catch of the day.',
      price: 28,
      category: 'Mains',
    ),
  ];

  Widget buildDashboard({
    Venue? venue = testVenue,
    List<Order>? orders,
    List<MenuItem>? menuItems,
  }) {
    return ProviderScope(
      overrides: [
        currentVenueProvider.overrideWith((ref) async => venue),
        if (venue != null)
          venueOrdersProvider(
            venue.id,
          ).overrideWith((ref) => Stream.value(orders ?? testOrders)),
        if (venue != null)
          menuItemsProvider(
            venue.id,
          ).overrideWith((ref) async => menuItems ?? testMenuItems),
      ],
      child: const MaterialApp(home: Scaffold(body: VenueDashboardScreen())),
    );
  }

  // ─── Empty / Error States ───

  testWidgets('shows empty state when venue is null', (tester) async {
    await tester.pumpWidget(buildDashboard(venue: null));
    await tester.pumpAndSettle();

    expect(find.text('No Venue Access'), findsOneWidget);
    expect(
      find.text('No venue linked to this account.'),
      findsOneWidget,
    );
  });

  // ─── Data-Populated Dashboard ───

  testWidgets('renders dashboard header with data', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildDashboard());
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Dashboard'), findsOneWidget);
  });

  testWidgets('renders section titles', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildDashboard());
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.text('Recent Orders'), findsOneWidget);
    expect(find.text('Top Items'), findsOneWidget);
  });

  testWidgets('renders quick action buttons', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildDashboard());
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('MANAGE MENU'), findsOneWidget);
    expect(find.text('ADD MENU'), findsOneWidget);
  });

  testWidgets('renders recent order cards with table numbers', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildDashboard());
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Order table numbers should be visible
    expect(find.text('Table 4'), findsWidgets);
    expect(find.text('Table 7'), findsWidgets);
  });

  testWidgets('renders top selling items from order data', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildDashboard());
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Octopus Carpaccio'), findsWidgets);
  });

  // ─── Ordering Toggle ───

  testWidgets('shows LIVE label when venue can accept orders', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const activeVenue = Venue(
      id: 'venue_1',
      name: 'Harbor Table',
      slug: 'harbor-table',
      category: 'Mediterranean',
      description: 'Seafront dining.',
      address: 'Valletta Waterfront',
      status: VenueStatus.active,
      orderingEnabled: true,
    );

    await tester.pumpWidget(buildDashboard(venue: activeVenue));
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('ACCEPTING ORDERS'), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
  });

  testWidgets('shows OFF label for browse-only venue', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const browseOnlyVenue = Venue(
      id: 'venue_browse_only',
      name: 'Preview Lounge',
      slug: 'preview-lounge',
      category: 'Mediterranean',
      description: 'Browse only.',
      address: 'Sliema',
      status: VenueStatus.active,
      orderingEnabled: false,
    );

    await tester.pumpWidget(
      buildDashboard(
        venue: browseOnlyVenue,
        orders: const <Order>[],
        menuItems: const <MenuItem>[],
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('ORDERING DISABLED'), findsOneWidget);
    expect(find.text('OFF'), findsOneWidget);
  });

  // ─── Empty Orders State ───

  testWidgets('renders dashboard structure when no orders exist', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      buildDashboard(orders: const <Order>[], menuItems: const <MenuItem>[]),
    );
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Quick Actions'), findsOneWidget);
  });
}
