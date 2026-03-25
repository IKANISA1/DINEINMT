import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'country_config.dart';
import 'country_runtime.dart';

/// Global provider for the active country configuration.
///
/// Set once at startup by the flavor entry point (`main_mt.dart` or `main_rw.dart`).
/// All widgets and services read country-specific values from this provider.
///
/// The provider can still be overridden at startup, but it falls back to the
/// runtime country holder so widget tests and isolated widget harnesses keep the
/// same market behavior as the rest of the app.
final countryConfigProvider = Provider<CountryConfig>((ref) {
  return CountryRuntime.config;
});
