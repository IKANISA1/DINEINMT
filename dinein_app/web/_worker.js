const LANDING_HOST = "__DINEIN_SITE_HOST__";
const GUEST_HOST = "__DINEIN_GUEST_HOST__";
const VENUE_HOST = "__DINEIN_VENUE_HOST__";
const ADMIN_HOST = "__DINEIN_ADMIN_HOST__";

function rewriteLandingPath(pathname) {
  switch (pathname) {
    case "/":
    case "":
    case "/index.html":
    case "/landing":
    case "/landing/":
      return "/landing/";
    case "/privacy":
    case "/privacy/":
      return "/privacy/";
    case "/terms":
    case "/terms/":
      return "/terms/";
    case "/download":
    case "/download/":
      return "/download/";
    default:
      return null;
  }
}

const venuePortalPrefixes = [
  "/venue-login",
  "/venue/dashboard",
  "/venue/orders",
  "/venue/menu",
  "/venue/settings",
  "/venue/item-report",
  "/venue/profile",
  "/venue/table-qr",
  "/venue/notifications",
  "/venue/language-region",
  "/venue/legal",
  "/venue/wifi",
  "/venue/waves",
  "/venue/item/",
  "/venue/order/",
];

const guestPrefixes = [
  "/discover",
  "/venues",
  "/orders",
  "/settings",
  "/cart",
  "/item/",
  "/order/",
];

function matchesPrefix(pathname, prefixes) {
  return prefixes.some((prefix) =>
    pathname === prefix || pathname.startsWith(`${prefix}/`)
  );
}

function resolveRedirectHost(pathname) {
  if (pathname === "/admin" || pathname.startsWith("/admin/")) {
    return ADMIN_HOST;
  }

  if (matchesPrefix(pathname, venuePortalPrefixes)) {
    return VENUE_HOST;
  }

  if (matchesPrefix(pathname, guestPrefixes)) {
    return GUEST_HOST;
  }

  if (pathname === "/venue" || pathname.startsWith("/venue/")) {
    return GUEST_HOST;
  }

  return null;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.hostname.toLowerCase() === LANDING_HOST) {
      const rewrittenPath = rewriteLandingPath(url.pathname);
      if (rewrittenPath) {
        const rewrittenUrl = new URL(request.url);
        rewrittenUrl.pathname = rewrittenPath;
        return env.ASSETS.fetch(new Request(rewrittenUrl, request));
      }

      const redirectHost = resolveRedirectHost(url.pathname);
      if (redirectHost) {
        const redirectUrl = new URL(request.url);
        redirectUrl.hostname = redirectHost;
        return Response.redirect(redirectUrl.toString(), 308);
      }
    }

    return env.ASSETS.fetch(request);
  },
};
