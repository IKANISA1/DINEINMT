import 'country_config.dart';

/// Runtime holder for the active country flavor.
///
/// Non-widget services use this to read the current market without depending
/// on Riverpod.
class CountryRuntime {
  CountryRuntime._();

  static CountryConfig _config = CountryConfig.mt;

  static void configure(CountryConfig config) {
    _config = config;
  }

  static CountryConfig get config => _config;
}
