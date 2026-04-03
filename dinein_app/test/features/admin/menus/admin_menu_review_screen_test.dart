import 'package:dinein_app/core/constants/enums.dart';
import 'package:dinein_app/core/models/models.dart';
import 'package:dinein_app/core/providers/menu_providers.dart';
import 'package:dinein_app/core/providers/venue_providers.dart';
import 'package:dinein_app/features/admin/menus/admin_menu_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('admin menu review reads the admin menu provider', (
    tester,
  ) async {
    const venue = Venue(
      id: 'venue-1',
      name: 'Harbor Table',
      slug: 'harbor-table',
      category: 'Restaurants',
      description: '',
      address: 'Valletta Waterfront',
    );

    const hiddenItem = MenuItem(
      id: 'item-1',
      venueId: 'venue-1',
      name: 'Hidden Tasting Menu',
      description: 'Only admin should see this item from the review queue.',
      price: 89,
      category: 'Chef Specials',
      isAvailable: false,
      imageStatus: MenuItemImageStatus.ready,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          venueByIdProvider(venue.id).overrideWith((ref) async => venue),
          menuItemsProvider(venue.id).overrideWith((ref) async => const []),
          adminMenuItemsProvider(
            venue.id,
          ).overrideWith((ref) async => [hiddenItem]),
        ],
        child: MaterialApp(home: AdminMenuReviewScreen(venueId: venue.id)),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Hidden Tasting Menu'), findsOneWidget);
    expect(find.text('89.00 • Unavailable'), findsOneWidget);
  });
}
