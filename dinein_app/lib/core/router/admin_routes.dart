import 'package:go_router/go_router.dart';

import '../../features/admin/activation/admin_activation_screen.dart' deferred as adminactivationscreen;
import '../../features/admin/admin_shell.dart';
import '../../features/admin/auth/admin_login_screen.dart';
import '../../features/admin/dashboard/admin_dashboard_screen.dart' deferred as admindashboardscreen;
import '../../features/admin/menus/admin_menu_item_screen.dart' deferred as adminmenuitemscreen;
import '../../features/admin/menus/admin_menu_review_screen.dart' deferred as adminmenureviewscreen;
import '../../features/admin/menus/admin_menus_screen.dart' deferred as adminmenusscreen;
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
      return buildFadeSlidePage(state, DeferredWidget(libraryLoader: adminactivationscreen.loadLibrary, createWidget: (_) => adminactivationscreen.AdminActivationScreen(venueId: id)));
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
        path: AppRoutePaths.adminMenus,
        name: AppRouteNames.adminMenus,
        redirect: adminRoleGuard,
        pageBuilder: (context, state) =>
            buildFadeSlidePage(state, DeferredWidget(libraryLoader: adminmenusscreen.loadLibrary, createWidget: (_) => adminmenusscreen.AdminMenusScreen())),
      ),
      GoRoute(
        path: AppRoutePaths.adminMenuNew,
        name: AppRouteNames.adminMenuNew,
        redirect: adminRoleGuard,
        pageBuilder: (context, state) =>
            buildFadeSlidePage(state, DeferredWidget(libraryLoader: adminmenuitemscreen.loadLibrary, createWidget: (_) => adminmenuitemscreen.AdminMenuItemScreen())),
      ),
      GoRoute(
        path: AppRoutePaths.adminMenuItem,
        name: AppRouteNames.adminMenuItem,
        redirect: adminRoleGuard,
        pageBuilder: (context, state) {
          final id = state.pathParameters[AppRouteParams.id]!;
          return buildFadeSlidePage(state, DeferredWidget(libraryLoader: adminmenuitemscreen.loadLibrary, createWidget: (_) => adminmenuitemscreen.AdminMenuItemScreen(groupId: id)));
        },
      ),
      GoRoute(
        path: AppRoutePaths.adminMenuReview,
        name: AppRouteNames.adminMenuReview,
        redirect: adminRoleGuard,
        pageBuilder: (context, state) {
          final id = state.pathParameters[AppRouteParams.id]!;
          return buildFadeSlidePage(state, DeferredWidget(libraryLoader: adminmenureviewscreen.loadLibrary, createWidget: (_) => adminmenureviewscreen.AdminMenuReviewScreen(venueId: id)));
        },
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
