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

  if (host == config.guestWebHost) {
    return AppRoutePaths.discover;
  }

  if (host == config.venueWebHost) {
    return hasVenueAccess
        ? AppRoutePaths.venueDashboard
        : AppRoutePaths.venueLogin;
  }

  if (host == config.adminWebHost) {
    return hasAdminAccess
        ? AppRoutePaths.adminOverview
        : AppRoutePaths.adminLogin;
  }

  return null;
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
