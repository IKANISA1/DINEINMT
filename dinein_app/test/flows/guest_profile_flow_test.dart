import 'package:dinein_app/core/providers/providers.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:dinein_app/features/guest/settings/guest_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _guestUser = User(
  id: 'guest_1',
  appMetadata: {},
  userMetadata: {'display_name': 'Jean Bosco'},
  aud: 'authenticated',
  email: 'jean@example.com',
  createdAt: '2026-03-21T10:00:00.000Z',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildScreen() {
    final router = GoRouter(
      initialLocation: AppRoutePaths.guestSettings,
      routes: [
        GoRoute(
          path: AppRoutePaths.guestSettings,
          name: AppRouteNames.guestSettings,
          builder: (_, _) => const GuestSettingsScreen(),
        ),
        GoRoute(
          path: AppRoutePaths.orderHistory,
          name: AppRouteNames.orderHistory,
          builder: (_, _) => const Scaffold(body: Text('Orders Screen')),
        ),
        GoRoute(
          path: AppRoutePaths.venueLogin,
          name: AppRouteNames.venueLogin,
          builder: (_, _) => const Scaffold(body: Text('Venue Portal Screen')),
        ),
        GoRoute(
          path: AppRoutePaths.venuesBrowse,
          name: AppRouteNames.venuesBrowse,
          builder: (_, _) => const Scaffold(body: Text('Venues Screen')),
        ),
        GoRoute(
          path: AppRoutePaths.splash,
          builder: (_, _) => const Scaffold(body: Text('Splash')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [currentUserProvider.overrideWith((ref) => _guestUser)],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('guest profile matches the guest account design layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildScreen());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Guest'), findsOneWidget);
    expect(find.text('WELCOME TO DINEIN MALTA'), findsOneWidget);
    expect(find.text('Order History'), findsOneWidget);
    expect(find.text('VIEW YOUR PAST ORDERS'), findsOneWidget);
    expect(find.text('Get in Touch'), findsOneWidget);
    expect(find.text('About DINEIN'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Discover Venues'), findsNothing);
    expect(find.text('Terms & Conditions'), findsNothing);
    expect(find.text('SIGN OUT'), findsNothing);

    expect(find.byTooltip('Guest'), findsNothing);
    expect(find.byTooltip('Guest'), findsNothing);
  });

  testWidgets('guest profile order history card routes into orders', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildScreen());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.ensureVisible(find.text('Order History'));
    await tester.tap(find.text('Order History'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Orders Screen'), findsOneWidget);
  });
}
