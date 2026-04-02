import 'package:dinein_app/core/config/country_config.dart';
import 'package:dinein_app/core/models/models.dart';
import 'package:dinein_app/core/providers/providers.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:dinein_app/core/router/app_router.dart';
import 'package:dinein_app/features/guest/venue_detail/venue_detail_screen.dart';
import 'package:dinein_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Error state edge cases', () {
    testWidgets('venue detail with no phone shows no call chip', (
      tester,
    ) async {
      const venue = Venue(
        id: 'venue_1',
        name: 'Silent Venue',
        slug: 'silent-venue',
        category: 'Restaurants',
        description: 'No phone number.',
        address: 'Valletta',
        // phone is null
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
            home: VenueDetailScreen(slug: 'silent-venue'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('About'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('CALL'), findsNothing);
    });

    testWidgets('venue detail with empty description renders gracefully', (
      tester,
    ) async {
      const venue = Venue(
        id: 'venue_2',
        name: 'Minimal Venue',
        slug: 'minimal-venue',
        category: 'Bar',
        description: '',
        address: 'Sliema',
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
            home: VenueDetailScreen(slug: 'minimal-venue'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Should render without errors
      expect(find.text('Minimal Venue'), findsOneWidget);
    });
  });

  group('Order success edge cases', () {
    setUp(() => appRouter.goNamed(AppRouteNames.splash));

    testWidgets('order success with empty orderId still renders', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(child: DineInApp(config: CountryConfig.mt)),
      );
      await tester.pump();

      appRouter.goNamed(
        AppRouteNames.orderSuccess,
        queryParameters: {AppRouteParams.id: ''},
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should navigate without crash
      expect(appRouter.state.uri.path, AppRoutePaths.orderSuccess);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('Admin flow edge cases', () {
    setUp(() => appRouter.goNamed(AppRouteNames.splash));

    testWidgets('admin overview redirects to login when not authenticated', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(child: DineInApp(config: CountryConfig.mt)),
      );
      await tester.pump();

      appRouter.go(AppRoutePaths.adminOverview);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Without auth should redirect to login
      expect(appRouter.state.uri.path, AppRoutePaths.adminLogin);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
