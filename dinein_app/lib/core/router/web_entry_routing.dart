import 'package:core_pkg/config/country_runtime.dart';
import 'package:core_pkg/config/country_config.dart';
import '../services/auth_repository.dart';
import 'app_routes.dart';

/// Resolves the browser root path to the correct role-specific start route.
///
/// This keeps the web hosts deterministic:
/// - guest host -> guest discover
/// - venue host -> venue login or dashboard
/// - admin host -> admin login or overview
String? resolveWebRootRoute({
  required Uri uri,
  required CountryConfig config,
  required bool hasVenueAccess,
  required bool hasAdminAccess,
}) {
  final host = uri.host.toLowerCase();
  if (host.isEmpty) return null;

  if (_isGuestHost(host, config)) {
    return AppRoutePaths.discover;
  }

  if (_isVenueHost(host, config)) {
    return hasVenueAccess
        ? AppRoutePaths.venueDashboard
        : AppRoutePaths.venueLogin;
  }

  if (_isAdminHost(host, config)) {
    return hasAdminAccess
        ? AppRoutePaths.adminOverview
        : AppRoutePaths.adminLogin;
  }

  return null;
}

bool _isGuestHost(String host, CountryConfig config) {
  return host == config.guestWebHost || _matchesRoleHost(host, roleSuffix: 'g');
}

bool _isVenueHost(String host, CountryConfig config) {
  return host == config.venueWebHost || _matchesRoleHost(host, roleSuffix: 'v');
}

bool _isAdminHost(String host, CountryConfig config) {
  return host == config.adminWebHost || _matchesRoleHost(host, roleSuffix: 'a');
}

bool _matchesRoleHost(String host, {required String roleSuffix}) {
  final normalizedHost = host.trim().toLowerCase();
  if (!normalizedHost.endsWith('.ikanisa.com')) {
    return false;
  }
  return RegExp(
    r'^dinein[a-z0-9]*' + roleSuffix + r'\.ikanisa\.com$',
  ).hasMatch(normalizedHost);
}

/// Convenience wrapper using the current app singleton state.
String? resolveCurrentWebRootRoute(Uri uri) {
  return resolveWebRootRoute(
    uri: uri,
    config: CountryRuntime.config,
    hasVenueAccess: AuthRepository.instance.hasVenueAccess,
    hasAdminAccess: AuthRepository.instance.hasAdminAccess,
  );
}
