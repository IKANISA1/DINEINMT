import 'package:go_router/go_router.dart';

import '../../features/admin/activation/admin_activation_screen.dart';
import '../../features/admin/admin_shell.dart';
import '../../features/admin/auth/admin_login_screen.dart';
import '../../features/admin/dashboard/admin_dashboard_screen.dart';
import '../../features/admin/menus/admin_menu_review_screen.dart';
import '../../features/admin/menus/admin_menus_screen.dart';
import '../../features/admin/orders/admin_orders_screen.dart';
import '../../features/admin/settings/admin_settings_screen.dart';
import '../../features/admin/venues/admin_venue_detail_screen.dart';
import '../../features/admin/venues/admin_venues_screen.dart';
import '../services/auth_repository.dart';
import 'app_routes.dart';
import 'route_guards.dart';
import 'route_helpers.dart';

final List<RouteBase> adminRoutes = [
  GoRoute(
    path: AppRoutePaths.adminLogin,
    name: AppRouteNames.adminLogin,
    redirect: (context, state) => AuthRepository.instance.hasAdminAccess
        ? AppRoutePaths.adminOverview
        : null,
    builder: (context, state) => const AdminLoginScreen(),
  ),
  // Redirect /admin → /admin/overview
  GoRoute(
    path: AppRoutePaths.adminRoot,
    redirect: (context, state) => AppRoutePaths.adminOverview,
  ),
  GoRoute(
    path: AppRoutePaths.adminActivation,
    name: AppRouteNames.adminActivation,
    redirect: adminRoleGuard,
    pageBuilder: (context, state) {
      final id = state.pathParameters[AppRouteParams.id]!;
      return buildFadeSlidePage(state, AdminActivationScreen(venueId: id));
    },
  ),
  ShellRoute(
    builder: (context, state, child) => AdminShell(child: child),
    routes: [
      GoRoute(
        path: AppRoutePaths.adminOverview,
        name: AppRouteNames.adminOverview,
        redirect: adminRoleGuard,
        pageBuilder: (context, state) =>
            buildFadeSlidePage(state, const AdminDashboardScreen()),
      ),
      GoRoute(
        path: AppRoutePaths.adminVenues,
        name: AppRouteNames.adminVenues,
        redirect: adminRoleGuard,
        pageBuilder: (context, state) =>
            buildFadeSlidePage(state, const AdminVenuesScreen()),
      ),
      GoRoute(
        path: AppRoutePaths.adminVenueDetail,
        name: AppRouteNames.adminVenueDetail,
        redirect: adminRoleGuard,
        pageBuilder: (context, state) {
          final id = state.pathParameters[AppRouteParams.id]!;
          return buildFadeSlidePage(state, AdminVenueDetailScreen(venueId: id));
        },
      ),
      GoRoute(
        path: AppRoutePaths.adminSettings,
        name: AppRouteNames.adminSettings,
        redirect: adminRoleGuard,
        pageBuilder: (context, state) =>
            buildFadeSlidePage(state, const AdminSettingsScreen()),
      ),
      GoRoute(
        path: AppRoutePaths.adminMenus,
        name: AppRouteNames.adminMenus,
        redirect: adminRoleGuard,
        pageBuilder: (context, state) =>
            buildFadeSlidePage(state, const AdminMenusScreen()),
      ),
      GoRoute(
        path: AppRoutePaths.adminMenuReview,
        name: AppRouteNames.adminMenuReview,
        redirect: adminRoleGuard,
        pageBuilder: (context, state) {
          final id = state.pathParameters[AppRouteParams.id]!;
          return buildFadeSlidePage(state, AdminMenuReviewScreen(venueId: id));
        },
      ),
      GoRoute(
        path: AppRoutePaths.adminOrders,
        name: AppRouteNames.adminOrders,
        redirect: adminRoleGuard,
        pageBuilder: (context, state) =>
            buildFadeSlidePage(state, const AdminOrdersScreen()),
      ),
    ],
  ),
];
