import 'dart:async';

import 'main_mt.dart' as shared;
import 'package:core_pkg/config/country_config.dart';
import 'package:core_pkg/config/country_runtime.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_pkg/config/country_config_provider.dart';
import 'package:dinein_app/core/services/app_bootstrap_service.dart';
import 'package:dinein_app/core/services/pwa_install_service.dart';
import 'package:dinein_app/core/router/url_strategy.dart';
import 'package:flutter/material.dart';

/// Rwanda entry point.
Future<void> main() async {
  const config = CountryConfig.rw;
  WidgetsFlutterBinding.ensureInitialized();
  configureWebUrlStrategy();
  CountryRuntime.configure(config);

  // ── Production error boundary (mirrored from main_mt.dart) ─────────────
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught platform error: $error\n$stack');
    return true;
  };

  if (kReleaseMode) {
    ErrorWidget.builder = (_) => const shared.ProductionErrorWidget();
  }
  // ────────────────────────────────────────────────────────────────────────

  // PWA install prompt — engagement timer starts here (web-only, no-op on mobile)
  PwaInstallService.init();

  unawaited(AppBootstrapService.instance.ensureStarted());

  runApp(
    ProviderScope(
      overrides: [countryConfigProvider.overrideWithValue(config)],
      child: shared.DineInApp(config: config),
    ),
  );
}
