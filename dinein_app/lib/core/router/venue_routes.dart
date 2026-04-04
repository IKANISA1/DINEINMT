import 'package:go_router/go_router.dart';

import '../services/auth_repository.dart';
import '../../features/venue/auth/venue_login_screen.dart';

import '../../features/venue/dashboard/venue_dashboard_screen.dart' deferred as venuedashboardscreen;
import '../../features/venue/menu/venue_edit_item_screen.dart' deferred as venueedititemscreen;
import '../../features/venue/menu/venue_menu_manager_screen.dart' deferred as venuemenumanagerscreen;

import '../../features/venue/orders/venue_order_detail_screen.dart' deferred as venueorderdetailscreen;
import '../../features/venue/orders/venue_orders_screen.dart' deferred as venueordersscreen;
import '../../features/venue/reports/venue_item_report_screen.dart' deferred as venueitemreportscreen;
import '../../features/venue/settings/venue_hours_screen.dart' deferred as venuehoursscreen;
import '../../features/venue/settings/venue_language_region_screen.dart' deferred as venuelanguageregionscreen;
import '../../features/venue/settings/venue_legal_screen.dart' deferred as venuelegalscreen;
import '../../features/venue/settings/venue_notifications_screen.dart' deferred as venuenotificationsscreen;
import '../../features/venue/settings/venue_profile_screen.dart' deferred as venueprofilescreen;
import '../../features/venue/settings/venue_table_qr_screen.dart' deferred as venuetableqrscreen;
import '../../features/venue/settings/venue_wifi_screen.dart' deferred as venuewifiscreen;
import '../../features/venue/settings/venue_settings_screen.dart' deferred as venuesettingsscreen;
import '../../features/venue/waves/venue_waves_screen.dart' deferred as venuewavesscreen;
import '../../features/venue/venue_shell.dart';
import 'app_routes.dart';
import 'route_guards.dart';
import 'route_helpers.dart';
import 'deferred_widget.dart';

final List<RouteBase> venueRoutes = [
  GoRoute(
    path: AppRoutePaths.venueLogin,
    name: AppRouteNames.venueLogin,
    redirect: (context, state) => AuthRepository.instance.hasVenueAccess
        ? (resolveVenueReturnToUri(state) ?? AppRoutePaths.venueDashboard)
        : null,
    builder: (context, state) => const VenueLoginScreen(),
  ),

  GoRoute(
    path: AppRoutePaths.venueOrderDetail,
    name: AppRouteNames.venueOrderDetail,
    redirect: venueAuthGuard,
    builder: (context, state) {
      final id = state.pathParameters[AppRouteParams.id]!;
      return DeferredWidget(libraryLoader: venueorderdetailscreen.loadLibrary, createWidget: (_) => venueorderdetailscreen.VenueOrderDetailScreen(orderId: id));
    },
  ),
  GoRoute(
    path: AppRoutePaths.venueNewItem,
    name: AppRouteNames.venueNewItem,
    redirect: venueAuthGuard,
    builder: (context, state) => DeferredWidget(libraryLoader: venueedititemscreen.loadLibrary, createWidget: (_) => venueedititemscreen.VenueEditItemScreen()),
  ),
  GoRoute(
    path: AppRoutePaths.venueEditItem,
    name: AppRouteNames.venueEditItem,
    redirect: venueAuthGuard,
    builder: (context, state) {
      final id = state.pathParameters[AppRouteParams.id]!;
      return DeferredWidget(libraryLoader: venueedititemscreen.loadLibrary, createWidget: (_) => venueedititemscreen.VenueEditItemScreen(itemId: id));
    },
  ),
  GoRoute(
    path: AppRoutePaths.venueItemReport,
    name: AppRouteNames.venueItemReport,
    redirect: venueAuthGuard,
    builder: (context, state) => DeferredWidget(libraryLoader: venueitemreportscreen.loadLibrary, createWidget: (_) => venueitemreportscreen.VenueItemReportScreen()),
  ),
  GoRoute(
    path: AppRoutePaths.venueHours,
    name: AppRouteNames.venueHours,
    redirect: venueAuthGuard,
    builder: (context, state) => DeferredWidget(libraryLoader: venuehoursscreen.loadLibrary, createWidget: (_) => venuehoursscreen.VenueHoursScreen()),
  ),
  GoRoute(
    path: AppRoutePaths.venueNotifications,
    name: AppRouteNames.venueNotifications,
    redirect: venueAuthGuard,
    builder: (context, state) => DeferredWidget(libraryLoader: venuenotificationsscreen.loadLibrary, createWidget: (_) => venuenotificationsscreen.VenueNotificationsScreen()),
  ),
  GoRoute(
    path: AppRoutePaths.venueLanguageRegion,
    name: AppRouteNames.venueLanguageRegion,
    redirect: venueAuthGuard,
    builder: (context, state) => DeferredWidget(libraryLoader: venuelanguageregionscreen.loadLibrary, createWidget: (_) => venuelanguageregionscreen.VenueLanguageRegionScreen()),
  ),
  GoRoute(
    path: AppRoutePaths.venueLegal,
    name: AppRouteNames.venueLegal,
    redirect: venueAuthGuard,
    builder: (context, state) => DeferredWidget(libraryLoader: venuelegalscreen.loadLibrary, createWidget: (_) => venuelegalscreen.VenueLegalScreen()),
  ),
  GoRoute(
    path: AppRoutePaths.venueWifi,
    name: AppRouteNames.venueWifi,
    redirect: venueAuthGuard,
    builder: (context, state) => DeferredWidget(libraryLoader: venuewifiscreen.loadLibrary, createWidget: (_) => venuewifiscreen.VenueWifiScreen()),
  ),
  GoRoute(
    path: AppRoutePaths.venueWaves,
    name: AppRouteNames.venueWaves,
    redirect: venueAuthGuard,
    builder: (context, state) => DeferredWidget(libraryLoader: venuewavesscreen.loadLibrary, createWidget: (_) => venuewavesscreen.VenueWavesScreen()),
  ),
  ShellRoute(
    builder: (context, state, child) => VenueShell(child: child),
    routes: [
      GoRoute(
        path: AppRoutePaths.venueDashboard,
        name: AppRouteNames.venueDashboard,
        redirect: venueAuthGuard,
        pageBuilder: (context, state) =>
            buildFadeSlidePage(state, DeferredWidget(libraryLoader: venuedashboardscreen.loadLibrary, createWidget: (_) => venuedashboardscreen.VenueDashboardScreen())),
      ),
      GoRoute(
        path: AppRoutePaths.venueOrders,
        name: AppRouteNames.venueOrders,
        redirect: venueAuthGuard,
        pageBuilder: (context, state) =>
            buildFadeSlidePage(state, DeferredWidget(libraryLoader: venueordersscreen.loadLibrary, createWidget: (_) => venueordersscreen.VenueOrdersScreen())),
      ),
      GoRoute(
        path: AppRoutePaths.venueMenu,
        name: AppRouteNames.venueMenu,
        redirect: venueAuthGuard,
        pageBuilder: (context, state) =>
            buildFadeSlidePage(state, DeferredWidget(libraryLoader: venuemenumanagerscreen.loadLibrary, createWidget: (_) => venuemenumanagerscreen.VenueMenuManagerScreen())),
      ),
      GoRoute(
        path: AppRoutePaths.venueSettings,
        name: AppRouteNames.venueSettings,
        redirect: venueAuthGuard,
        pageBuilder: (context, state) =>
            buildFadeSlidePage(state, DeferredWidget(libraryLoader: venuesettingsscreen.loadLibrary, createWidget: (_) => venuesettingsscreen.VenueSettingsScreen())),
      ),
      GoRoute(
        path: AppRoutePaths.venueProfile,
        name: AppRouteNames.venueProfile,
        redirect: venueAuthGuard,
        pageBuilder: (context, state) =>
            buildFadeSlidePage(state, DeferredWidget(libraryLoader: venueprofilescreen.loadLibrary, createWidget: (_) => venueprofilescreen.VenueProfileScreen())),
      ),
      GoRoute(
        path: AppRoutePaths.venueTableQr,
        name: AppRouteNames.venueTableQr,
        redirect: venueAuthGuard,
        pageBuilder: (context, state) =>
            buildFadeSlidePage(state, DeferredWidget(libraryLoader: venuetableqrscreen.loadLibrary, createWidget: (_) => venuetableqrscreen.VenueTableQrScreen())),
      ),
    ],
  ),
];
