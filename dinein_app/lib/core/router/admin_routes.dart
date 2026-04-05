import 'package:go_router/go_router.dart';

import '../../features/admin/admin_shell.dart';
import '../../features/admin/auth/admin_login_screen.dart';
import '../../features/admin/dashboard/admin_dashboard_screen.dart' deferred as admindashboardscreen;
import '../../features/admin/orders/admin_orders_screen.dart' deferred as adminordersscreen;
import '../../features/admin/settings/admin_settings_screen.dart' deferred as adminsettingsscreen;
import '../../features/admin/venues/admin_venue_detail_screen.dart' deferred as adminvenuedetailscreen;
import '../../features/admin/venues/admin_venues_screen.dart' deferred as adminvenuesscreen;
import '../services/auth_repository.dart';
import 'app_routes.dart';
import 'route_guards.dart';
import 'route_helpers.dart';
import 'deferred_widget.dart';

final List<RouteBase> adminRoutes = [
  GoRoute(
    path: AppRoutePaths.adminLogin,
    name: AppRouteNames.adminLogin,
    redirect: (context, state) {
      if (!AuthRepository.instance.hasAdminAccess) return null;
      final returnTo = state.uri.queryParameters[AppRouteParams.returnTo];
      if (returnTo != null && returnTo.trim().isNotEmpty) {
        final target = Uri.tryParse(returnTo);
        if (target != null &&
            target.path.startsWith('/admin') &&
            target.path != AppRoutePaths.adminLogin) {
          return target.toString();
        }
      }
      return AppRoutePaths.adminOverview;
    },
    builder: (context, state) => const AdminLoginScreen(),
  ),
  // Redirect /admin → /admin/overview
  GoRoute(
    path: AppRoutePaths.adminRoot,
    redirect: (context, state) => AppRoutePaths.adminOverview,
  ),
  ShellRoute(
    builder: (context, state, child) => AdminShell(child: child),
    routes: [
      GoRoute(
        path: AppRoutePaths.adminOverview,
        name: AppRouteNames.adminOverview,
        redirect: adminRoleGuard,
        pageBuilder: (context, state) =>
            buildFadeSlidePage(state, DeferredWidget(libraryLoader: admindashboardscreen.loadLibrary, createWidget: (_) => admindashboardscreen.AdminDashboardScreen())),
      ),
      GoRoute(
        path: AppRoutePaths.adminVenues,
        name: AppRouteNames.adminVenues,
        redirect: adminRoleGuard,
        pageBuilder: (context, state) =>
            buildFadeSlidePage(state, DeferredWidget(libraryLoader: adminvenuesscreen.loadLibrary, createWidget: (_) => adminvenuesscreen.AdminVenuesScreen())),
      ),
      GoRoute(
        path: AppRoutePaths.adminVenueCreate,
        name: AppRouteNames.adminVenueCreate,
        redirect: adminRoleGuard,
        pageBuilder: (context, state) =>
            buildFadeSlidePage(state, DeferredWidget(libraryLoader: adminvenuedetailscreen.loadLibrary, createWidget: (_) => adminvenuedetailscreen.AdminVenueDetailScreen())),
      ),
      GoRoute(
        path: AppRoutePaths.adminVenueDetail,
        name: AppRouteNames.adminVenueDetail,
        redirect: adminRoleGuard,
        pageBuilder: (context, state) {
          final id = state.pathParameters[AppRouteParams.id]!;
          return buildFadeSlidePage(state, DeferredWidget(libraryLoader: adminvenuedetailscreen.loadLibrary, createWidget: (_) => adminvenuedetailscreen.AdminVenueDetailScreen(venueId: id)));
        },
      ),
      GoRoute(
        path: AppRoutePaths.adminSettings,
        name: AppRouteNames.adminSettings,
        redirect: adminRoleGuard,
        pageBuilder: (context, state) =>
            buildFadeSlidePage(state, DeferredWidget(libraryLoader: adminsettingsscreen.loadLibrary, createWidget: (_) => adminsettingsscreen.AdminSettingsScreen())),
      ),
      GoRoute(
        path: AppRoutePaths.adminOrders,
        name: AppRouteNames.adminOrders,
        redirect: adminRoleGuard,
        pageBuilder: (context, state) =>
            buildFadeSlidePage(state, DeferredWidget(libraryLoader: adminordersscreen.loadLibrary, createWidget: (_) => adminordersscreen.AdminOrdersScreen())),
      ),
    ],
  ),
];
