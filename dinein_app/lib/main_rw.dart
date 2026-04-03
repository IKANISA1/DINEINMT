import 'dart:async';

import 'main_mt.dart' as shared;
import 'core/config/country_config.dart';
import 'core/config/country_runtime.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/country_config_provider.dart';
import 'core/services/app_bootstrap_service.dart';
import 'core/router/url_strategy.dart';
import 'package:flutter/material.dart';

/// Rwanda entry point.
Future<void> main() async {
  const config = CountryConfig.rw;
  WidgetsFlutterBinding.ensureInitialized();
  configureWebUrlStrategy();
  CountryRuntime.configure(config);
  unawaited(AppBootstrapService.instance.ensureStarted());

  runApp(
    ProviderScope(
      overrides: [countryConfigProvider.overrideWithValue(config)],
      child: shared.DineInApp(config: config),
    ),
  );
}
