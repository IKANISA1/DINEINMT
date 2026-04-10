import 'package:flutter/foundation.dart';

import 'package:core_pkg/config/country_runtime.dart';
import 'package:core_pkg/config/country_config.dart';
import '../services/auth_repository.dart';
import 'app_routes.dart';

enum WebAppSurface { guest, venue, admin, landing, unknown }

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
  return switch (resolveWebAppSurface(uri: uri, config: config)) {
    WebAppSurface.guest => AppRoutePaths.discover,
    WebAppSurface.venue =>
      hasVenueAccess ? AppRoutePaths.venueDashboard : AppRoutePaths.venueLogin,
    WebAppSurface.admin =>
      hasAdminAccess ? AppRoutePaths.adminOverview : AppRoutePaths.adminLogin,
    WebAppSurface.landing || WebAppSurface.unknown => null,
  };
}

WebAppSurface resolveWebAppSurface({
  required Uri uri,
  required CountryConfig config,
}) {
  final host = uri.host.toLowerCase().trim();
  if (host.isEmpty) {
    return WebAppSurface.unknown;
  }

  if (host == config.siteHost) {
    return WebAppSurface.landing;
  }
  if (_isGuestHost(host, config)) {
    return WebAppSurface.guest;
  }
  if (_isVenueHost(host, config)) {
    return WebAppSurface.venue;
  }
  if (_isAdminHost(host, config)) {
    return WebAppSurface.admin;
  }
  return WebAppSurface.unknown;
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

WebAppSurface resolveCurrentWebAppSurface([Uri? uri]) {
  if (!kIsWeb) {
    return WebAppSurface.unknown;
  }
  return resolveWebAppSurface(
    uri: uri ?? Uri.base,
    config: CountryRuntime.config,
  );
}
