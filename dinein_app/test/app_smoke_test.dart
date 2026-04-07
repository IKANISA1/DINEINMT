import 'package:core_pkg/config/country_config.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:dinein_app/core/router/app_router.dart';
import 'package:dinein_app/core/services/app_bootstrap_service.dart';
import 'package:dinein_app/main.dart';
import 'package:ui/widgets/brand_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppBootstrapService.instance.resetForTest();
    appRouter.goNamed(AppRouteNames.splash);
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    bool bootstrapReady = true,
  }) async {
    if (bootstrapReady) {
      AppBootstrapService.instance.markReadyForTest();
    }
    await tester.pumpWidget(
      ProviderScope(child: DineInApp(config: CountryConfig.mt)),
    );
    await tester.pump();
  }

  /// Drain all pending timers (OrderReceiptService, notification service,
  /// Riverpod keepAlive, etc.) then safely dispose the widget tree.
  Future<void> disposeApp(WidgetTester tester) async {
    // Pump enough to exhaust all pending timers (notification init can take
    // several seconds, plus secure-storage timeout).
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pumpWidget(const SizedBox.shrink());
    // Final drain for any teardown timers spawned by dispose.
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  testWidgets('renders the splash screen on startup', (tester) async {
    await pumpApp(tester, bootstrapReady: false);

    // Wait for animations to settle enough to show content
    await tester.pump(const Duration(milliseconds: 1200));

    // The splash shows a DineInLogoText (branded wordmark) + loading spinner
    expect(find.byType(DineInLogoText), findsOneWidget);
    expect(find.byType(BrandMark), findsNothing);

    // Splash has a loading spinner, no tagline text
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('splash redirects to discover once bootstrap completes', (
    tester,
  ) async {
    await pumpApp(tester, bootstrapReady: false);

    AppBootstrapService.instance.markReadyForTest();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(appRouter.state.uri.path, AppRoutePaths.discover);

    await disposeApp(tester);
  });

  testWidgets('venue login route navigates to login path', (
    tester,
  ) async {
    await pumpApp(tester);

    appRouter.goNamed(AppRouteNames.venueLogin);
    await tester.pump();
    // Allow time for deferred loading and route resolution
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // Verify the route resolved to the venue login path
    expect(
      appRouter.state.uri.path,
      AppRoutePaths.venueLogin,
    );

    await disposeApp(tester);
  });

  testWidgets('order success route navigates successfully', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpApp(tester);

    appRouter.goNamed(
      AppRouteNames.orderSuccess,
      queryParameters: {
        AppRouteParams.id: 'ORD-1234',
        AppRouteParams.orderNumber: '12345678',
      },
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Verify navigated to order success path
    expect(
      appRouter.state.uri.path,
      AppRoutePaths.orderSuccess,
    );

    await disposeApp(tester);
  });
}
