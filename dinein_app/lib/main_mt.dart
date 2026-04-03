import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/country_config.dart';
import 'core/config/country_config_provider.dart';
import 'core/config/country_runtime.dart';
import 'core/services/app_bootstrap_service.dart';
import 'features/guest/permissions/guest_location_permission_host.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/router/url_strategy.dart';

/// Malta entry point.
Future<void> main() async => _boot(CountryConfig.mt);

/// Shared bootstrap used by all flavor entry points.
Future<void> _boot(CountryConfig config) async {
  WidgetsFlutterBinding.ensureInitialized();
  configureWebUrlStrategy();
  CountryRuntime.configure(config);
  unawaited(AppBootstrapService.instance.ensureStarted());

  runApp(
    ProviderScope(
      overrides: [countryConfigProvider.overrideWithValue(config)],
      child: DineInApp(config: config),
    ),
  );
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
