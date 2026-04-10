import 'dart:async';
import 'dart:ui';

import 'package:core_pkg/config/country_config.dart';
import 'package:core_pkg/config/country_config_provider.dart';
import 'package:core_pkg/config/country_runtime.dart';
import 'package:dinein_app/core/router/app_router.dart';
import 'package:dinein_app/core/router/url_strategy.dart';
import 'package:dinein_app/core/router/web_entry_routing.dart';
import 'package:dinein_app/core/services/app_bootstrap_service.dart';
import 'package:dinein_app/core/services/pwa_install_service.dart';
import 'package:dinein_app/features/guest/permissions/guest_location_permission_host.dart';
import 'package:dinein_app/shared/widgets/offline_banner.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/theme/app_theme.dart';
import 'package:ui/widgets/dinein_toast.dart';

Future<void> bootApp(CountryConfig config) async {
  WidgetsFlutterBinding.ensureInitialized();
  configureWebUrlStrategy();
  CountryRuntime.configure(config);

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught platform error: $error\n$stack');
    return true;
  };

  if (kReleaseMode) {
    ErrorWidget.builder = (_) => const ProductionErrorWidget();
  }

  final webAppSurface = resolveCurrentWebAppSurface();
  final startupProfile = switch (webAppSurface) {
    WebAppSurface.guest => const AppStartupProfile.guestWeb(),
    WebAppSurface.venue => const AppStartupProfile.venueWeb(),
    WebAppSurface.admin => const AppStartupProfile.adminWeb(),
    WebAppSurface.landing ||
    WebAppSurface.unknown => const AppStartupProfile.defaultProfile(),
  };

  if (webAppSurface == WebAppSurface.guest ||
      webAppSurface == WebAppSurface.unknown) {
    PwaInstallService.init();
  }
  unawaited(
    AppBootstrapService.instance.ensureStarted(profile: startupProfile),
  );

  runApp(
    DineInToastOverlay(
      child: ProviderScope(
        overrides: [countryConfigProvider.overrideWithValue(config)],
        child: DineInApp(config: config),
      ),
    ),
  );
}

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
      builder: (context, child) => OfflineBanner(
        child: GuestLocationPermissionHost(
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      scrollBehavior: const _DineInScrollBehavior(),
    );
  }
}

class _DineInScrollBehavior extends ScrollBehavior {
  const _DineInScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    final platform = Theme.of(context).platform;
    if (platform == TargetPlatform.iOS || platform == TargetPlatform.android) {
      return child;
    }
    return super.buildScrollbar(context, child, details);
  }
}

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
