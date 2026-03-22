import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/guest/permissions/guest_location_permission_host.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/app_notification_service.dart';
import 'core/services/app_telemetry_service.dart';
import 'core/services/auth_repository.dart';
import 'core/services/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Future.wait<void>([
    SupabaseConfig.initialize(),
    AuthRepository.instance.restoreVenueSession(),
    AuthRepository.instance.restoreAdminSession(),
    AppNotificationService.initialize(),
  ]);
  runApp(const ProviderScope(child: DineInApp()));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(AppTelemetryService.initialize());
    final venueSession = AuthRepository.instance.currentVenueSession;
    if (venueSession != null) {
      unawaited(AppNotificationService.handleVenueSessionUpdated(venueSession));
    }
  });
}

/// Root widget for the DineIn Malta app.
class DineInApp extends StatelessWidget {
  const DineInApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DINEIN MALTA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
      builder: (context, child) =>
          GuestLocationPermissionHost(child: child ?? const SizedBox.shrink()),
      // Keep scroll chrome visually quiet across the supported mobile app.
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
