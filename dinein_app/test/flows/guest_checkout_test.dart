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

  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  group('Guest Checkout Smoke Tests', () {
    testWidgets('splash screen shows brand tagline', (tester) async {
      await pumpApp(tester, bootstrapReady: false);
      // Wait for staggered animations to show content
      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.text('DINE IN, STAND OUT.'), findsOneWidget);
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
  });
}
