import 'package:dinein_app/core/config/country_config.dart';
import 'package:dinein_app/core/config/country_config_provider.dart';
import 'package:dinein_app/core/config/country_runtime.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:dinein_app/core/router/guest_routes.dart';
import 'package:dinein_app/features/guest/settings/guest_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildScreen(CountryConfig config) {
    final router = GoRouter(
      initialLocation: AppRoutePaths.guestSettings,
      routes: [
        GoRoute(
          path: AppRoutePaths.guestSettings,
          name: AppRouteNames.guestSettings,
          builder: (_, _) => const GuestSettingsScreen(),
        ),
        GoRoute(
          path: AppRoutePaths.biopayHome,
          name: AppRouteNames.biopayHome,
          builder: (_, _) => const Scaffold(body: Text('BioPay Home')),
        ),
        GoRoute(
          path: AppRoutePaths.orderHistory,
          name: AppRouteNames.orderHistory,
          builder: (_, _) => const Scaffold(body: Text('Orders')),
        ),
        GoRoute(
          path: AppRoutePaths.venueLogin,
          name: AppRouteNames.venueLogin,
          builder: (_, _) => const Scaffold(body: Text('Venue Portal')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [countryConfigProvider.overrideWithValue(config)],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  Widget buildGuestRouter(CountryConfig config, String initialLocation) {
    CountryRuntime.configure(config);
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: guestRoutes,
    );

    return ProviderScope(
      overrides: [countryConfigProvider.overrideWithValue(config)],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('shows BioPay entry for Rwanda only', (tester) async {
    await tester.pumpWidget(buildScreen(CountryConfig.rw));
    await tester.pumpAndSettle();

    expect(find.text('BioPay'), findsOneWidget);
    expect(find.text('FACE-SCAN PAYMENTS'), findsOneWidget);
  });

  testWidgets('hides BioPay entry for Malta', (tester) async {
    await tester.pumpWidget(buildScreen(CountryConfig.mt));
    await tester.pumpAndSettle();

    expect(find.text('BioPay'), findsNothing);
    expect(find.text('FACE-SCAN PAYMENTS'), findsNothing);
  });

  testWidgets('redirects Malta BioPay home route back to settings', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildGuestRouter(CountryConfig.mt, AppRoutePaths.biopayHome),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GuestSettingsScreen), findsOneWidget);
    expect(find.text('BioPay'), findsNothing);
  });

  testWidgets('redirects invalid Rwanda BioPay confirm route to settings', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildGuestRouter(CountryConfig.rw, AppRoutePaths.biopayConfirm),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GuestSettingsScreen), findsOneWidget);
    expect(find.text('Confirm Payment'), findsNothing);
  });
}
