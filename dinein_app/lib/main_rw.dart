import 'main_mt.dart' as shared;
import 'core/config/country_config.dart';
import 'core/config/country_runtime.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/country_config_provider.dart';
import 'core/services/app_notification_service.dart'
    if (dart.library.html) 'core/services/app_notification_service_web.dart';
import 'core/services/app_telemetry_service.dart'
    if (dart.library.html) 'core/services/app_telemetry_service_web.dart';
import 'core/services/auth_repository.dart';
import 'core/services/supabase_config.dart';
import 'package:flutter/material.dart';
import 'dart:async';

/// Rwanda entry point.
Future<void> main() async {
  const config = CountryConfig.rw;
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
      child: shared.DineInApp(config: config),
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
