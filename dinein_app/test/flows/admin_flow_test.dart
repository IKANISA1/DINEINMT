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

  Future<void> pumpUntilVisible(
    WidgetTester tester,
    Finder finder, {
    Duration step = const Duration(milliseconds: 100),
    int maxPumps = 50,
  }) async {
    for (var index = 0; index < maxPumps; index++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.pump(step);
    }
    expect(finder, findsWidgets);
  }

  group('Admin Flow Smoke Tests', () {
    testWidgets('admin activation route redirects to admin login', (
      tester,
    ) async {
      await pumpApp(tester);
      appRouter.go(AppRoutePaths.adminOverview);
      await tester.pump();
      await pumpUntilVisible(tester, find.text('Secure Access'));
      expect(appRouter.state.uri.path, AppRoutePaths.adminLogin);
      expect(find.text('ADMIN'), findsWidgets);
      expect(find.text('Get OTP'), findsOneWidget);
      await disposeApp(tester);
    });
  });
}
