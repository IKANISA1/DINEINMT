import 'package:dinein_app/core/constants/enums.dart';
import 'package:dinein_app/core/models/models.dart';
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

    expect(
      find.text(
        'Manual images stay authoritative. Update the URL below and save to replace it.',
      ),
      findsOneWidget,
    );
    expect(find.text('MANUAL IMAGE ACTIVE'), findsOneWidget);
    expect(find.text('Protect current image'), findsNothing);
    expect(find.text('https://example.com/images/ribeye.jpg'), findsOneWidget);
  });
}
