import 'package:go_router/go_router.dart';

import '../../features/guest/cart/cart_screen.dart';
import '../../features/guest/discover/discover_screen.dart';
import '../../features/guest/guest_shell.dart';
import '../../features/guest/menu/item_detail_screen.dart';
import '../../features/guest/menu/menu_screen.dart';
import '../../features/guest/order/order_details_screen.dart';
import '../../features/guest/order/order_history_screen.dart';
import '../../features/guest/order/order_status_screen.dart';
import '../../features/guest/order/order_success_screen.dart';
import '../../features/guest/settings/guest_settings_screen.dart';
import '../../features/guest/splash/splash_screen.dart';
import '../../features/guest/venue_detail/venue_detail_screen.dart';
import '../../features/guest/venues/venues_browse_screen.dart';
import 'app_routes.dart';
import 'route_helpers.dart';

final List<RouteBase> guestRoutes = [
  GoRoute(
    path: AppRoutePaths.splash,
    name: AppRouteNames.splash,
    builder: (context, state) => const SplashScreen(),
  ),
  GoRoute(
    path: AppRoutePaths.venueDeepLink,
    name: AppRouteNames.venueDeepLink,
    builder: (context, state) {
      final slug = state.pathParameters[AppRouteParams.slug]!;
      final table = state.uri.queryParameters[AppRouteParams.table];
      return VenueDetailScreen(slug: slug, tableNumber: table);
    },
  ),
  ShellRoute(
    builder: (context, state, child) => GuestShell(child: child),
    routes: [
      GoRoute(
        path: AppRoutePaths.discover,
        name: AppRouteNames.discover,
        pageBuilder: (context, state) =>
            buildFadeSlidePage(state, const DiscoverScreen()),
      ),
      GoRoute(
        path: AppRoutePaths.venuesBrowse,
        name: AppRouteNames.venuesBrowse,
        pageBuilder: (context, state) =>
            buildFadeSlidePage(state, const VenuesBrowseScreen()),
      ),
      GoRoute(
        path: AppRoutePaths.orderHistory,
        name: AppRouteNames.orderHistory,
        pageBuilder: (context, state) =>
            buildFadeSlidePage(state, const OrderHistoryScreen()),
      ),
      GoRoute(
        path: AppRoutePaths.guestSettings,
        name: AppRouteNames.guestSettings,
        pageBuilder: (context, state) =>
            buildFadeSlidePage(state, const GuestSettingsScreen()),
      ),
    ],
  ),
  GoRoute(
    path: AppRoutePaths.cart,
    name: AppRouteNames.cart,
    pageBuilder: (context, state) =>
        buildFadeSlidePage(state, const CartScreen()),
  ),
  GoRoute(
    path: AppRoutePaths.itemDetail,
    name: AppRouteNames.itemDetail,
    pageBuilder: (context, state) {
      final id = state.pathParameters[AppRouteParams.id]!;
      return buildFadeSlidePage(state, ItemDetailScreen(itemId: id));
    },
  ),
  GoRoute(
    path: AppRoutePaths.orderSuccess,
    name: AppRouteNames.orderSuccess,
    pageBuilder: (context, state) {
      final orderId = state.uri.queryParameters[AppRouteParams.id] ?? '';
      return buildFadeSlidePage(state, OrderSuccessScreen(orderId: orderId));
    },
  ),
  GoRoute(
    path: AppRoutePaths.orderStatus,
    name: AppRouteNames.orderStatus,
    pageBuilder: (context, state) {
      final id = state.pathParameters[AppRouteParams.id]!;
      return buildFadeSlidePage(state, OrderStatusScreen(orderId: id));
    },
  ),
  GoRoute(
    path: AppRoutePaths.orderDetails,
    name: AppRouteNames.orderDetails,
    pageBuilder: (context, state) {
      final id = state.pathParameters[AppRouteParams.id]!;
      return buildFadeSlidePage(state, OrderDetailsScreen(orderId: id));
    },
  ),
  GoRoute(
    path: AppRoutePaths.venueDetail,
    name: AppRouteNames.venueDetail,
    builder: (context, state) {
      final slug = state.pathParameters[AppRouteParams.slug]!;
      return VenueDetailScreen(slug: slug);
    },
    routes: [
      GoRoute(
        path: AppRoutePaths.venueMenuChild,
        name: AppRouteNames.menu,
        builder: (context, state) {
          final venueId =
              state.extra as String? ??
              state.pathParameters[AppRouteParams.slug]!;
          return MenuScreen(venueId: venueId);
        },
      ),
    ],
  ),
];
