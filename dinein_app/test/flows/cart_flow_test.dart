import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/providers/cart_provider.dart';
import 'package:dinein_app/core/providers/providers.dart';
import 'package:dinein_app/features/guest/cart/cart_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const venue = Venue(
    id: 'venue_1',
    name: 'Harbor Table',
    slug: 'harbor-table',
    category: 'Seafood',
    description: 'Seafront seafood dining with sunset views.',
    address: 'Valletta Waterfront',
  );

  MenuItem buildItem() => MenuItem(
    id: 'item_1',
    venueId: venue.id,
    name: 'Octopus',
    description: 'Chargrilled octopus with lemon.',
    price: 18,
    category: 'Mains',
  );

  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: [
        venueByIdProvider(venue.id).overrideWith((ref) async => venue),
      ],
    );
    final notifier = container.read(cartProvider.notifier);
    notifier.setVenue(
      venueId: venue.id,
      venueSlug: venue.slug,
      venueName: venue.name,
      venueCountry: venue.country,
    );
    notifier.addItem(buildItem());
    return container;
  }

  testWidgets('cart table number draft commits on blur, not each keystroke', (
    tester,
  ) async {
    final container = buildContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CartScreen()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Table #'));
    await tester.pumpAndSettle();

    final tableField = find.byType(TextField).first;
    await tester.tap(tableField);
    await tester.enterText(tableField, '12');
    await tester.pump();

    expect(container.read(cartProvider).tableNumber, isNull);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    expect(container.read(cartProvider).tableNumber, '12');
  });

  testWidgets(
    'cart special requests draft commits on blur, not each keystroke',
    (tester) async {
      final container = buildContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: CartScreen()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.text('Notes'));
      await tester.pump(const Duration(milliseconds: 300));

      final requestsField = find.byType(TextField).first;
      await tester.enterText(requestsField, 'No onions');
      await tester.pump();

      expect(container.read(cartProvider).specialRequests, isNull);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      expect(container.read(cartProvider).specialRequests, 'No onions');
    },
  );
}
