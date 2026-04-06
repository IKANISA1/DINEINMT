import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:core_pkg/config/country_runtime.dart';
import '../../features/biopay/biopay_route_surface_native.dart'
    if (dart.library.html) '../../features/biopay/biopay_route_surface_web.dart' deferred as biopaysurface;
import '../../features/guest/cart/cart_screen.dart' deferred as cartscreen;
import '../../features/guest/discover/discover_screen.dart' deferred as discoverscreen;
import '../../features/guest/guest_shell.dart' deferred as guestshell;
import '../../features/guest/menu/item_detail_screen.dart' deferred as itemdetailscreen;
import '../../features/guest/menu/menu_screen.dart' deferred as menuscreen;
import '../../features/guest/order/order_details_screen.dart' deferred as orderdetailsscreen;
import '../../features/guest/order/order_history_screen.dart' deferred as orderhistoryscreen;
import '../../features/guest/order/order_status_screen.dart' deferred as orderstatusscreen;
import '../../features/guest/order/order_success_screen.dart' deferred as ordersuccessscreen;
import '../../features/guest/settings/guest_settings_screen.dart' deferred as guestsettingsscreen;
import '../../features/guest/splash/splash_screen.dart';
import '../../features/guest/venue_detail/venue_detail_screen.dart' deferred as venuedetailscreen;
import '../../features/guest/venues/venues_browse_screen.dart' deferred as venuesbrowsescreen;
import 'app_routes.dart';
import 'deferred_widget.dart';
import 'route_helpers.dart';

String? _biopayGuard(BuildContext context, GoRouterState state) {
  return !kIsWeb && CountryRuntime.config.biopayEnabled
      ? null
      : AppRoutePaths.guestSettings;
}

String? _biopayConfirmGuard(BuildContext context, GoRouterState state) {
  final marketRedirect = _biopayGuard(context, state);
  if (marketRedirect != null) return marketRedirect;
  return state.extra != null ? null : AppRoutePaths.guestSettings;
}

final List<RouteBase> guestRoutes = [
  GoRoute(
    path: AppRoutePaths.splash,
    name: AppRouteNames.splash,
    builder: (context, state) => const SplashScreen(),
  ),
  ShellRoute(
    builder: (context, state, child) => DeferredWidget(libraryLoader: guestshell.loadLibrary, createWidget: (_) => guestshell.GuestShell(child: child)),
    routes: [
      GoRoute(
        path: AppRoutePaths.venueDeepLink,
        name: AppRouteNames.venueDeepLink,
        builder: (context, state) {
          final slug = state.pathParameters[AppRouteParams.slug]!;
          final table = state.uri.queryParameters[AppRouteParams.table];
          return DeferredWidget(
            libraryLoader: venuedetailscreen.loadLibrary,
            createWidget:
                (_) => venuedetailscreen.VenueDetailScreen(
                  slug: slug,
                  tableNumber: table,
                ),
          );
        },
      ),
      GoRoute(
        path: AppRoutePaths.discover,
        name: AppRouteNames.discover,
        pageBuilder: (context, state) =>
            buildFadeSlidePage(state, DeferredWidget(libraryLoader: discoverscreen.loadLibrary, createWidget: (_) => discoverscreen.DiscoverScreen())),
      ),
      GoRoute(
        path: AppRoutePaths.venuesBrowse,
        name: AppRouteNames.venuesBrowse,
        pageBuilder: (context, state) =>
            buildFadeSlidePage(state, DeferredWidget(libraryLoader: venuesbrowsescreen.loadLibrary, createWidget: (_) => venuesbrowsescreen.VenuesBrowseScreen())),
      ),
      GoRoute(
        path: AppRoutePaths.orderHistory,
        name: AppRouteNames.orderHistory,
        pageBuilder: (context, state) =>
            buildFadeSlidePage(state, DeferredWidget(libraryLoader: orderhistoryscreen.loadLibrary, createWidget: (_) => orderhistoryscreen.OrderHistoryScreen())),
      ),
      GoRoute(
        path: AppRoutePaths.guestSettings,
        name: AppRouteNames.guestSettings,
        pageBuilder: (context, state) =>
            buildFadeSlidePage(state, DeferredWidget(libraryLoader: guestsettingsscreen.loadLibrary, createWidget: (_) => guestsettingsscreen.GuestSettingsScreen())),
      ),
      GoRoute(
        path: AppRoutePaths.biopayHome,
        name: AppRouteNames.biopayHome,
        redirect: _biopayGuard,
        pageBuilder: (context, state) =>
            buildFadeSlidePage(state, DeferredWidget(libraryLoader: biopaysurface.loadLibrary, createWidget: (_) => biopaysurface.BiopayHomeScreen())),
      ),
      GoRoute(
        path: AppRoutePaths.cart,
        name: AppRouteNames.cart,
        pageBuilder: (context, state) =>
            buildFadeSlidePage(state, DeferredWidget(libraryLoader: cartscreen.loadLibrary, createWidget: (_) => cartscreen.CartScreen())),
      ),
      GoRoute(
        path: AppRoutePaths.itemDetail,
        name: AppRouteNames.itemDetail,
        pageBuilder: (context, state) {
          final id = state.pathParameters[AppRouteParams.id]!;
          return buildFadeSlidePage(state, DeferredWidget(libraryLoader: itemdetailscreen.loadLibrary, createWidget: (_) => itemdetailscreen.ItemDetailScreen(itemId: id)));
        },
      ),
      GoRoute(
        path: AppRoutePaths.orderSuccess,
        name: AppRouteNames.orderSuccess,
        pageBuilder: (context, state) {
          final orderId = state.uri.queryParameters[AppRouteParams.id] ?? '';
          final orderNumber =
              state.uri.queryParameters[AppRouteParams.orderNumber];
          return buildFadeSlidePage(
            state,
            DeferredWidget(
              libraryLoader: ordersuccessscreen.loadLibrary,
              createWidget:
                  (_) => ordersuccessscreen.OrderSuccessScreen(
                    orderId: orderId,
                    orderNumber: orderNumber,
                  ),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutePaths.orderStatus,
        name: AppRouteNames.orderStatus,
        pageBuilder: (context, state) {
          final id = state.pathParameters[AppRouteParams.id]!;
          return buildFadeSlidePage(state, DeferredWidget(libraryLoader: orderstatusscreen.loadLibrary, createWidget: (_) => orderstatusscreen.OrderStatusScreen(orderId: id)));
        },
      ),
      GoRoute(
        path: AppRoutePaths.orderDetails,
        name: AppRouteNames.orderDetails,
        pageBuilder: (context, state) {
          final id = state.pathParameters[AppRouteParams.id]!;
          return buildFadeSlidePage(state, DeferredWidget(libraryLoader: orderdetailsscreen.loadLibrary, createWidget: (_) => orderdetailsscreen.OrderDetailsScreen(orderId: id)));
        },
      ),
      GoRoute(
        path: AppRoutePaths.venueDetail,
        name: AppRouteNames.venueDetail,
        builder: (context, state) {
          final slug = state.pathParameters[AppRouteParams.slug]!;
          return DeferredWidget(
            libraryLoader: venuedetailscreen.loadLibrary,
            createWidget:
                (_) => venuedetailscreen.VenueDetailScreen(slug: slug),
          );
        },
        routes: [
          GoRoute(
            path: AppRoutePaths.venueMenuChild,
            name: AppRouteNames.menu,
            builder: (context, state) {
              final extra = state.extra;
              final venueId = extra is String ? extra : null;
              return DeferredWidget(
                libraryLoader: menuscreen.loadLibrary,
                createWidget:
                    (_) => menuscreen.MenuScreen(
                      venueId: venueId,
                      venueSlug: state.pathParameters[AppRouteParams.slug],
                    ),
              );
            },
          ),
        ],
      ),
    ],
  ),
  // ─── BioPay Full-Screen Routes (outside shell) ───
  GoRoute(
    path: AppRoutePaths.biopayRegister,
    name: AppRouteNames.biopayRegister,
    redirect: _biopayGuard,
    pageBuilder: (context, state) =>
        buildFadeSlidePage(state, DeferredWidget(libraryLoader: biopaysurface.loadLibrary, createWidget: (_) => biopaysurface.BiopayRegisterScreen())),
  ),
  GoRoute(
    path: AppRoutePaths.biopayScanner,
    name: AppRouteNames.biopayScanner,
    redirect: _biopayGuard,
    pageBuilder: (context, state) =>
        buildFadeSlidePage(state, DeferredWidget(libraryLoader: biopaysurface.loadLibrary, createWidget: (_) => biopaysurface.BiopayScannerScreen())),
  ),
  GoRoute(
    path: AppRoutePaths.biopayConfirm,
    name: AppRouteNames.biopayConfirm,
    redirect: _biopayConfirmGuard,
    pageBuilder: (context, state) {
      final matchResult = state.extra;
      return buildFadeSlidePage(
        state,
        DeferredWidget(
          libraryLoader: biopaysurface.loadLibrary,
          createWidget:
              (_) => biopaysurface.BiopayConfirmScreen(matchResult: matchResult),
        ),
      );
    },
  ),
  GoRoute(
    path: AppRoutePaths.biopayReEnroll,
    name: AppRouteNames.biopayReEnroll,
    redirect: _biopayGuard,
    pageBuilder: (context, state) =>
        buildFadeSlidePage(state, DeferredWidget(libraryLoader: biopaysurface.loadLibrary, createWidget: (_) => biopaysurface.BiopayReEnrollScreen())),
  ),
  GoRoute(
    path: AppRoutePaths.biopayManage,
    name: AppRouteNames.biopayManage,
    redirect: _biopayGuard,
    pageBuilder: (context, state) =>
        buildFadeSlidePage(state, DeferredWidget(libraryLoader: biopaysurface.loadLibrary, createWidget: (_) => biopaysurface.BiopayManageScreen())),
  ),
];
