import 'package:flutter_test/flutter_test.dart';

import 'package:dinein_app/core/router/app_routes.dart';

void main() {
  group('AppRoutePaths — admin routes', () {
    test('all admin route paths start with /admin', () {
      final adminPaths = [
        AppRoutePaths.adminLogin,
        AppRoutePaths.adminOverview,
        AppRoutePaths.adminVenues,
        AppRoutePaths.adminVenueCreate,
        AppRoutePaths.adminVenueDetail,
        AppRoutePaths.adminSettings,
        AppRoutePaths.adminOrders,
        AppRoutePaths.adminRoot,
      ];
      for (final path in adminPaths) {
        expect(path, startsWith('/admin'),
            reason: '$path should start with /admin');
      }
    });
  });

  group('AppRoutePaths — venue routes', () {
    test('all venue route paths start with /venue', () {
      final venuePaths = [
        AppRoutePaths.venueDashboard,
        AppRoutePaths.venueOrders,
        AppRoutePaths.venueMenu,
        AppRoutePaths.venueSettings,
        AppRoutePaths.venueProfile,
        AppRoutePaths.venueTableQr,
        AppRoutePaths.venueNotifications,
        AppRoutePaths.venueWaves,
      ];
      for (final path in venuePaths) {
        expect(path, startsWith('/venue'),
            reason: '$path should start with /venue');
      }
    });
  });

  group('AppRouteParams', () {
    test('returnTo parameter key is defined', () {
      expect(AppRouteParams.returnTo, 'returnTo');
    });
  });
}
