import 'package:go_router/go_router.dart';

import '../../features/guest/cart/cart_screen.dart' deferred as cartscreen;
import '../../features/guest/discover/discover_screen.dart'
    deferred as discoverscreen;
import '../../features/guest/guest_shell.dart' deferred as guestshell;
import '../../features/guest/menu/item_detail_screen.dart'
    deferred as itemdetailscreen;
import '../../features/guest/menu/menu_screen.dart' deferred as menuscreen;
import '../../features/guest/order/order_details_screen.dart'
    deferred as orderdetailsscreen;
import '../../features/guest/order/order_history_screen.dart'
    deferred as orderhistoryscreen;
import '../../features/guest/order/order_status_screen.dart'
    deferred as orderstatusscreen;
import '../../features/guest/order/order_success_screen.dart'
    deferred as ordersuccessscreen;
import '../../features/guest/settings/guest_settings_screen.dart'
    deferred as guestsettingsscreen;
import '../../features/guest/splash/splash_screen.dart';
import '../../features/guest/venue_detail/venue_detail_screen.dart'
    deferred as venuedetailscreen;
import '../../features/guest/venues/venues_browse_screen.dart'
    deferred as venuesbrowsescreen;
import 'app_routes.dart';
import 'deferred_widget.dart';
import 'route_helpers.dart';

final List<RouteBase> guestRoutes = [
  GoRoute(
    path: AppRoutePaths.splash,
    name: AppRouteNames.splash,
    builder: (context, state) => const SplashScreen(),
  ),
  ShellRoute(
    builder: (context, state, child) => DeferredWidget(
      libraryLoader: guestshell.loadLibrary,
      createWidget: (_) => guestshell.GuestShell(child: child),
    ),
    routes: [
      GoRoute(
        path: AppRoutePaths.venueDeepLink,
        name: AppRouteNames.venueDeepLink,
        builder: (context, state) {
          final slug = state.pathParameters[AppRouteParams.slug]!;
          final table = state.uri.queryParameters[AppRouteParams.table];
          return DeferredWidget(
            libraryLoader: venuedetailscreen.loadLibrary,
            createWidget: (_) => venuedetailscreen.VenueDetailScreen(
              slug: slug,
              tableNumber: table,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutePaths.discover,
        name: AppRouteNames.discover,
        pageBuilder: (context, state) => buildFadeSlidePage(
          state,
          DeferredWidget(
            libraryLoader: discoverscreen.loadLibrary,
            createWidget: (_) => discoverscreen.DiscoverScreen(),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.venuesBrowse,
        name: AppRouteNames.venuesBrowse,
        pageBuilder: (context, state) => buildFadeSlidePage(
          state,
          DeferredWidget(
            libraryLoader: venuesbrowsescreen.loadLibrary,
            createWidget: (_) => venuesbrowsescreen.VenuesBrowseScreen(),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.orderHistory,
        name: AppRouteNames.orderHistory,
        pageBuilder: (context, state) => buildFadeSlidePage(
          state,
          DeferredWidget(
            libraryLoader: orderhistoryscreen.loadLibrary,
            createWidget: (_) => orderhistoryscreen.OrderHistoryScreen(),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.guestSettings,
        name: AppRouteNames.guestSettings,
        pageBuilder: (context, state) => buildFadeSlidePage(
          state,
          DeferredWidget(
            libraryLoader: guestsettingsscreen.loadLibrary,
            createWidget: (_) => guestsettingsscreen.GuestSettingsScreen(),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.cart,
        name: AppRouteNames.cart,
        pageBuilder: (context, state) => buildFadeSlidePage(
          state,
          DeferredWidget(
            libraryLoader: cartscreen.loadLibrary,
            createWidget: (_) => cartscreen.CartScreen(),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.itemDetail,
        name: AppRouteNames.itemDetail,
        pageBuilder: (context, state) {
          final id = state.pathParameters[AppRouteParams.id]!;
          return buildFadeSlidePage(
            state,
            DeferredWidget(
              libraryLoader: itemdetailscreen.loadLibrary,
              createWidget: (_) =>
                  itemdetailscreen.ItemDetailScreen(itemId: id),
            ),
          );
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
              createWidget: (_) => ordersuccessscreen.OrderSuccessScreen(
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
          return buildFadeSlidePage(
            state,
            DeferredWidget(
              libraryLoader: orderstatusscreen.loadLibrary,
              createWidget: (_) =>
                  orderstatusscreen.OrderStatusScreen(orderId: id),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutePaths.orderDetails,
        name: AppRouteNames.orderDetails,
        pageBuilder: (context, state) {
          final id = state.pathParameters[AppRouteParams.id]!;
          return buildFadeSlidePage(
            state,
            DeferredWidget(
              libraryLoader: orderdetailsscreen.loadLibrary,
              createWidget: (_) =>
                  orderdetailsscreen.OrderDetailsScreen(orderId: id),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutePaths.venueDetail,
        name: AppRouteNames.venueDetail,
        builder: (context, state) {
          final slug = state.pathParameters[AppRouteParams.slug]!;
          return DeferredWidget(
            libraryLoader: venuedetailscreen.loadLibrary,
            createWidget: (_) =>
                venuedetailscreen.VenueDetailScreen(slug: slug),
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
                createWidget: (_) => menuscreen.MenuScreen(
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
];
