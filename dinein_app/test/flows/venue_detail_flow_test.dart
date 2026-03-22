import 'package:dinein_app/core/models/models.dart';
import 'package:dinein_app/core/providers/providers.dart';
import 'package:dinein_app/core/services/guest_wifi_service.dart';
import 'package:dinein_app/features/guest/venue_detail/venue_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

String _todayName() {
  return switch (DateTime.now().weekday) {
    DateTime.monday => 'Monday',
    DateTime.tuesday => 'Tuesday',
    DateTime.wednesday => 'Wednesday',
    DateTime.thursday => 'Thursday',
    DateTime.friday => 'Friday',
    DateTime.saturday => 'Saturday',
    DateTime.sunday => 'Sunday',
    _ => 'Monday',
  };
}

class _FakeGuestWifiService extends GuestWifiService {
  _FakeGuestWifiService(this.result);

  final GuestWifiConnectResult result;

  @override
  Future<GuestWifiConnectResult> connectToVenueWifi(Venue venue) async {
    return result;
  }
}

void main() {
  testWidgets('venue detail exposes phone, website, and opening-hours chips', (
    tester,
  ) async {
    final venue = Venue(
      id: 'venue_1',
      name: 'Harbor Table',
      slug: 'harbor-table',
      category: 'Seafood',
      description: 'Seafront seafood dining with sunset views.',
      address: 'Valletta Waterfront',
      phone: '+356 9999 1111',
      websiteUrl: 'https://harbortable.mt',
      rating: 4.8,
      ratingCount: 210,
      openingHours: {
        _todayName(): const OpeningHours(open: '09:00', close: '22:00'),
      },
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
        child: const MaterialApp(home: VenueDetailScreen(slug: 'harbor-table')),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();

    expect(find.text('+356 9999 1111'), findsOneWidget);
    expect(find.text('WEBSITE'), findsOneWidget);
    expect(find.text('OPEN UNTIL 10 PM'), findsOneWidget);
  });

  testWidgets(
    'venue detail shows the connect to wifi chip when the venue shares WiFi',
    (tester) async {
      const venue = Venue(
        id: 'venue_wifi',
        name: 'Harbor Table',
        slug: 'harbor-table',
        category: 'Seafood',
        description: 'Seafront seafood dining with sunset views.',
        address: 'Valletta Waterfront',
        wifiSsid: 'HarborGuest',
        wifiPassword: 'seaside123',
        wifiSecurity: 'WPA',
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
            guestWifiServiceProvider.overrideWithValue(
              _FakeGuestWifiService(
                const GuestWifiConnectResult.connected('Connected.'),
              ),
            ),
          ],
          child: const MaterialApp(
            home: VenueDetailScreen(slug: 'harbor-table'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('About'));
      await tester.pumpAndSettle();

      expect(find.text('CONNECT TO WIFI'), findsOneWidget);
    },
  );

  testWidgets(
    'venue detail hides the connect to wifi chip when the venue has no WiFi',
    (tester) async {
      const venue = Venue(
        id: 'venue_nowifi',
        name: 'Morning Edit',
        slug: 'morning-edit',
        category: 'Cafe',
        description: 'Coffee and pastries.',
        address: 'Sliema Front',
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
            guestWifiServiceProvider.overrideWithValue(
              _FakeGuestWifiService(
                const GuestWifiConnectResult.connected('Connected.'),
              ),
            ),
          ],
          child: const MaterialApp(
            home: VenueDetailScreen(slug: 'morning-edit'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('About'));
      await tester.pumpAndSettle();

      expect(find.text('CONNECT TO WIFI'), findsNothing);
    },
  );

  testWidgets('venue detail WiFi chip falls back to shared WiFi details', (
    tester,
  ) async {
    const venue = Venue(
      id: 'venue_wifi',
      name: 'Harbor Table',
      slug: 'harbor-table',
      category: 'Seafood',
      description: 'Seafront seafood dining with sunset views.',
      address: 'Valletta Waterfront',
      wifiSsid: 'HarborGuest',
      wifiPassword: 'seaside123',
      wifiSecurity: 'WPA',
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
          guestWifiServiceProvider.overrideWithValue(
            _FakeGuestWifiService(
              const GuestWifiConnectResult.fallback(
                'Could not join automatically. Use the WiFi details instead.',
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: VenueDetailScreen(slug: 'harbor-table')),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('CONNECT TO WIFI'));
    await tester.pumpAndSettle();

    expect(find.text('HarborGuest'), findsOneWidget);
    expect(find.text('TAP TO COPY PASSWORD'), findsOneWidget);
  });

  testWidgets(
    'venue detail prioritizes venue-selected highlights and fills remaining slots with fallback items',
    (tester) async {
      const venue = Venue(
        id: 'venue_highlights',
        name: 'Harbor Table',
        slug: 'harbor-table',
        category: 'Seafood',
        description: 'Seafront seafood dining with sunset views.',
        address: 'Valletta Waterfront',
      );

      final items = [
        MenuItem(
          id: 'item_fallback_1',
          venueId: venue.id,
          name: 'Fallback One',
          description: 'Automatic fallback item.',
          price: 10,
          category: 'Mains',
        ),
        MenuItem(
          id: 'item_selected_2',
          venueId: venue.id,
          name: 'Selected Two',
          description: 'Manually chosen second.',
          price: 12,
          category: 'Mains',
          highlightRank: 2,
        ),
        MenuItem(
          id: 'item_fallback_2',
          venueId: venue.id,
          name: 'Fallback Two',
          description: 'Should stay outside the top three.',
          price: 14,
          category: 'Mains',
        ),
        MenuItem(
          id: 'item_selected_1',
          venueId: venue.id,
          name: 'Selected One',
          description: 'Manually chosen first.',
          price: 16,
          category: 'Mains',
          highlightRank: 1,
        ),
      ];

      await tester.binding.setSurfaceSize(const Size(430, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            venueBySlugProvider(venue.slug).overrideWith((ref) async => venue),
            menuItemsProvider(venue.id).overrideWith((ref) async => items),
          ],
          child: const MaterialApp(
            home: VenueDetailScreen(slug: 'harbor-table'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.scrollUntilVisible(
        find.text('Selected One'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Selected One'), findsOneWidget);
      expect(find.text('Selected Two'), findsOneWidget);
      expect(find.text('Fallback One'), findsOneWidget);
      expect(find.text('Fallback Two'), findsNothing);
    },
  );

  testWidgets('venue detail see all action keeps a full touch target', (
    tester,
  ) async {
    const venue = Venue(
      id: 'venue_touch_target',
      name: 'Harbor Table',
      slug: 'harbor-table',
      category: 'Seafood',
      description: 'Seafront seafood dining with sunset views.',
      address: 'Valletta Waterfront',
    );

    final items = [
      MenuItem(
        id: 'item_selected_1',
        venueId: venue.id,
        name: 'Selected One',
        description: 'Manually chosen first.',
        price: 16,
        category: 'Mains',
        highlightRank: 1,
      ),
    ];

    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          venueBySlugProvider(venue.slug).overrideWith((ref) async => venue),
          menuItemsProvider(venue.id).overrideWith((ref) async => items),
        ],
        child: const MaterialApp(home: VenueDetailScreen(slug: 'harbor-table')),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('venue-detail-see-all-action')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final actionSize = tester.getSize(
      find.byKey(const ValueKey('venue-detail-see-all-action')),
    );

    expect(actionSize.width, greaterThanOrEqualTo(96));
    expect(actionSize.height, greaterThanOrEqualTo(48));
  });
}
