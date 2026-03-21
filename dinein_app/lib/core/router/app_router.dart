import 'package:go_router/go_router.dart';
import 'admin_routes.dart';
import 'guest_routes.dart';
import 'venue_routes.dart';

/// App-wide GoRouter configuration.
///
/// Deep link support: `/v/{slug}` is the canonical entry route.
/// Optional table parameter: `?t=12`
final appRouter = GoRouter(
  initialLocation: '/',
  // Keep specific protected route trees ahead of guest dynamic slug routes.
  routes: [...adminRoutes, ...venueRoutes, ...guestRoutes],
);
