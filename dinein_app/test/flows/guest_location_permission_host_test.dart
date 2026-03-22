import 'package:dinein_app/core/providers/permission_providers.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:dinein_app/core/router/app_router.dart';
import 'package:dinein_app/core/services/app_permission_service.dart';
import 'package:dinein_app/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('guest discover route shows the location popup when missing', (
    tester,
  ) async {
    var openedSettings = 0;
    final service = AppPermissionService(
      readStatus: (_) async => PermissionStatus.denied,
      requestPermission: (_) async => PermissionStatus.denied,
      openSettings: () async {
        openedSettings += 1;
        return true;
      },
    );

    appRouter.goNamed(AppRouteNames.discover);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appPermissionServiceProvider.overrideWithValue(service)],
        child: const DineInApp(),
      ),
    );
    await tester.pump();

    expect(find.text('LOCATION SHARING'), findsOneWidget);

    await tester.tap(find.text('GRANT ACCESS'));
    await tester.pumpAndSettle();

    expect(openedSettings, 1);
  });

  testWidgets('venue login route does not show the guest location popup', (
    tester,
  ) async {
    final service = AppPermissionService(
      readStatus: (_) async => PermissionStatus.denied,
      requestPermission: (_) async => PermissionStatus.denied,
      openSettings: () async => true,
    );

    appRouter.goNamed(AppRouteNames.venueLogin);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appPermissionServiceProvider.overrideWithValue(service)],
        child: const DineInApp(),
      ),
    );
    await tester.pump();

    expect(find.text('LOCATION SHARING'), findsNothing);
  });
}
