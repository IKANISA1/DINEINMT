// ──────────────────────────────────────────────────────────────────────────────
// DineIn Custom Service Worker
// Wraps Flutter's generated service worker with:
//   1. Offline fallback to offline.html when network is unavailable
//   2. Cache-first strategy for static assets (fonts, images, icons)
//   3. Network-first for API calls (Supabase)
// ──────────────────────────────────────────────────────────────────────────────

const CACHE_NAME = 'dinein-static-v1';
const OFFLINE_URL = '/offline.html';

// Static assets to precache on install
const PRECACHE_URLS = [
  OFFLINE_URL,
  '/manifest.json',
  '/favicon.png',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
];

// ── Install: precache offline page + essential assets ─────────────────────
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(PRECACHE_URLS))
  );
  // Activate immediately without waiting for existing tabs to close
  self.skipWaiting();
});

// ── Activate: clean up old caches ─────────────────────────────────────────
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((key) => key !== CACHE_NAME && key.startsWith('dinein-'))
          .map((key) => caches.delete(key))
      )
    )
  );
  // Take control of all open tabs immediately
  self.clients.claim();
});

// ── Fetch: smart routing ──────────────────────────────────────────────────
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Skip non-GET requests
  if (request.method !== 'GET') return;

  // Skip Supabase API calls — always network-only (realtime, auth, REST)
  if (url.hostname.endsWith('.supabase.co') || url.hostname.endsWith('.supabase.in')) {
    return;
  }

  // Skip Firebase calls
  if (url.hostname.includes('firebaseapp.com') || url.hostname.includes('googleapis.com')) {
    return;
  }

  // For navigation requests: network-first with offline.html fallback
  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request).catch(() =>
        caches.match(OFFLINE_URL).then((cached) => cached || new Response('Offline', { status: 503 }))
      )
    );
    return;
  }

  // For static assets (images, fonts, icons): cache-first
  const isStaticAsset =
    url.pathname.match(/\.(png|jpg|jpeg|webp|svg|gif|ico|woff2?|ttf|otf)$/) ||
    url.pathname.startsWith('/icons/') ||
    url.pathname.startsWith('/assets/');

  if (isStaticAsset) {
    event.respondWith(
      caches.match(request).then((cached) => {
        if (cached) return cached;
        return fetch(request).then((response) => {
          // Only cache successful responses
          if (response.ok) {
            const clone = response.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(request, clone));
          }
          return response;
        }).catch(() => new Response('', { status: 404 }));
      })
    );
    return;
  }

  // For everything else (JS, WASM, etc): network-first with cache fallback
  event.respondWith(
    fetch(request)
      .then((response) => {
        if (response.ok) {
          const clone = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(request, clone));
        }
        return response;
      })
      .catch(() => caches.match(request).then((cached) => cached || new Response('', { status: 503 })))
  );
});
