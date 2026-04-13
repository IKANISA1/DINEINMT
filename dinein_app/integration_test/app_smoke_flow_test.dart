import 'package:core_pkg/config/country_config.dart';
import 'package:dinein_app/core/router/app_router.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:dinein_app/core/services/app_bootstrap_service.dart';
import 'package:dinein_app/app_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ui/widgets/brand_mark.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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
      const ProviderScope(
        child: DineInApp(config: CountryConfig.mt),
      ),
    );
    await tester.pump();
  }

  Future<void> disposeApp(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  testWidgets('shows splash UI until bootstrap completes', (tester) async {
    await pumpApp(tester, bootstrapReady: false);
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.byType(DineInLogoText), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('routes to discover and venue login without crashing', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(appRouter.state.uri.path, AppRoutePaths.discover);

    appRouter.goNamed(AppRouteNames.venueLogin);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(appRouter.state.uri.path, AppRoutePaths.venueLogin);

    await disposeApp(tester);
  });
}
