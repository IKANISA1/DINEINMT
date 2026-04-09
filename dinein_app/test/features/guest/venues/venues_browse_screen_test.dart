import 'package:db_pkg/models/guest_venue_feed.dart';
import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/providers/providers.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:dinein_app/features/guest/venues/venues_browse_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _browseTestVenues = [
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
];

final _browseTestFeed = GuestVenueFeed.fromVenues(_browseTestVenues);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('route search intent opens the venues search sheet', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation:
          '${AppRoutePaths.venuesBrowse}?${AppRouteParams.search}=1',
      routes: [
        GoRoute(
          path: AppRoutePaths.venuesBrowse,
          name: AppRouteNames.venuesBrowse,
          builder: (context, state) => const VenuesBrowseScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guestVenueFeedProvider(
            const GuestVenueQuery(limit: 18),
          ).overrideWith((ref) async => _browseTestFeed),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Search venues...'), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.queryParameters.containsKey(
        AppRouteParams.search,
      ),
      isFalse,
    );
  });
}
