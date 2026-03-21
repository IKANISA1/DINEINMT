import 'package:dinein_app/core/models/models.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('discover screen exposes the search hero and featured venues', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          venuesProvider.overrideWith((ref) async => _discoverTestVenues),
        ],
        child: const MaterialApp(home: Scaffold(body: DiscoverScreen())),
      ),
    );

    // Allow async provider to resolve and animations to settle.
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Search bar is present in the hero section.
    expect(find.byType(TextField), findsOneWidget);
    // Search hint text is present.
    expect(find.text('Search venues...'), findsOneWidget);
    // GO button is rendered.
    expect(find.text('GO'), findsOneWidget);
    // Active venues header (below featured).
    expect(find.text('Active Venues'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('discover search switches the screen into results mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          venuesProvider.overrideWith((ref) async => _discoverTestVenues),
        ],
        child: const MaterialApp(home: Scaffold(body: DiscoverScreen())),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.enterText(find.byType(TextField).first, 'waterfront');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('waterfront'), findsOneWidget);
    expect(find.text('Results'), findsOneWidget);
    expect(find.text('Featured'), findsNothing);
  });
}
