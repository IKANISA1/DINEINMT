import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'admin_routes.dart';
import 'package:core_pkg/config/country_runtime.dart';
import '../services/app_bootstrap_service.dart';
import '../services/auth_repository.dart';
import 'app_routes.dart';
import 'guest_routes.dart';
import 'web_entry_routing.dart';
import 'venue_routes.dart';

/// App-wide GoRouter configuration.
///
/// Deep link support: `/v/{slug}` is the canonical entry route.
/// Optional table parameter: `?t=12`
final appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: AppBootstrapService.instance,
  redirect: (context, state) {
    final bootstrap = AppBootstrapService.instance;
    if (!bootstrap.isReady) {
      if (state.uri.path == AppRoutePaths.splash) {
        return null;
      }
      return Uri(
        path: AppRoutePaths.splash,
        queryParameters: {AppRouteParams.returnTo: state.uri.toString()},
      ).toString();
    }

    if (state.uri.path != AppRoutePaths.splash) {
      return null;
    }

    final pendingReturnTo = _resolveBootstrapReturnTo(state.uri);
    if (pendingReturnTo != null) {
      return pendingReturnTo;
    }

    if (kIsWeb) {
      return resolveWebRootRoute(
            uri: Uri.base,
            config: CountryRuntime.config,
            hasVenueAccess: AuthRepository.instance.hasVenueAccess,
            hasAdminAccess: AuthRepository.instance.hasAdminAccess,
          ) ??
          AppRoutePaths.discover;
    }

    if (AuthRepository.instance.hasAdminAccess) {
      return AppRoutePaths.adminOverview;
    }
    if (AuthRepository.instance.hasVenueAccess) {
      return AppRoutePaths.venueDashboard;
    }
    return AppRoutePaths.discover;
  },
  // Keep specific protected route trees ahead of guest dynamic slug routes.
  routes: [...adminRoutes, ...venueRoutes, ...guestRoutes],
);

String? _resolveBootstrapReturnTo(Uri uri) {
  final raw = uri.queryParameters[AppRouteParams.returnTo];
  if (raw == null || raw.trim().isEmpty) return null;
  final resolved = Uri.tryParse(raw);
  if (resolved == null || resolved.path.isEmpty) return null;
  if (resolved.path == AppRoutePaths.splash) return null;
  return resolved.toString();
}
