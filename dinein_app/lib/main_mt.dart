import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/country_config.dart';
import 'core/config/country_config_provider.dart';
import 'core/config/country_runtime.dart';
import 'features/guest/permissions/guest_location_permission_host.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/app_notification_service.dart'
    if (dart.library.html) 'core/services/app_notification_service_web.dart';
import 'core/services/app_telemetry_service.dart'
    if (dart.library.html) 'core/services/app_telemetry_service_web.dart';
import 'core/services/auth_repository.dart';
import 'core/services/supabase_config.dart';

/// Malta entry point.
Future<void> main() async => _boot(CountryConfig.mt);

/// Shared bootstrap used by all flavor entry points.
Future<void> _boot(CountryConfig config) async {
  WidgetsFlutterBinding.ensureInitialized();
  CountryRuntime.configure(config);

  await Future.wait<void>([
    SupabaseConfig.initialize(),
    AuthRepository.instance.restoreVenueSession(),
    AuthRepository.instance.restoreAdminSession(),
    AppNotificationService.initialize(),
  ]);
  runApp(
    ProviderScope(
      overrides: [countryConfigProvider.overrideWithValue(config)],
      child: DineInApp(config: config),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(AppTelemetryService.initialize());
    final venueSession = AuthRepository.instance.currentVenueSession;
    if (venueSession != null) {
      unawaited(AppNotificationService.handleVenueSessionUpdated(venueSession));
    }
  });
}

/// Root widget for the DineIn app.
class DineInApp extends StatelessWidget {
  final CountryConfig config;
  const DineInApp({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: config.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
      builder: (context, child) =>
          GuestLocationPermissionHost(child: child ?? const SizedBox.shrink()),
      scrollBehavior: const _NoScrollbarBehavior(),
    );
  }
}

/// Custom scroll behavior that suppresses scrollbars for full-screen surfaces.
class _NoScrollbarBehavior extends ScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
