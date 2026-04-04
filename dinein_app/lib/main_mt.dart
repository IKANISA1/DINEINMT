import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_pkg/config/country_config.dart';
import 'package:core_pkg/config/country_config_provider.dart';
import 'package:core_pkg/config/country_runtime.dart';
import 'package:dinein_app/core/services/app_bootstrap_service.dart';
import 'package:dinein_app/core/services/pwa_install_service.dart';
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

  // ── Production error boundary ──────────────────────────────────────────
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    // Firebase Crashlytics (if initialised) picks these up automatically.
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught platform error: $error\n$stack');
    return true; // handled — prevent crash in release
  };

  // In release mode, show a friendly error widget instead of the red screen.
  if (kReleaseMode) {
    ErrorWidget.builder = (details) => const ProductionErrorWidget();
  }
  // ────────────────────────────────────────────────────────────────────────

  // PWA install prompt — engagement timer starts here (web-only, no-op on mobile)
  PwaInstallService.init();

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

/// Friendly fallback shown in release builds when a widget fails to render.
class ProductionErrorWidget extends StatelessWidget {
  const ProductionErrorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      color: const Color(0xFF111111),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.refresh_rounded, size: 48, color: Color(0xFF888888)),
          SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFFEEEEEE),
              decoration: TextDecoration.none,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Try going back or restarting the app.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF888888),
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}
