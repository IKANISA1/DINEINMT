import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'admin_routes.dart';
import '../config/country_runtime.dart';
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
  redirect: (context, state) {
    if (!kIsWeb || state.uri.path != AppRoutePaths.splash) {
      return null;
    }

    return resolveWebRootRoute(
      uri: Uri.base,
      config: CountryRuntime.config,
      hasVenueAccess: AuthRepository.instance.hasVenueAccess,
      hasAdminAccess: AuthRepository.instance.hasAdminAccess,
    );
  },
  // Keep specific protected route trees ahead of guest dynamic slug routes.
  routes: [...adminRoutes, ...venueRoutes, ...guestRoutes],
);
