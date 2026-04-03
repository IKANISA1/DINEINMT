import 'package:dinein_app/core/config/country_config.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:dinein_app/core/router/app_router.dart';
import 'package:dinein_app/core/services/app_bootstrap_service.dart';
import 'package:dinein_app/core/services/auth_repository.dart';
import 'package:dinein_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppBootstrapService.instance.markReadyForTest();
    await AuthRepository.instance.clearVenueSession();
    await AuthRepository.instance.clearAdminSession();
    appRouter.goNamed(AppRouteNames.splash);
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(child: DineInApp(config: CountryConfig.mt)),
    );
    await tester.pump();
  }

  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  // ─── venueAuthGuard ───

  group('venueAuthGuard integration', () {
    testWidgets('venue dashboard redirects to venue login when no session', (
      tester,
    ) async {
      await pumpApp(tester);

      appRouter.go(AppRoutePaths.venueDashboard);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(appRouter.state.uri.path, AppRoutePaths.venueLogin);
      expect(
        appRouter.state.uri.queryParameters[AppRouteParams.returnTo],
        AppRoutePaths.venueDashboard,
      );
      await disposeApp(tester);
    });

    testWidgets('venue orders redirects to venue login when no session', (
      tester,
    ) async {
      await pumpApp(tester);

      appRouter.go(AppRoutePaths.venueOrders);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(appRouter.state.uri.path, AppRoutePaths.venueLogin);
      await disposeApp(tester);
    });

    testWidgets('venue menu redirects to venue login when no session', (
      tester,
    ) async {
      await pumpApp(tester);

      appRouter.go(AppRoutePaths.venueMenu);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(appRouter.state.uri.path, AppRoutePaths.venueLogin);
      await disposeApp(tester);
    });

    testWidgets('venue settings redirects to venue login when no session', (
      tester,
    ) async {
      await pumpApp(tester);

      appRouter.go(AppRoutePaths.venueSettings);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(appRouter.state.uri.path, AppRoutePaths.venueLogin);
      await disposeApp(tester);
    });
  });

  // ─── adminRoleGuard ───

  group('adminRoleGuard integration', () {
    testWidgets('admin overview redirects to admin login when no session', (
      tester,
    ) async {
      await pumpApp(tester);

      appRouter.go(AppRoutePaths.adminOverview);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(appRouter.state.uri.path, AppRoutePaths.adminLogin);
      await disposeApp(tester);
    });

    testWidgets('admin venues redirects to admin login when no session', (
      tester,
    ) async {
      await pumpApp(tester);

      appRouter.go(AppRoutePaths.adminVenues);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(appRouter.state.uri.path, AppRoutePaths.adminLogin);
      await disposeApp(tester);
    });

    testWidgets('admin settings redirects to admin login when no session', (
      tester,
    ) async {
      await pumpApp(tester);

      appRouter.go(AppRoutePaths.adminSettings);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(appRouter.state.uri.path, AppRoutePaths.adminLogin);
      await disposeApp(tester);
    });
  });
}
