const CACHE_NAMESPACE = 'dinein-pwa';
const CACHE_VERSION = '__DINEIN_PWA_VERSION__';
const CACHE_NAMES = {
  shell: `${CACHE_NAMESPACE}-shell-${CACHE_VERSION}`,
  runtime: `${CACHE_NAMESPACE}-runtime-${CACHE_VERSION}`,
  api: `${CACHE_NAMESPACE}-api-${CACHE_VERSION}`,
};
const APP_SHELL_URL = '/index.html';
const OFFLINE_URL = '/offline.html';
const SHELL_ASSETS = __DINEIN_PWA_SHELL_ASSETS__;
const SHELL_ASSET_SET = new Set(SHELL_ASSETS);
const API_ORIGINS = ['supabase.co'];
const STATIC_PATTERNS = [
  /\.(?:js|css|json|png|jpg|jpeg|webp|avif|svg|gif|ico|woff2?|ttf|otf|wasm)$/i,
];

self.addEventListener('install', (event) => {
  event.waitUntil(precacheShellAssets());
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    if (self.registration.navigationPreload) {
      await self.registration.navigationPreload.enable();
    }
    await purgeOldCaches();
    await self.clients.claim();
  })());
});

self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});

self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  if (!isHttpRequest(url)) {
    return;
  }

  if (request.method !== 'GET') {
    if (isApiRequest(url)) {
      event.respondWith(handleApiMutation(request));
    }
    return;
  }

  if (request.mode === 'navigate') {
    event.respondWith(handleNavigationRequest(event));
    return;
  }

  if (isApiRequest(url)) {
    event.respondWith(networkFirstWithCache(request, CACHE_NAMES.api));
    return;
  }

  if (isShellAsset(url) || isStaticAsset(url)) {
    const cacheName = isShellAsset(url) ? CACHE_NAMES.shell : CACHE_NAMES.runtime;
    event.respondWith(staleWhileRevalidate(request, cacheName));
    return;
  }

  if (url.origin === self.location.origin) {
    event.respondWith(staleWhileRevalidate(request, CACHE_NAMES.runtime));
  }
});

async function precacheShellAssets() {
  const cache = await caches.open(CACHE_NAMES.shell);
  const failures = [];

  for (const asset of SHELL_ASSETS) {
    try {
      const response = await fetch(asset, { cache: 'no-cache' });
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      await cache.put(asset, response.clone());
    } catch (error) {
      failures.push({ asset, error: String(error) });
    }
  }

  if (failures.length > 0) {
    const missingCritical = failures.filter((entry) =>
      entry.asset === APP_SHELL_URL || entry.asset === OFFLINE_URL
    );
    if (missingCritical.length > 0) {
      throw new Error(
        `[dinein-sw] Failed to precache critical shell assets: ${JSON.stringify(missingCritical)}`,
      );
    }
    console.warn('[dinein-sw] Non-critical shell assets failed to precache', failures);
  }
}

async function purgeOldCaches() {
  const activeCaches = new Set(Object.values(CACHE_NAMES));
  const cacheNames = await caches.keys();
  await Promise.all(
    cacheNames
      .filter((name) => name.startsWith(`${CACHE_NAMESPACE}-`) && !activeCaches.has(name))
      .map((name) => caches.delete(name)),
  );
}

async function handleNavigationRequest(event) {
  const preloadResponse = await event.preloadResponse;
  if (preloadResponse) {
    return preloadResponse;
  }

  try {
    const networkResponse = await fetch(event.request);
    if (networkResponse && networkResponse.ok) {
      const cache = await caches.open(CACHE_NAMES.shell);
      await cache.put(APP_SHELL_URL, networkResponse.clone());
    }
    return networkResponse;
  } catch (_) {
    const cachedRoute = await caches.match(event.request);
    if (cachedRoute) {
      return cachedRoute;
    }

    const cachedShell = await caches.match(APP_SHELL_URL);
    if (cachedShell) {
      return cachedShell;
    }

    const offlinePage = await caches.match(OFFLINE_URL);
    if (offlinePage) {
      return offlinePage;
    }

    return buildOfflineHtmlResponse();
  }
}

async function networkFirstWithCache(request, cacheName) {
  try {
    const networkResponse = await fetch(request);
    if (networkResponse && networkResponse.ok) {
      const cache = await caches.open(cacheName);
      await cache.put(request, networkResponse.clone());
    }
    return networkResponse;
  } catch (_) {
    const cachedResponse = await caches.match(request);
    if (cachedResponse) {
      return cachedResponse;
    }

    return new Response(
      JSON.stringify({
        error: 'offline',
        recoverable: true,
        message: 'No cached response is available for this request.',
      }),
      {
        status: 503,
        statusText: 'Service Unavailable',
        headers: {
          'Content-Type': 'application/json',
          'X-DineIn-Offline': '1',
        },
      },
    );
  }
}

async function staleWhileRevalidate(request, cacheName) {
  const cache = await caches.open(cacheName);
  const cachedResponse = await cache.match(request);
  const networkFetch = fetch(request)
    .then(async (response) => {
      if (response && response.ok) {
        await cache.put(request, response.clone());
      }
      return response;
    })
    .catch(() => null);

  if (cachedResponse) {
    networkFetch.catch(() => {});
    return cachedResponse;
  }

  const networkResponse = await networkFetch;
  if (networkResponse) {
    return networkResponse;
  }

  if (request.destination === 'document') {
    const fallback = await caches.match(APP_SHELL_URL);
    if (fallback) {
      return fallback;
    }
  }

  return new Response('', { status: 504, statusText: 'Gateway Timeout' });
}

async function handleApiMutation(request) {
  try {
    return await fetch(request);
  } catch (_) {
    return new Response(
      JSON.stringify({
        error: 'offline',
        recoverable: true,
        queued: false,
        message: 'You appear to be offline. Reconnect and retry the action.',
      }),
      {
        status: 503,
        statusText: 'Service Unavailable',
        headers: {
          'Content-Type': 'application/json',
          'X-DineIn-Offline': '1',
        },
      },
    );
  }
}

function buildOfflineHtmlResponse() {
  return new Response(
    '<html><body style="background:#111;color:#fff;display:grid;place-items:center;height:100vh;font-family:sans-serif"><main style="text-align:center;padding:24px"><h1 style="margin-bottom:12px">Offline</h1><p style="margin:0;color:rgba(255,255,255,.72)">Reconnect to continue, or reopen a route you have already loaded.</p></main></body></html>',
    {
      status: 503,
      headers: { 'Content-Type': 'text/html; charset=utf-8' },
    },
  );
}

function isHttpRequest(url) {
  return url.protocol === 'http:' || url.protocol === 'https:';
}

function isApiRequest(url) {
  return API_ORIGINS.some((origin) => url.hostname.includes(origin));
}

function isShellAsset(url) {
  return url.origin === self.location.origin && SHELL_ASSET_SET.has(url.pathname);
}

function isStaticAsset(url) {
  return url.origin === self.location.origin &&
    STATIC_PATTERNS.some((pattern) => pattern.test(url.pathname));
}
