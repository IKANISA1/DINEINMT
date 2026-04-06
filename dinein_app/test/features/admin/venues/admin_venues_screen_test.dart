import 'package:core_pkg/config/country_config.dart';
import 'package:core_pkg/config/country_runtime.dart';
import 'package:core_pkg/constants/enums.dart';
import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/providers/venue_providers.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/shared_widgets.dart';
import 'package:dinein_app/features/admin/venues/admin_venues_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<Venue> buildVenues() => [
    Venue(
      id: 'venue-1',
      name: 'Harbor Table',
      slug: 'harbor-table',
      category: 'Restaurants',
      description: 'Harbor-facing dining.',
      address: '45 Tower Rd, Sliema, Malta',
      status: VenueStatus.active,
      orderingEnabled: true,
      country: Country.mt,
    ),
    Venue(
      id: 'venue-2',
      name: 'Sky Lounge',
      slug: 'sky-lounge',
      category: 'Bar',
      description: 'Rooftop cocktail bar.',
      address: '12 Republic St, Valletta',
      status: VenueStatus.inactive,
      orderingEnabled: false,
      country: Country.mt,
    ),
    Venue(
      id: 'venue-3',
      name: 'Cafe Roma',
      slug: 'cafe-roma',
      category: 'Restaurants',
      description: 'Italian-inspired cafe.',
      address: '8 Mdina Rd, Rabat',
      status: VenueStatus.active,
      orderingEnabled: true,
      country: Country.mt,
    ),
  ];

  Future<void> pumpVenuesScreen(
    WidgetTester tester, {
    required List<Venue> venues,
  }) async {
    CountryRuntime.configure(CountryConfig.mt);

    await tester.binding.setSurfaceSize(const Size(1440, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allVenuesProvider.overrideWith((ref) async => venues),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const AdminVenuesScreen(),
        ),
      ),
    );

    // Let animations + async provider complete
    await tester.pumpAndSettle();
  }

  testWidgets('admin venues screen renders header and venue list', (
    tester,
  ) async {
    await pumpVenuesScreen(tester, venues: buildVenues());

    // Header
    expect(find.text('Venues'), findsWidgets);

    // "NEW VENUE" button
    expect(find.text('NEW VENUE'), findsOneWidget);

    // Active tab should show active venues by default
    expect(find.text('Harbor Table'), findsOneWidget);
    expect(find.text('Cafe Roma'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('admin venues screen renders empty state when no venues', (
    tester,
  ) async {
    await pumpVenuesScreen(tester, venues: <Venue>[]);

    // Header should always render
    expect(find.text('Venues'), findsWidgets);

    // Empty list should show EmptyState or an indication of no data
    final hasEmpty = find.byType(EmptyState).evaluate().isNotEmpty;
    final hasNoDataIndicator = find.text('No venues').evaluate().isNotEmpty ||
        find.text('0').evaluate().isNotEmpty ||
        find.text('No active venues').evaluate().isNotEmpty;
    expect(hasEmpty || hasNoDataIndicator, isTrue,
        reason: 'Empty venue list should show EmptyState or empty indication');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('admin venues screen shows error state with retry', (
    tester,
  ) async {
    CountryRuntime.configure(CountryConfig.mt);

    await tester.binding.setSurfaceSize(const Size(1440, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allVenuesProvider.overrideWith(
            (ref) async => throw Exception('Network error'),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const AdminVenuesScreen(),
        ),
      ),
    );

    // Let provider resolve to error state
    await tester.pumpAndSettle();

    // Error state should show ErrorState with retry
    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text('Could not load venues.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('admin venues screen separates active and inactive venues', (
    tester,
  ) async {
    await pumpVenuesScreen(tester, venues: buildVenues());

    // Default tab is 'active', so inactive venue Sky Lounge should NOT be visible
    expect(find.text('Sky Lounge'), findsNothing);

    // Active venues should be visible
    expect(find.text('Harbor Table'), findsOneWidget);
    expect(find.text('Cafe Roma'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
