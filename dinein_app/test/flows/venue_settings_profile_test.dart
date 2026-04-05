import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/providers/providers.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:dinein_app/features/venue/settings/venue_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // Helper to build the screen wrapped in GoRouter for pushNamed support
  Widget buildScreen(Venue venue) {
    final router = GoRouter(
      initialLocation: AppRoutePaths.venueSettings,
      routes: [
        GoRoute(
          path: AppRoutePaths.venueSettings,
          name: AppRouteNames.venueSettings,
          builder: (_, _) => const VenueSettingsScreen(),
        ),
        // Stub routes to absorb pushNamed calls
        GoRoute(
          path: AppRoutePaths.venueProfile,
          name: AppRouteNames.venueProfile,
          builder: (_, _) => const Scaffold(body: Text('Profile Screen')),
        ),
        GoRoute(
          path: AppRoutePaths.venueHours,
          name: AppRouteNames.venueHours,
          builder: (_, _) => const Scaffold(body: Text('Hours Screen')),
        ),
        GoRoute(
          path: AppRoutePaths.venueWifi,
          name: AppRouteNames.venueWifi,
          builder: (_, _) => const Scaffold(body: Text('WiFi Screen')),
        ),
        GoRoute(
          path: AppRoutePaths.venueTableQr,
          name: AppRouteNames.venueTableQr,
          builder: (_, _) => const Scaffold(body: Text('Venue QR Screen')),
        ),
        GoRoute(
          path: AppRoutePaths.venueNotifications,
          name: AppRouteNames.venueNotifications,
          builder: (_, _) => const Scaffold(body: Text('Notifications Screen')),
        ),
        GoRoute(
          path: AppRoutePaths.venueLanguageRegion,
          name: AppRouteNames.venueLanguageRegion,
          builder: (_, _) => const Scaffold(body: Text('Language Screen')),
        ),
        GoRoute(
          path: AppRoutePaths.venueLegal,
          name: AppRouteNames.venueLegal,
          builder: (_, _) => const Scaffold(body: Text('Legal Screen')),
        ),
        GoRoute(
          path: AppRoutePaths.splash,
          builder: (_, _) => const Scaffold(body: Text('Splash')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [currentVenueProvider.overrideWith((ref) async => venue)],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets(
    'venue settings renders section headers and key configuration tiles',
    (tester) async {
      const venue = Venue(
        id: 'venue_1',
        name: 'Harbor Table',
        slug: 'harbor-table',
        category: 'Mediterranean',
        description: 'Seafront dining.',
        address: 'Valletta Waterfront',
        phone: '+35679991234',
        email: 'concierge@harbortable.mt',
      );

      await tester.pumpWidget(buildScreen(venue));
      await tester.pump();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Page header
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('VENUE MANAGEMENT'), findsOneWidget);

      // First section header
      expect(find.text('VENUE CONFIGURATION'), findsOneWidget);

      // Key tiles in the first section
      expect(find.text('Venue Profile'), findsOneWidget);
      expect(find.text('Opening Hours'), findsOneWidget);
      expect(find.text('Venue QR Codes'), findsOneWidget);

      // Owner card shows venue name
      expect(find.text('Harbor Table'), findsAtLeast(1));

      // Scroll down to reveal more tiles
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();

      // WiFi tile should be visible
      expect(find.text('WiFi Sharing'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle(const Duration(seconds: 2));
    },
  );

  testWidgets('venue settings QR tile navigates to QR screen', (tester) async {
    const venue = Venue(
      id: 'venue_1',
      name: 'Harbor Table',
      slug: 'harbor-table',
      category: 'Mediterranean',
      description: 'Seafront dining.',
      address: 'Valletta Waterfront',
      phone: '+35679991234',
      email: 'concierge@harbortable.mt',
    );

    await tester.pumpWidget(buildScreen(venue));
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text('Venue QR Codes'));
    await tester.pumpAndSettle();

    expect(find.text('Venue QR Screen'), findsOneWidget);
  });

  testWidgets('venue settings WiFi tile navigates to WiFi screen', (
    tester,
  ) async {
    const venue = Venue(
      id: 'venue_1',
      name: 'Harbor Table',
      slug: 'harbor-table',
      category: 'Mediterranean',
      description: 'Seafront dining.',
      address: 'Valletta Waterfront',
      phone: '+35679991234',
      email: 'concierge@harbortable.mt',
    );

    await tester.pumpWidget(buildScreen(venue));
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Scroll to reveal WiFi tile
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    // Tap WiFi Sharing tile
    await tester.tap(find.text('WiFi Sharing'));
    await tester.pumpAndSettle();

    // Should navigate to the WiFi screen stub
    expect(find.text('WiFi Screen'), findsOneWidget);
  });
}
