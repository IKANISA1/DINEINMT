import '../router/app_routes.dart';

const dineInSiteHost = 'dineinmalta.com';
const dineInGooglePlayUrl =
    'https://play.google.com/store/apps/details?id=com.dineinmalta.app';

Uri buildVenueDeepLinkUri({required String slug}) {
  return Uri.https(dineInSiteHost, '/v/$slug');
}

Uri buildVenueTableDeepLinkUri({
  required String slug,
  required String tableNumber,
}) {
  return Uri.https(dineInSiteHost, '/v/$slug', {
    AppRouteParams.table: tableNumber,
  });
}

Uri buildVenueTableDownloadRedirectUri({
  required String slug,
  required String tableNumber,
  String? venueName,
}) {
  final target = buildVenueTableDeepLinkUri(
    slug: slug,
    tableNumber: tableNumber,
  );
  return Uri.https(dineInSiteHost, '/download/', {
    'slug': slug,
    'target': target.toString(),
    AppRouteParams.table: tableNumber,
    if (venueName != null && venueName.trim().isNotEmpty) 'venue': venueName,
  });
}
