import '../config/country_config.dart';
import '../router/app_routes.dart';

/// Build a venue deep link URI using the active country config.
Uri buildVenueDeepLinkUri({
  required String slug,
  required CountryConfig config,
}) {
  return Uri.https(config.siteHost, '/v/$slug');
}

/// Build a venue + table deep link URI.
Uri buildVenueTableDeepLinkUri({
  required String slug,
  required String tableNumber,
  required CountryConfig config,
}) {
  return Uri.https(config.siteHost, '/v/$slug', {
    AppRouteParams.table: tableNumber,
  });
}

/// Build a smart download redirect URI.
Uri buildVenueTableDownloadRedirectUri({
  required String slug,
  required String tableNumber,
  required CountryConfig config,
  String? venueName,
}) {
  final target = buildVenueTableDeepLinkUri(
    slug: slug,
    tableNumber: tableNumber,
    config: config,
  );
  return Uri.https(config.siteHost, '/download/', {
    'slug': slug,
    'target': target.toString(),
    AppRouteParams.table: tableNumber,
    if (venueName != null && venueName.trim().isNotEmpty) 'venue': venueName,
  });
}
