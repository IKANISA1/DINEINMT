import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_pkg/config/country_config.dart';
import 'package:core_pkg/config/country_config_provider.dart';
import 'package:core_pkg/config/country_runtime.dart';
import 'package:dinein_app/core/services/app_bootstrap_service.dart';
import 'features/guest/permissions/guest_location_permission_host.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:dinein_app/core/router/app_router.dart';
import 'package:dinein_app/core/router/url_strategy.dart';

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
