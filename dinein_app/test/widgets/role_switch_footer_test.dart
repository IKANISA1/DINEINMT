import 'package:dinein_app/core/config/country_config.dart';
import 'package:dinein_app/core/config/country_config_provider.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:dinein_app/shared/widgets/role_switch_footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Widget buildFooter(ActiveRole currentRole) {
    final router = GoRouter(
      initialLocation: '/footer',
      routes: [
        GoRoute(
          path: '/footer',
          builder: (_, _) =>
              Scaffold(body: RoleSwitchFooter(currentRole: currentRole)),
        ),
        GoRoute(
          path: AppRoutePaths.discover,
          name: AppRouteNames.discover,
          builder: (_, _) => const Scaffold(body: Text('Discover')),
        ),
        GoRoute(
          path: AppRoutePaths.venueLogin,
          name: AppRouteNames.venueLogin,
          builder: (_, state) => Scaffold(
            body: Column(
              children: [
                const Text('Venue Login'),
                Text(
                  'return:${state.uri.queryParameters[AppRouteParams.returnTo] ?? ''}',
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: AppRoutePaths.adminLogin,
          name: AppRouteNames.adminLogin,
          builder: (_, state) => Scaffold(
            body: Column(
              children: [
                const Text('Admin Login'),
                Text(
                  'return:${state.uri.queryParameters[AppRouteParams.returnTo] ?? ''}',
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return ProviderScope(
      overrides: [countryConfigProvider.overrideWithValue(CountryConfig.mt)],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('guest profile footer shows venue and admin icons only', (
    tester,
  ) async {
    await tester.pumpWidget(buildFooter(ActiveRole.guest));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byTooltip('Venue Portal'), findsOneWidget);
    expect(find.byTooltip('Admin Console'), findsOneWidget);
    expect(find.byTooltip('Guest'), findsNothing);
  });

  testWidgets(
    'guest footer venue icon opens venue login with guest return path',
    (tester) async {
      await tester.pumpWidget(buildFooter(ActiveRole.guest));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byTooltip('Venue Portal'));
      await tester.pumpAndSettle();

      expect(find.text('Venue Login'), findsOneWidget);
      expect(find.text('return:/settings'), findsOneWidget);
    },
  );

  testWidgets(
    'guest footer admin icon opens admin login with guest return path',
    (tester) async {
      await tester.pumpWidget(buildFooter(ActiveRole.guest));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byTooltip('Admin Console'));
      await tester.pumpAndSettle();

      expect(find.text('Admin Login'), findsOneWidget);
      expect(find.text('return:/settings'), findsOneWidget);
    },
  );

  testWidgets('venue profile footer shows guest and admin icons only', (
    tester,
  ) async {
    await tester.pumpWidget(buildFooter(ActiveRole.venue));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byTooltip('Guest'), findsOneWidget);
    expect(find.byTooltip('Admin Console'), findsOneWidget);
    expect(find.byTooltip('Venue Portal'), findsNothing);
  });

  testWidgets('venue footer guest icon returns to guest discover', (
    tester,
  ) async {
    await tester.pumpWidget(buildFooter(ActiveRole.venue));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byTooltip('Guest'));
    await tester.pumpAndSettle();

    expect(find.text('Discover'), findsOneWidget);
  });

  testWidgets(
    'venue footer admin icon opens admin login with venue return path',
    (tester) async {
      await tester.pumpWidget(buildFooter(ActiveRole.venue));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byTooltip('Admin Console'));
      await tester.pumpAndSettle();

      expect(find.text('Admin Login'), findsOneWidget);
      expect(find.text('return:/venue/settings'), findsOneWidget);
    },
  );

  testWidgets('admin profile footer shows guest and venue icons only', (
    tester,
  ) async {
    await tester.pumpWidget(buildFooter(ActiveRole.admin));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byTooltip('Guest'), findsOneWidget);
    expect(find.byTooltip('Venue Portal'), findsOneWidget);
    expect(find.byTooltip('Admin Console'), findsNothing);
  });

  testWidgets(
    'admin footer venue icon opens venue login with admin return path',
    (tester) async {
      await tester.pumpWidget(buildFooter(ActiveRole.admin));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byTooltip('Venue Portal'));
      await tester.pumpAndSettle();

      expect(find.text('Venue Login'), findsOneWidget);
      expect(find.text('return:/admin/settings'), findsOneWidget);
    },
  );
}
