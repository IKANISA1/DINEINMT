import 'package:core_pkg/constants/enums.dart';
import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/providers/providers.dart';
import 'package:dinein_app/features/venue/menu/venue_edit_item_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('menu editor treats manual images as authoritative', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    const venue = Venue(
      id: 'venue_1',
      name: 'Harbor Table',
      slug: 'harbor-table',
      category: 'Restaurants',
      description: 'Seafront dining.',
      address: 'Valletta Waterfront',
    );

    const item = MenuItem(
      id: 'item_1',
      venueId: 'venue_1',
      name: 'Dry-Aged Ribeye',
      description: 'Charcoal grilled with rosemary butter.',
      price: 48,
      category: 'Signature Mains',
      imageUrl: 'https://example.com/images/ribeye.jpg',
      imageSource: MenuItemImageSource.manual,
      imageStatus: MenuItemImageStatus.ready,
      imageLocked: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentVenueProvider.overrideWith((ref) async => venue),
          menuItemsProvider(venue.id).overrideWith((ref) async => [item]),
        ],
        child: const MaterialApp(home: VenueEditItemScreen(itemId: 'item_1')),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('MANUAL IMAGE ACTIVE'), findsOneWidget);
    // Manual-image items hide the "Protect current image" toggle (source code #883)
    expect(find.text('Protect current image'), findsNothing);
  });

  testWidgets('menu editor opens detail sheet before generating an image', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    const venue = Venue(
      id: 'venue_1',
      name: 'Harbor Table',
      slug: 'harbor-table',
      category: 'Restaurants',
      description: 'Seafront dining.',
      address: 'Valletta Waterfront',
    );

    const item = MenuItem(
      id: 'item_1',
      venueId: 'venue_1',
      name: 'Dry-Aged Ribeye',
      description: 'Charcoal grilled with rosemary butter.',
      price: 48,
      category: 'Signature Mains',
      itemClass: MenuItemClass.food,
      imageStatus: MenuItemImageStatus.ready,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentVenueProvider.overrideWith((ref) async => venue),
          menuItemsProvider(venue.id).overrideWith((ref) async => [item]),
        ],
        child: const MaterialApp(home: VenueEditItemScreen(itemId: 'item_1')),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('GENERATE IMAGE'));
    await tester.pumpAndSettle();

    expect(find.text('Generate Item Image'), findsOneWidget);
    expect(find.text('CLASS'), findsOneWidget);
    expect(find.text('CATEGORY'), findsOneWidget);
    expect(find.text('DESCRIPTION'), findsOneWidget);
  });
}
