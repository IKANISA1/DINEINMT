import 'package:dinein_app/core/models/models.dart';
import 'package:dinein_app/core/providers/providers.dart';
import 'package:dinein_app/features/guest/venue_detail/venue_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'venue detail exposes a call chip and drops the fake website chip',
    (tester) async {
      const venue = Venue(
        id: 'venue_1',
        name: 'Harbor Table',
        slug: 'harbor-table',
        category: 'Seafood',
        description: 'Seafront seafood dining with sunset views.',
        address: 'Valletta Waterfront',
        phone: '+356 9999 1111',
        rating: 4.8,
        ratingCount: 210,
      );

      await tester.binding.setSurfaceSize(const Size(430, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            venueBySlugProvider(venue.slug).overrideWith((ref) async => venue),
            menuItemsProvider(
              venue.id,
            ).overrideWith((ref) async => const <MenuItem>[]),
          ],
          child: const MaterialApp(
            home: VenueDetailScreen(slug: 'harbor-table'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('About'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('CALL'), findsOneWidget);
      expect(find.text('WEBSITE'), findsNothing);
    },
  );
}
