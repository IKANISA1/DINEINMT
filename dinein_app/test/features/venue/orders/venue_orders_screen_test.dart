import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dinein_app/core/providers/providers.dart';
import 'package:dinein_app/features/venue/orders/venue_orders_screen.dart';

void main() {
  testWidgets('venue orders screen renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentVenueProvider.overrideWith((ref) => null)
        ],
        child: const MaterialApp(
          home: Scaffold(body: VenueOrdersScreen()),
        ),
      ),
    );

    await tester.pumpAndSettle();
    
    expect(find.text('No Venue Access'), findsOneWidget);
  });
}
