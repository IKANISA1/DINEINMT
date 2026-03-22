import 'package:dinein_app/core/config/country_config.dart';
import 'package:dinein_app/core/config/country_config_provider.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:dinein_app/core/router/app_router.dart';
import 'package:dinein_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appRouter.goNamed(AppRouteNames.splash);
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [countryConfigProvider.overrideWithValue(CountryConfig.mt)],
        child: DineInApp(config: CountryConfig.mt),
      ),
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
    int maxPumps = 30,
  }) async {
    for (var index = 0; index < maxPumps; index++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.pump(step);
    }
    expect(finder, findsWidgets);
  }

  group('Venue Claim Route (no auth required)', () {
    testWidgets('venue claim route renders scaffold', (tester) async {
      await pumpApp(tester);
      appRouter.go(AppRoutePaths.venueClaim);
      await tester.pump();
      await pumpUntilVisible(tester, find.byType(Scaffold));
      expect(find.byType(Scaffold), findsWidgets);
      await disposeApp(tester);
    });

    testWidgets(
      'venue claim step one back button returns to guest settings when opened directly',
      (tester) async {
        await pumpApp(tester);
        appRouter.go(AppRoutePaths.venueClaim);
        await tester.pump();
        await pumpUntilVisible(tester, find.textContaining('STEP 1 OF 4'));

        await tester.tap(find.byIcon(LucideIcons.chevronLeft).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(appRouter.state.uri.path, AppRoutePaths.guestSettings);
        await disposeApp(tester);
      },
    );
  });

  group('Venue Login Route (no auth required)', () {
    testWidgets('venue login route renders scaffold', (tester) async {
      await pumpApp(tester);
      appRouter.goNamed(AppRouteNames.venueLogin);
      await tester.pump();
      await pumpUntilVisible(tester, find.byType(Scaffold));
      expect(find.byType(Scaffold), findsWidgets);
      await disposeApp(tester);
    });
  });

  group('Venue Onboarding (no auth required)', () {
    testWidgets('onboarding route renders scaffold', (tester) async {
      await pumpApp(tester);
      appRouter.go(AppRoutePaths.venueOnboarding);
      await tester.pump();
      await pumpUntilVisible(tester, find.byType(Scaffold));
      expect(find.byType(Scaffold), findsWidgets);
      await disposeApp(tester);
    });
  });
}
