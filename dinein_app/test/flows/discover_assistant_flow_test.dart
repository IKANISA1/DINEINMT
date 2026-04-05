import 'package:db_pkg/models/guest_venue_feed.dart';
import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/providers/providers.dart';
import 'package:dinein_app/features/guest/discover/discover_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _discoverTestVenues = [
  Venue(
    id: 'venue_1',
    name: 'Harbor Table',
    slug: 'harbor-table',
    category: 'Seafood',
    description: 'Seafront seafood dining with sunset views.',
    address: 'Valletta Waterfront',
    rating: 4.8,
    ratingCount: 210,
  ),
  Venue(
    id: 'venue_2',
    name: 'Morning Edit',
    slug: 'morning-edit',
    category: 'Cafe',
    description: 'Coffee and brunch studio.',
    address: 'St Julian\'s',
    rating: 4.3,
    ratingCount: 75,
  ),
];

final _discoverTestFeed = GuestVenueFeed.fromVenues(_discoverTestVenues);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('discover screen exposes the hero and featured venues', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guestVenueFeedProvider(
            const GuestVenueQuery(limit: 12),
          ).overrideWith((ref) async => _discoverTestFeed),
        ],
        child: const MaterialApp(home: Scaffold(body: DiscoverScreen())),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('FIND YOUR '), findsOneWidget);
    expect(find.text('FLAVOR'), findsOneWidget);
    expect(find.text('Featured'), findsOneWidget);
    expect(find.text('All Venues'), findsOneWidget);

    await tester.pumpAndSettle();
  });
}
