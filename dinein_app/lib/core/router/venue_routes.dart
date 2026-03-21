import 'package:go_router/go_router.dart';

import '../../features/venue/onboarding/venue_onboarding_flow.dart';
import '../../features/venue/auth/venue_login_screen.dart';

import '../../features/venue/dashboard/venue_dashboard_screen.dart';
import '../../features/venue/menu/venue_edit_item_screen.dart';
import '../../features/venue/menu/venue_menu_manager_screen.dart';
import '../../features/venue/menu/venue_ocr_review_screen.dart';

import '../../features/venue/orders/venue_order_detail_screen.dart';
import '../../features/venue/orders/venue_orders_screen.dart';
import '../../features/venue/reports/venue_item_report_screen.dart';
import '../../features/venue/settings/venue_hours_screen.dart';
import '../../features/venue/settings/venue_language_region_screen.dart';
import '../../features/venue/settings/venue_legal_screen.dart';
import '../../features/venue/settings/venue_notifications_screen.dart';
import '../../features/venue/settings/venue_profile_screen.dart';
import '../../features/venue/settings/venue_wifi_screen.dart';
import '../../features/venue/settings/venue_settings_screen.dart';
import '../../features/venue/waves/venue_waves_screen.dart';
import '../../features/venue/venue_shell.dart';
import 'app_routes.dart';
import 'route_guards.dart';
import 'route_helpers.dart';

final List<RouteBase> venueRoutes = [
  GoRoute(
    path: AppRoutePaths.venueLogin,
    name: AppRouteNames.venueLogin,
    builder: (context, state) => const VenueLoginScreen(),
  ),
  GoRoute(
    path: AppRoutePaths.venueClaim,
    name: AppRouteNames.venueClaim,
    builder: (context, state) => const VenueOnboardingFlow(),
  ),

  GoRoute(
    path: AppRoutePaths.venueOrderDetail,
    name: AppRouteNames.venueOrderDetail,
    redirect: venueAuthGuard,
    builder: (context, state) {
      final id = state.pathParameters[AppRouteParams.id]!;
      return VenueOrderDetailScreen(orderId: id);
    },
  ),
  GoRoute(
    path: AppRoutePaths.venueNewItem,
    name: AppRouteNames.venueNewItem,
    redirect: venueAuthGuard,
    builder: (context, state) => const VenueEditItemScreen(),
  ),
  GoRoute(
    path: AppRoutePaths.venueEditItem,
    name: AppRouteNames.venueEditItem,
    redirect: venueAuthGuard,
    builder: (context, state) {
      final id = state.pathParameters[AppRouteParams.id]!;
      return VenueEditItemScreen(itemId: id);
    },
  ),
  GoRoute(
    path: AppRoutePaths.venueOcrReview,
    name: AppRouteNames.venueOcrReview,
    redirect: venueOcrGuard,
    builder: (context, state) => VenueOcrReviewScreen(
      manualMode: state.uri.queryParameters[AppRouteParams.manual] == 'true',
      source: state.uri.queryParameters[AppRouteParams.source] ?? 'onboarding',
      venueId: state.uri.queryParameters[AppRouteParams.venueId],
    ),
  ),
  GoRoute(
    path: AppRoutePaths.venueItemReport,
    name: AppRouteNames.venueItemReport,
    redirect: venueAuthGuard,
    builder: (context, state) => const VenueItemReportScreen(),
  ),
  GoRoute(
    path: AppRoutePaths.venueProfile,
    name: AppRouteNames.venueProfile,
    redirect: venueAuthGuard,
    builder: (context, state) => const VenueProfileScreen(),
  ),
  GoRoute(
    path: AppRoutePaths.venueHours,
    name: AppRouteNames.venueHours,
    redirect: venueAuthGuard,
    builder: (context, state) => const VenueHoursScreen(),
  ),
  GoRoute(
    path: AppRoutePaths.venueNotifications,
    name: AppRouteNames.venueNotifications,
    redirect: venueAuthGuard,
    builder: (context, state) => const VenueNotificationsScreen(),
  ),
  GoRoute(
    path: AppRoutePaths.venueLanguageRegion,
    name: AppRouteNames.venueLanguageRegion,
    redirect: venueAuthGuard,
    builder: (context, state) => const VenueLanguageRegionScreen(),
  ),
  GoRoute(
    path: AppRoutePaths.venueLegal,
    name: AppRouteNames.venueLegal,
    redirect: venueAuthGuard,
    builder: (context, state) => const VenueLegalScreen(),
  ),
  GoRoute(
    path: AppRoutePaths.venueWifi,
    name: AppRouteNames.venueWifi,
    redirect: venueAuthGuard,
    builder: (context, state) => const VenueWifiScreen(),
  ),
  GoRoute(
    path: AppRoutePaths.venueWaves,
    name: AppRouteNames.venueWaves,
    redirect: venueAuthGuard,
    builder: (context, state) => const VenueWavesScreen(),
  ),
  ShellRoute(
    builder: (context, state, child) => VenueShell(child: child),
    routes: [
      GoRoute(
        path: AppRoutePaths.venueDashboard,
        name: AppRouteNames.venueDashboard,
        redirect: venueAuthGuard,
        pageBuilder: (context, state) =>
            buildFadeSlidePage(state, const VenueDashboardScreen()),
      ),
      GoRoute(
        path: AppRoutePaths.venueOrders,
        name: AppRouteNames.venueOrders,
        redirect: venueAuthGuard,
        pageBuilder: (context, state) =>
            buildFadeSlidePage(state, const VenueOrdersScreen()),
      ),
      GoRoute(
        path: AppRoutePaths.venueMenu,
        name: AppRouteNames.venueMenu,
        redirect: venueAuthGuard,
        pageBuilder: (context, state) =>
            buildFadeSlidePage(state, const VenueMenuManagerScreen()),
      ),
      GoRoute(
        path: AppRoutePaths.venueSettings,
        name: AppRouteNames.venueSettings,
        redirect: venueAuthGuard,
        pageBuilder: (context, state) =>
            buildFadeSlidePage(state, const VenueSettingsScreen()),
      ),
    ],
  ),
];
