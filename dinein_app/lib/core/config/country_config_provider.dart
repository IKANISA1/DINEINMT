import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'country_config.dart';

/// Global provider for the active country configuration.
///
/// Set once at startup by the flavor entry point (`main_mt.dart` or `main_rw.dart`).
/// All widgets and services read country-specific values from this provider.
final countryConfigProvider = Provider<CountryConfig>((ref) {
  throw UnimplementedError(
    'countryConfigProvider must be overridden at app startup.',
  );
});
