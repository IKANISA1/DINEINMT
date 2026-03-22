import 'package:dinein_app/core/router/app_routes.dart';
import 'package:dinein_app/core/router/app_router.dart';
import 'package:dinein_app/main.dart';
import 'package:dinein_app/shared/widgets/brand_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appRouter.goNamed(AppRouteNames.splash);
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: DineInApp()));
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
      if (finder.evaluate().isNotEmpty) {
        return;
      }
      await tester.pump(step);
    }

    expect(finder, findsWidgets);
  }

  testWidgets('renders the splash screen on startup', (tester) async {
    await pumpApp(tester);

    // Wait for animations to settle enough to show content
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.byType(DineInLogoText), findsOneWidget);
    expect(find.byType(BrandMark), findsNothing);

    // The splash now shows the tagline instead of CTAs
    expect(find.text('DINE IN, STAND OUT.'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('splash auto-navigates to discover after timeout', (
    tester,
  ) async {
    await pumpApp(tester);

    // Pump in increments to let Timer callbacks fire
    for (var i = 0; i < 35; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(appRouter.state.uri.path, AppRoutePaths.discover);

    await disposeApp(tester);
  });

  testWidgets('venue login route renders the venue portal entry screen', (
    tester,
  ) async {
    await pumpApp(tester);

    appRouter.goNamed(AppRouteNames.venueLogin);
    await tester.pump();
    await pumpUntilVisible(tester, find.text('CLAIM YOUR VENUE'));

    expect(
      find.text('Access your venue workspace with WhatsApp OTP.'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 1));
    await disposeApp(tester);
  });

  testWidgets('venue login claim CTA opens the claim flow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpApp(tester);

    appRouter.goNamed(AppRouteNames.venueLogin);
    await tester.pump();
    await pumpUntilVisible(tester, find.text('CLAIM YOUR VENUE'));

    await tester.tap(find.widgetWithText(GestureDetector, 'CLAIM YOUR VENUE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(appRouter.state.uri.path, AppRoutePaths.venueClaim);

    await disposeApp(tester);
  });

  testWidgets('venue claim path resolves to the claim screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpApp(tester);

    appRouter.go(AppRoutePaths.venueClaim);
    await tester.pump();
    await pumpUntilVisible(tester, find.text('STEP 1 OF 4'));
    await pumpUntilVisible(tester, find.text('ADD YOUR'));
    await pumpUntilVisible(tester, find.text('VENUE'));

    expect(appRouter.state.uri.path, AppRoutePaths.venueClaim);
    expect(find.text('ADD YOUR'), findsOneWidget);
    expect(find.text('VENUE'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await disposeApp(tester);
  });

  testWidgets('order success route prefers the order number query parameter', (
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
    await pumpUntilVisible(tester, find.text('#12345678'));

    expect(find.text('#12345678'), findsOneWidget);

    await disposeApp(tester);
  });
}
