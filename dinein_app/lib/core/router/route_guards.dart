import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'app_routes.dart';
import '../services/auth_repository.dart';

String _venueLoginRedirectTarget(GoRouterState state) {
  return Uri(
    path: AppRoutePaths.venueLogin,
    queryParameters: {AppRouteParams.returnTo: state.uri.toString()},
  ).toString();
}

String? resolveVenueReturnToUri(GoRouterState state) {
  final raw = state.uri.queryParameters[AppRouteParams.returnTo];
  if (raw == null || raw.trim().isEmpty) return null;

  final uri = Uri.tryParse(raw);
  if (uri == null || uri.path.isEmpty) return null;
  if (!uri.path.startsWith('/venue')) return null;
  if (uri.path == AppRoutePaths.venueLogin) return null;
  return uri.toString();
}

/// Redirect unauthenticated venue users to the venue login screen.
String? venueAuthGuard(BuildContext context, GoRouterState state) {
  return !AuthRepository.instance.hasVenueAccess
      ? _venueLoginRedirectTarget(state)
      : null;
}

/// Redirect unauthenticated or non-admin users to the admin login page.
///
/// Checks custom admin session first (expiry-aware), then falls back to
/// Supabase auth + role lookup for initial login flow.
Future<String?> adminRoleGuard(
  BuildContext context,
  GoRouterState state,
) async {
  // Fast path: valid non-expired admin session.
  if (AuthRepository.instance.hasAdminAccess) return null;

  // Expired admin session — clear it and redirect.
  final adminSession = AuthRepository.instance.currentAdminSession;
  if (adminSession == null) {
    // Check if this is a fresh login via Supabase auth with admin role.
    if (!AuthRepository.instance.isAuthenticated) {
      return AppRoutePaths.adminLogin;
    }

    final user = AuthRepository.instance.currentUser;
    if (user == null) return AppRoutePaths.adminLogin;

    final role = await AuthRepository.instance.getUserRole(user.id);
    if (role != 'admin') return AppRoutePaths.adminLogin;

    return null;
  }

  // Session object exists but is expired (hasAdminAccess returned false).
  await AuthRepository.instance.clearAdminSession();
  return AppRoutePaths.adminLogin;
}
