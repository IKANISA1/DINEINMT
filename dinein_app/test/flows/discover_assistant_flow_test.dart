import 'package:db_pkg/models/guest_venue_feed.dart';
import 'package:db_pkg/models/models.dart';
import 'package:dinein_app/core/providers/providers.dart';
import 'package:dinein_app/features/guest/discover/discover_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ui/theme/app_theme.dart';

const _discoverTestVenues = <Venue>[];

final _discoverTestFeed = GuestVenueFeed.fromVenues(_discoverTestVenues);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('discover screen exposes the current hero and empty state', (
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
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(0.8)),
            child: child!,
          ),
          home: const Scaffold(body: DiscoverScreen()),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Find a place quickly.'), findsOneWidget);
    expect(
      find.text('Search once, scan faster, and keep the screen quiet.'),
      findsOneWidget,
    );
    expect(find.text('All venues'), findsOneWidget);
    expect(find.text('No venues'), findsOneWidget);
    expect(find.text('Try a different name or area.'), findsOneWidget);

    await tester.pumpAndSettle();
  });
}
