import 'dart:async';

import 'package:core_pkg/constants/enums.dart';
import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/providers/providers.dart';
import 'package:dinein_app/features/venue/settings/venue_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ui/widgets/shared_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const testVenue = Venue(
    id: 'venue_1',
    name: 'Harbor Table',
    slug: 'harbor-table',
    category: 'Mediterranean',
    description: 'Seafront dining.',
    address: 'Valletta Waterfront',
    status: VenueStatus.active,
    orderingEnabled: true,
    country: Country.mt,
  );

  Widget buildSettings({Venue? venue = testVenue, bool throwError = false}) {
    return ProviderScope(
      overrides: [
        currentVenueProvider.overrideWith((ref) {
          if (throwError) throw Exception('Network error');
          return Future.value(venue);
        }),
        currentUserProvider.overrideWithValue(null),
      ],
      child: MaterialApp(
        home: const Scaffold(body: VenueSettingsScreen()),
      ),
    );
  }

  // ─── Loading State ───

  testWidgets('shows skeleton loader during loading', (tester) async {
    // Use a Completer that never completes to keep provider in loading state
    // without leaving pending timers.
    final completer = Completer<Venue?>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentVenueProvider.overrideWith((ref) => completer.future),
          currentUserProvider.overrideWithValue(null),
        ],
        child: MaterialApp(
          home: const Scaffold(body: VenueSettingsScreen()),
        ),
      ),
    );

    // Pump once (provider starts loading)
    await tester.pump();

    // Should show the SkeletonLoader during loading
    expect(find.byType(SkeletonLoader), findsWidgets);

    // Complete to avoid dangling future
    completer.complete(null);
    await tester.pumpAndSettle();
  });

  // ─── Error State ───

  testWidgets('shows ErrorState when provider fails', (tester) async {
    await tester.pumpWidget(buildSettings(throwError: true));
    await tester.pumpAndSettle();

    expect(find.text('Could not load venue.'), findsOneWidget);
  });

  // ─── Empty State ───

  testWidgets('shows EmptyState when venue is null', (tester) async {
    await tester.pumpWidget(buildSettings(venue: null));
    await tester.pumpAndSettle();

    expect(find.text('No Venue Access'), findsOneWidget);
    expect(find.text('No venue linked to this account.'), findsOneWidget);
  });

  // ─── Data Populated ───

  testWidgets('renders Settings header', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildSettings());
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('VENUE MANAGEMENT'), findsOneWidget);
  });

  testWidgets('renders venue configuration tiles', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildSettings());
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('VENUE CONFIGURATION'), findsOneWidget);
    expect(find.text('Venue Profile'), findsOneWidget);
    expect(find.text('Opening Hours'), findsOneWidget);
    expect(find.text('Venue QR Codes'), findsOneWidget);
    expect(find.text('WiFi Sharing'), findsOneWidget);
  });

  testWidgets('renders preferences and safety tiles', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildSettings());
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('PREFERENCES & SAFETY'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Language & Region'), findsOneWidget);
    expect(find.text('Legal & Policies'), findsOneWidget);
  });

  testWidgets('renders sign out button', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildSettings());
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('SIGN OUT'), findsOneWidget);
  });

  testWidgets('displays venue name in manager card when no user metadata',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildSettings());
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // When currentUser is null, managerName falls back to venue.name
    expect(find.text('Harbor Table'), findsWidgets);
  });
}
