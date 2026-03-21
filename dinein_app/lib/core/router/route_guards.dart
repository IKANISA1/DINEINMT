import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'app_routes.dart';
import '../services/auth_repository.dart';

/// Redirect unauthenticated venue users to the venue login screen.
String? venueAuthGuard(BuildContext context, GoRouterState state) {
  return !AuthRepository.instance.hasVenueAccess
      ? AppRoutePaths.venueLogin
      : null;
}

/// Protect OCR review when it is being used against an existing venue.
String? venueOcrGuard(BuildContext context, GoRouterState state) {
  final venueId = state.uri.queryParameters[AppRouteParams.venueId];
  if (venueId == null || venueId.isEmpty) return null;
  return venueAuthGuard(context, state);
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
