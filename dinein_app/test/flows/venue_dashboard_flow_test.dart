import 'dart:async';

import 'package:dinein_app/core/constants/enums.dart';
import 'package:dinein_app/core/models/models.dart';
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

  testWidgets('venue dashboard shows current quick actions and stats', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const venue = Venue(
      id: 'venue_1',
      name: 'Harbor Table',
      slug: 'harbor-table',
      category: 'Mediterranean',
      description: 'Seafront dining.',
      address: 'Valletta Waterfront',
    );

    final orders = [
      Order(
        id: 'order_1234',
        venueId: venue.id,
        venueName: venue.name,
        items: const [
          OrderItem(
            menuItemId: 'item_1',
            name: 'Octopus Carpaccio',
            price: 18,
            quantity: 2,
          ),
        ],
        total: 36,
        status: OrderStatus.received,
        createdAt: DateTime.now(),
        paymentMethod: PaymentMethod.cash,
        tableNumber: '4',
      ),
    ];

    const menuItems = [
      MenuItem(
        id: 'item_1',
        venueId: 'venue_1',
        name: 'Octopus Carpaccio',
        description: 'Citrus, fennel, olive oil.',
        price: 18,
        category: 'Starters',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentVenueProvider.overrideWith((ref) async => venue),
          venueOrdersProvider(
            venue.id,
          ).overrideWith((ref) => Stream.value(orders)),
          menuItemsProvider(venue.id).overrideWith((ref) async => menuItems),
        ],
        child: const MaterialApp(home: Scaffold(body: VenueDashboardScreen())),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Dashboard header
    expect(find.text('Dashboard'), findsOneWidget);

    // Quick actions match current UI
    expect(find.text('MANAGE MENU'), findsOneWidget);
    expect(find.text('ADD MENU'), findsOneWidget);

    // Section headers
    expect(find.text('Recent Orders'), findsOneWidget);
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.text('Top Items'), findsOneWidget);
  });
}
