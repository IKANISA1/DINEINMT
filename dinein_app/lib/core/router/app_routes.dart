abstract final class AppRouteNames {
  static const splash = 'splash';
  static const venueDeepLink = 'venueDeepLink';
  static const discover = 'discover';
  static const venuesBrowse = 'venuesBrowse';
  static const orderHistory = 'orderHistory';
  static const guestSettings = 'guestSettings';
  static const cart = 'cart';
  static const itemDetail = 'itemDetail';
  static const orderSuccess = 'orderSuccess';
  static const orderStatus = 'orderStatus';
  static const orderDetails = 'orderDetails';
  static const venueDetail = 'venueDetail';
  static const menu = 'menu';

  static const venueLogin = 'venueLogin';
  static const venueClaim = 'venueClaim';
  static const venueVerify = 'venueVerify';
  static const venueOnboarding = 'venueOnboarding';
  static const venueOrderDetail = 'venueOrderDetail';
  static const venueNewItem = 'venueNewItem';
  static const venueEditItem = 'venueEditItem';
  static const venueOcrReview = 'venueOcrReview';
  static const venueDashboard = 'venueDashboard';
  static const venueOrders = 'venueOrders';
  static const venueMenu = 'venueMenu';
  static const venueSettings = 'venueSettings';
  static const venueItemReport = 'venueItemReport';
  static const venueProfile = 'venueProfile';
  static const venueTableQr = 'venueTableQr';
  static const venueHours = 'venueHours';
  static const venueNotifications = 'venueNotifications';
  static const venueLanguageRegion = 'venueLanguageRegion';
  static const venueLegal = 'venueLegal';
  static const venueWifi = 'venueWifi';
  static const venueWaves = 'venueWaves';

  static const adminLogin = 'adminLogin';
  static const adminActivation = 'adminActivation';
  static const adminOverview = 'adminOverview';
  static const adminClaims = 'adminClaims';
  static const adminClaimDetail = 'adminClaimDetail';
  static const adminVenues = 'adminVenues';
  static const adminVenueDetail = 'adminVenueDetail';
  static const adminSettings = 'adminSettings';
  static const adminMenus = 'adminMenus';
  static const adminMenuReview = 'adminMenuReview';
  static const adminOrders = 'adminOrders';

  static const biopayHome = 'biopayHome';
  static const biopayRegister = 'biopayRegister';
  static const biopayScanner = 'biopayScanner';
  static const biopayConfirm = 'biopayConfirm';
  static const biopayReEnroll = 'biopayReEnroll';
  static const biopayManage = 'biopayManage';
}

abstract final class AppRouteParams {
  static const id = 'id';
  static const orderNumber = 'orderNumber';
  static const slug = 'slug';
  static const table = 't';
  static const manual = 'manual';
  static const source = 'source';
  static const venueId = 'venueId';
  static const returnTo = 'returnTo';
}

abstract final class AppRoutePaths {
  static const splash = '/';
  static const venueDeepLink = '/v/:${AppRouteParams.slug}';
  static const discover = '/discover';
  static const venuesBrowse = '/venues';
  static const orderHistory = '/orders';
  static const guestSettings = '/settings';
  static const cart = '/cart';
  static const itemDetail = '/item/:${AppRouteParams.id}';
  static const orderSuccess = '/order-success';
  static const orderStatus = '/order/:${AppRouteParams.id}';
  static const orderDetails = '/order/:${AppRouteParams.id}/details';
  static const venueDetail = '/venue/:${AppRouteParams.slug}';
  static const venueMenuChild = 'menu';

  static const venueLogin = '/venue-login';
  static const venueClaim = '/venue/claim';
  static const venueVerify = '/venue/verify';
  static const venueOnboarding = '/venue/onboarding';
  static const venueOrderDetail = '/venue/order/:${AppRouteParams.id}';
  static const venueNewItem = '/venue/item/new';
  static const venueEditItem = '/venue/item/:${AppRouteParams.id}';
  static const venueOcrReview = '/venue/ocr-review';
  static const venueDashboard = '/venue/dashboard';
  static const venueOrders = '/venue/orders';
  static const venueMenu = '/venue/menu';
  static const venueSettings = '/venue/settings';
  static const venueItemReport = '/venue/item-report';
  static const venueProfile = '/venue/profile';
  static const venueTableQr = '/venue/table-qr';
  static const venueHours = '/venue/hours';
  static const venueNotifications = '/venue/notifications';
  static const venueLanguageRegion = '/venue/language-region';
  static const venueLegal = '/venue/legal';
  static const venueWifi = '/venue/wifi';
  static const venueWaves = '/venue/waves';

  static const adminLogin = '/admin/login';
  static const adminActivation =
      '/admin/venues/:${AppRouteParams.id}/activation';
  static const adminOverview = '/admin/overview';
  static const adminClaims = '/admin/claims';
  static const adminClaimDetail = '/admin/claims/:${AppRouteParams.id}';
  static const adminVenues = '/admin/venues';
  static const adminVenueDetail = '/admin/venues/:${AppRouteParams.id}';
  static const adminSettings = '/admin/settings';
  static const adminMenus = '/admin/menus';
  static const adminMenuReview = '/admin/menus/:${AppRouteParams.id}';
  static const adminOrders = '/admin/orders';
  static const adminRoot = '/admin';

  static const orderBase = '/order';

  static const biopayHome = '/biopay';
  static const biopayRegister = '/biopay/register';
  static const biopayScanner = '/biopay/scan';
  static const biopayConfirm = '/biopay/confirm';
  static const biopayReEnroll = '/biopay/re-enroll';
  static const biopayManage = '/biopay/manage';
}
