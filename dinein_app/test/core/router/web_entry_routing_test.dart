import 'package:core_pkg/config/country_config.dart';
import 'package:dinein_app/core/router/app_routes.dart';
import 'package:dinein_app/core/router/web_entry_routing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveWebAppSurface', () {
    test('detects the landing host separately from app hosts', () {
      final surface = resolveWebAppSurface(
        uri: Uri.parse('https://dineinmt.ikanisa.com/'),
        config: CountryConfig.mt,
      );

      expect(surface, WebAppSurface.landing);
    });

    test('detects guest, venue, and admin hosts', () {
      expect(
        resolveWebAppSurface(
          uri: Uri.parse('https://dineinmtg.ikanisa.com/'),
          config: CountryConfig.mt,
        ),
        WebAppSurface.guest,
      );
      expect(
        resolveWebAppSurface(
          uri: Uri.parse('https://dineinmtv.ikanisa.com/'),
          config: CountryConfig.mt,
        ),
        WebAppSurface.venue,
      );
      expect(
        resolveWebAppSurface(
          uri: Uri.parse('https://dineinmta.ikanisa.com/'),
          config: CountryConfig.mt,
        ),
        WebAppSurface.admin,
      );
    });
  });

  group('resolveWebRootRoute', () {
    test('routes guest host to discover', () {
      final route = resolveWebRootRoute(
        uri: Uri.parse('https://dineinmtg.ikanisa.com/'),
        config: CountryConfig.mt,
        hasVenueAccess: false,
        hasAdminAccess: false,
      );

      expect(route, AppRoutePaths.discover);
    });

    test('routes venue host to login when access is missing', () {
      final route = resolveWebRootRoute(
        uri: Uri.parse('https://dineinrwv.ikanisa.com/'),
        config: CountryConfig.rw,
        hasVenueAccess: false,
        hasAdminAccess: false,
      );

      expect(route, AppRoutePaths.venueLogin);
    });

    test('routes venue host to dashboard when access exists', () {
      final route = resolveWebRootRoute(
        uri: Uri.parse('https://dineinrwv.ikanisa.com/'),
        config: CountryConfig.rw,
        hasVenueAccess: true,
        hasAdminAccess: false,
      );

      expect(route, AppRoutePaths.venueDashboard);
    });

    test('routes admin host to overview when access exists', () {
      final route = resolveWebRootRoute(
        uri: Uri.parse('https://dineinmta.ikanisa.com/'),
        config: CountryConfig.mt,
        hasVenueAccess: false,
        hasAdminAccess: true,
      );

      expect(route, AppRoutePaths.adminOverview);
    });

    test('routes Rwanda guest host even when config falls back to Malta', () {
      final route = resolveWebRootRoute(
        uri: Uri.parse('https://dineinrwg.ikanisa.com/'),
        config: CountryConfig.mt,
        hasVenueAccess: false,
        hasAdminAccess: false,
      );

      expect(route, AppRoutePaths.discover);
    });

    test('routes Rwanda venue host even when config falls back to Malta', () {
      final route = resolveWebRootRoute(
        uri: Uri.parse('https://dineinrwv.ikanisa.com/'),
        config: CountryConfig.mt,
        hasVenueAccess: false,
        hasAdminAccess: false,
      );

      expect(route, AppRoutePaths.venueLogin);
    });

    test('returns null for unknown hosts', () {
      final route = resolveWebRootRoute(
        uri: Uri.parse('https://example.com/'),
        config: CountryConfig.mt,
        hasVenueAccess: false,
        hasAdminAccess: false,
      );

      expect(route, isNull);
    });

    test('returns null for the landing host', () {
      final route = resolveWebRootRoute(
        uri: Uri.parse('https://dineinrw.ikanisa.com/'),
        config: CountryConfig.rw,
        hasVenueAccess: false,
        hasAdminAccess: false,
      );

      expect(route, isNull);
    });
  });
}
