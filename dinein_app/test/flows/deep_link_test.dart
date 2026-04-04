import 'package:core_pkg/config/country_config.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:dinein_app/core/router/app_router.dart';
import 'package:dinein_app/core/services/app_bootstrap_service.dart';
import 'package:dinein_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppBootstrapService.instance.markReadyForTest();
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

  group('Deep link flow tests', () {
    testWidgets('/v/{slug} deep link navigates to venue detail', (
      tester,
    ) async {
      await pumpApp(tester);

      appRouter.go('/v/harbor-table');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Current location should be the deep link path
      expect(appRouter.state.uri.path, '/v/harbor-table');

      await disposeApp(tester);
    });

    testWidgets('/v/{slug}?t=12 deep link includes table number param', (
      tester,
    ) async {
      await pumpApp(tester);

      appRouter.go('/v/harbor-table?t=12');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(appRouter.state.uri.path, '/v/harbor-table');
      expect(appRouter.state.uri.queryParameters['t'], '12');

      await disposeApp(tester);
    });
  });

  group('Admin redirect tests', () {
    testWidgets('/admin redirects to /admin/overview or /admin/login', (
      tester,
    ) async {
      await pumpApp(tester);

      appRouter.go('/admin');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Without auth, admin routes should redirect to login
      final path = appRouter.state.uri.path;
      expect(
        path == AppRoutePaths.adminOverview || path == AppRoutePaths.adminLogin,
        isTrue,
        reason: 'Should redirect to overview (if authed) or login (if not)',
      );

      await disposeApp(tester);
    });
  });
}
