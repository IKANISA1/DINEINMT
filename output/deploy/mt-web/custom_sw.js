const CACHE_NAMESPACE = 'dinein-pwa';
const CACHE_VERSION = '8b881e779e5dc57d7538';
const OFFLINE_QUEUE_DB = `${CACHE_NAMESPACE}-offline-queue`;
const OFFLINE_QUEUE_STORE = 'requests';
const OFFLINE_QUEUE_SYNC_TAG = 'dinein-offline-queue-sync';
const CACHE_NAMES = {
  shell: `${CACHE_NAMESPACE}-shell-${CACHE_VERSION}`,
  runtime: `${CACHE_NAMESPACE}-runtime-${CACHE_VERSION}`,
  api: `${CACHE_NAMESPACE}-api-${CACHE_VERSION}`,
};
const APP_SHELL_URL = '/index.html';
const OFFLINE_URL = '/offline.html';
const SHELL_ASSETS = [
  "/index.html",
  "/offline.html",
  "/manifest.json",
  "/flutter.js",
  "/flutter_bootstrap.js",
  "/main.dart.js",
  "/assets/AssetManifest.bin",
  "/assets/AssetManifest.bin.json",
  "/assets/FontManifest.json",
  "/assets/NOTICES",
  "/assets/assets/branding/dinein-brand-icon-1024.png",
  "/assets/assets/branding/dinein-brand-icon-512.png",
  "/assets/assets/branding/dinein_logo.png",
  "/assets/assets/ml/.gitkeep",
  "/assets/assets/ml/mobilefacenet.tflite",
  "/assets/fonts/MaterialIcons-Regular.otf",
  "/assets/packages/cupertino_icons/assets/CupertinoIcons.ttf",
  "/assets/packages/lucide_icons/assets/lucide.ttf",
  "/assets/shaders/ink_sparkle.frag",
  "/assets/shaders/stretch_effect.frag",
  "/canvaskit/canvaskit.js",
  "/canvaskit/canvaskit.wasm",
  "/canvaskit/chromium/canvaskit.js",
  "/canvaskit/chromium/canvaskit.wasm",
  "/canvaskit/skwasm.js",
  "/canvaskit/skwasm.wasm",
  "/canvaskit/skwasm_heavy.js",
  "/canvaskit/skwasm_heavy.wasm",
  "/discover/index.html",
  "/favicon.png",
  "/firebase-messaging-sw.js",
  "/icons/Icon-192.png",
  "/icons/Icon-512.png",
  "/icons/Icon-maskable-192.png",
  "/icons/Icon-maskable-512.png",
  "/main.dart.js_1.part.js",
  "/main.dart.js_10.part.js",
  "/main.dart.js_100.part.js",
  "/main.dart.js_101.part.js",
  "/main.dart.js_102.part.js",
  "/main.dart.js_103.part.js",
  "/main.dart.js_104.part.js",
  "/main.dart.js_105.part.js",
  "/main.dart.js_106.part.js",
  "/main.dart.js_107.part.js",
  "/main.dart.js_108.part.js",
  "/main.dart.js_109.part.js",
  "/main.dart.js_11.part.js",
  "/main.dart.js_110.part.js",
  "/main.dart.js_111.part.js",
  "/main.dart.js_112.part.js",
  "/main.dart.js_113.part.js",
  "/main.dart.js_114.part.js",
  "/main.dart.js_115.part.js",
  "/main.dart.js_116.part.js",
  "/main.dart.js_117.part.js",
  "/main.dart.js_118.part.js",
  "/main.dart.js_119.part.js",
  "/main.dart.js_12.part.js",
  "/main.dart.js_120.part.js",
  "/main.dart.js_121.part.js",
  "/main.dart.js_122.part.js",
  "/main.dart.js_123.part.js",
  "/main.dart.js_124.part.js",
  "/main.dart.js_125.part.js",
  "/main.dart.js_126.part.js",
  "/main.dart.js_127.part.js",
  "/main.dart.js_128.part.js",
  "/main.dart.js_129.part.js",
  "/main.dart.js_13.part.js",
  "/main.dart.js_130.part.js",
  "/main.dart.js_131.part.js",
  "/main.dart.js_132.part.js",
  "/main.dart.js_133.part.js",
  "/main.dart.js_134.part.js",
  "/main.dart.js_135.part.js",
  "/main.dart.js_136.part.js",
  "/main.dart.js_137.part.js",
  "/main.dart.js_138.part.js",
  "/main.dart.js_139.part.js",
  "/main.dart.js_14.part.js",
  "/main.dart.js_140.part.js",
  "/main.dart.js_141.part.js",
  "/main.dart.js_142.part.js",
  "/main.dart.js_143.part.js",
  "/main.dart.js_144.part.js",
  "/main.dart.js_145.part.js",
  "/main.dart.js_146.part.js",
  "/main.dart.js_147.part.js",
  "/main.dart.js_148.part.js",
  "/main.dart.js_149.part.js",
  "/main.dart.js_15.part.js",
  "/main.dart.js_150.part.js",
  "/main.dart.js_151.part.js",
  "/main.dart.js_152.part.js",
  "/main.dart.js_153.part.js",
  "/main.dart.js_154.part.js",
  "/main.dart.js_155.part.js",
  "/main.dart.js_156.part.js",
  "/main.dart.js_157.part.js",
  "/main.dart.js_158.part.js",
  "/main.dart.js_159.part.js",
  "/main.dart.js_160.part.js",
  "/main.dart.js_161.part.js",
  "/main.dart.js_162.part.js",
  "/main.dart.js_163.part.js",
  "/main.dart.js_164.part.js",
  "/main.dart.js_165.part.js",
  "/main.dart.js_166.part.js",
  "/main.dart.js_167.part.js",
  "/main.dart.js_168.part.js",
  "/main.dart.js_169.part.js",
  "/main.dart.js_17.part.js",
  "/main.dart.js_170.part.js",
  "/main.dart.js_171.part.js",
  "/main.dart.js_172.part.js",
  "/main.dart.js_173.part.js",
  "/main.dart.js_174.part.js",
  "/main.dart.js_175.part.js",
  "/main.dart.js_176.part.js",
  "/main.dart.js_177.part.js",
  "/main.dart.js_178.part.js",
  "/main.dart.js_179.part.js",
  "/main.dart.js_18.part.js",
  "/main.dart.js_180.part.js",
  "/main.dart.js_181.part.js",
  "/main.dart.js_182.part.js",
  "/main.dart.js_183.part.js",
  "/main.dart.js_184.part.js",
  "/main.dart.js_185.part.js",
  "/main.dart.js_186.part.js",
  "/main.dart.js_187.part.js",
  "/main.dart.js_188.part.js",
  "/main.dart.js_189.part.js",
  "/main.dart.js_19.part.js",
  "/main.dart.js_190.part.js",
  "/main.dart.js_191.part.js",
  "/main.dart.js_192.part.js",
  "/main.dart.js_193.part.js",
  "/main.dart.js_194.part.js",
  "/main.dart.js_195.part.js",
  "/main.dart.js_196.part.js",
  "/main.dart.js_197.part.js",
  "/main.dart.js_198.part.js",
  "/main.dart.js_199.part.js",
  "/main.dart.js_2.part.js",
  "/main.dart.js_20.part.js",
  "/main.dart.js_200.part.js",
  "/main.dart.js_201.part.js",
  "/main.dart.js_202.part.js",
  "/main.dart.js_203.part.js",
  "/main.dart.js_204.part.js",
  "/main.dart.js_205.part.js",
  "/main.dart.js_206.part.js",
  "/main.dart.js_207.part.js",
  "/main.dart.js_208.part.js",
  "/main.dart.js_209.part.js",
  "/main.dart.js_21.part.js",
  "/main.dart.js_210.part.js",
  "/main.dart.js_211.part.js",
  "/main.dart.js_212.part.js",
  "/main.dart.js_213.part.js",
  "/main.dart.js_214.part.js",
  "/main.dart.js_215.part.js",
  "/main.dart.js_216.part.js",
  "/main.dart.js_217.part.js",
  "/main.dart.js_218.part.js",
  "/main.dart.js_219.part.js",
  "/main.dart.js_22.part.js",
  "/main.dart.js_220.part.js",
  "/main.dart.js_222.part.js",
  "/main.dart.js_223.part.js",
  "/main.dart.js_224.part.js",
  "/main.dart.js_225.part.js",
  "/main.dart.js_226.part.js",
  "/main.dart.js_227.part.js",
  "/main.dart.js_228.part.js",
  "/main.dart.js_229.part.js",
  "/main.dart.js_23.part.js",
  "/main.dart.js_230.part.js",
  "/main.dart.js_231.part.js",
  "/main.dart.js_232.part.js",
  "/main.dart.js_234.part.js",
  "/main.dart.js_235.part.js",
  "/main.dart.js_24.part.js",
  "/main.dart.js_25.part.js",
  "/main.dart.js_26.part.js",
  "/main.dart.js_27.part.js",
  "/main.dart.js_28.part.js",
  "/main.dart.js_29.part.js",
  "/main.dart.js_3.part.js",
  "/main.dart.js_30.part.js",
  "/main.dart.js_32.part.js",
  "/main.dart.js_33.part.js",
  "/main.dart.js_34.part.js",
  "/main.dart.js_35.part.js",
  "/main.dart.js_36.part.js",
  "/main.dart.js_37.part.js",
  "/main.dart.js_38.part.js",
  "/main.dart.js_39.part.js",
  "/main.dart.js_4.part.js",
  "/main.dart.js_40.part.js",
  "/main.dart.js_41.part.js",
  "/main.dart.js_42.part.js",
  "/main.dart.js_43.part.js",
  "/main.dart.js_44.part.js",
  "/main.dart.js_45.part.js",
  "/main.dart.js_46.part.js",
  "/main.dart.js_47.part.js",
  "/main.dart.js_48.part.js",
  "/main.dart.js_49.part.js",
  "/main.dart.js_5.part.js",
  "/main.dart.js_50.part.js",
  "/main.dart.js_51.part.js",
  "/main.dart.js_52.part.js",
  "/main.dart.js_53.part.js",
  "/main.dart.js_54.part.js",
  "/main.dart.js_55.part.js",
  "/main.dart.js_56.part.js",
  "/main.dart.js_57.part.js",
  "/main.dart.js_58.part.js",
  "/main.dart.js_59.part.js",
  "/main.dart.js_60.part.js",
  "/main.dart.js_61.part.js",
  "/main.dart.js_62.part.js",
  "/main.dart.js_63.part.js",
  "/main.dart.js_64.part.js",
  "/main.dart.js_65.part.js",
  "/main.dart.js_66.part.js",
  "/main.dart.js_67.part.js",
  "/main.dart.js_68.part.js",
  "/main.dart.js_69.part.js",
  "/main.dart.js_70.part.js",
  "/main.dart.js_71.part.js",
  "/main.dart.js_72.part.js",
  "/main.dart.js_73.part.js",
  "/main.dart.js_74.part.js",
  "/main.dart.js_75.part.js",
  "/main.dart.js_76.part.js",
  "/main.dart.js_77.part.js",
  "/main.dart.js_78.part.js",
  "/main.dart.js_79.part.js",
  "/main.dart.js_8.part.js",
  "/main.dart.js_80.part.js",
  "/main.dart.js_81.part.js",
  "/main.dart.js_82.part.js",
  "/main.dart.js_83.part.js",
  "/main.dart.js_84.part.js",
  "/main.dart.js_85.part.js",
  "/main.dart.js_86.part.js",
  "/main.dart.js_87.part.js",
  "/main.dart.js_88.part.js",
  "/main.dart.js_89.part.js",
  "/main.dart.js_9.part.js",
  "/main.dart.js_90.part.js",
  "/main.dart.js_91.part.js",
  "/main.dart.js_92.part.js",
  "/main.dart.js_93.part.js",
  "/main.dart.js_94.part.js",
  "/main.dart.js_95.part.js",
  "/main.dart.js_96.part.js",
  "/main.dart.js_97.part.js",
  "/main.dart.js_98.part.js",
  "/main.dart.js_99.part.js",
  "/robots.txt",
  "/screenshots/discover-mobile.png",
  "/screenshots/venues-desktop.png",
  "/sitemap.xml",
  "/venues/index.html",
  "/version.json"
];
const SHELL_ASSET_SET = new Set(SHELL_ASSETS);
const API_ORIGINS = ['supabase.co'];
const STATIC_PATTERNS = [
  /\.(?:js|css|json|png|jpg|jpeg|webp|avif|svg|gif|ico|woff2?|ttf|otf|wasm)$/i,
];
let replayInFlight = null;

self.addEventListener('install', (event) => {
  event.waitUntil(precacheShellAssets());
  // Do NOT call self.skipWaiting() here — the new worker must remain
  // in the "waiting" state so the update banner can offer a controlled
  // reload.  The SKIP_WAITING message listener (below) handles activation
  // when the user taps "Reload".
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    if (self.registration.navigationPreload) {
      await self.registration.navigationPreload.enable();
    }
    await purgeOldCaches();
    await self.clients.claim();
    await replayQueuedRequests();
  })());
});

self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }

  // Forward push messages from FCM SW to any visible Flutter clients
  if (event.data && event.data.type === 'PUSH_RECEIVED') {
    self.clients.matchAll({ type: 'window' }).then((clients) => {
      for (const client of clients) {
        client.postMessage(event.data);
      }
    });
  }
});

self.addEventListener('sync', (event) => {
  if (event.tag === OFFLINE_QUEUE_SYNC_TAG) {
    event.waitUntil((async () => {
      const result = await replayQueuedRequests();
      // Notify Flutter app that offline orders have been synced
      try {
        const clientList = await self.clients.matchAll({ type: 'window' });
        for (const client of clientList) {
          client.postMessage({
            type: 'OFFLINE_SYNC_COMPLETE',
            syncedCount: result || 0,
          });
        }
      } catch (_) {}

      // Show OS notification if no visible tab (user left the app)
      try {
        const visibleClients = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
        const hasVisible = visibleClients.some(c => c.visibilityState === 'visible');
        if (!hasVisible && self.registration.showNotification) {
          self.registration.showNotification('Order confirmed', {
            body: 'Your offline order has been submitted successfully.',
            icon: '/icons/Icon-192.png',
            badge: '/icons/Icon-maskable-192.png',
            tag: 'dinein-offline-sync',
          });
        }
      } catch (_) {}
    })());
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

  event.waitUntil(replayQueuedRequests());

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
    if (isQueueableApiRequest(request)) {
      const queued = await queueApiRequest(request.clone());
      if (queued) {
        await registerOfflineSync();
        return new Response(
          JSON.stringify({
            error: 'offline',
            recoverable: true,
            queued: true,
            message: 'Saved offline. It will retry automatically when connectivity returns.',
          }),
          {
            status: 202,
            statusText: 'Accepted',
            headers: {
              'Content-Type': 'application/json',
              'X-DineIn-Offline': '1',
              'X-DineIn-Queued': '1',
            },
          },
        );
      }
    }

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

function isQueueableApiRequest(request) {
  const queueHint = request.headers.get('X-DineIn-Offline-Queue');
  return typeof queueHint === 'string' && queueHint.trim().length > 0;
}

function isShellAsset(url) {
  return url.origin === self.location.origin && SHELL_ASSET_SET.has(url.pathname);
}

function isStaticAsset(url) {
  return url.origin === self.location.origin &&
    STATIC_PATTERNS.some((pattern) => pattern.test(url.pathname));
}

async function registerOfflineSync() {
  if (!self.registration || !self.registration.sync) {
    return;
  }

  try {
    await self.registration.sync.register(OFFLINE_QUEUE_SYNC_TAG);
  } catch (_) {
    // Best-effort only; fetch-driven replays still run on future requests.
  }
}

async function queueApiRequest(request) {
  try {
    const body = await request.text();
    const headers = {};
    for (const [key, value] of request.headers.entries()) {
      headers[key] = value;
    }
    headers['X-DineIn-Offline-Replay'] = '1';

    const db = await openOfflineQueueDb();
    const tx = db.transaction(OFFLINE_QUEUE_STORE, 'readwrite');
    const store = tx.objectStore(OFFLINE_QUEUE_STORE);
    const entry = {
      id: `${Date.now()}-${Math.random().toString(36).slice(2)}`,
      createdAt: Date.now(),
      url: request.url,
      method: request.method,
      headers,
      body,
    };
    store.put(entry);
    await transactionDone(tx);
    return true;
  } catch (_) {
    return false;
  }
}

async function replayQueuedRequests() {
  if (replayInFlight) {
    return replayInFlight;
  }

  replayInFlight = (async () => {
    let entries = [];
    try {
      entries = await getQueuedRequests();
    } catch (_) {
      return;
    }

    for (const entry of entries) {
      try {
        const response = await fetch(entry.url, {
          method: entry.method,
          headers: entry.headers,
          body: entry.body || undefined,
        });
        if (response && response.ok) {
          await deleteQueuedRequest(entry.id);
        }
      } catch (_) {
        break;
      }
    }
  })();

  try {
    await replayInFlight;
  } finally {
    replayInFlight = null;
  }
}

function openOfflineQueueDb() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(OFFLINE_QUEUE_DB, 1);
    request.onupgradeneeded = () => {
      const db = request.result;
      if (!db.objectStoreNames.contains(OFFLINE_QUEUE_STORE)) {
        db.createObjectStore(OFFLINE_QUEUE_STORE, { keyPath: 'id' });
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error || new Error('Could not open offline queue.'));
  });
}

async function getQueuedRequests() {
  const db = await openOfflineQueueDb();
  const tx = db.transaction(OFFLINE_QUEUE_STORE, 'readonly');
  const store = tx.objectStore(OFFLINE_QUEUE_STORE);
  const request = store.getAll();
  const result = await requestDone(request);
  await transactionDone(tx);
  return Array.isArray(result)
    ? result.sort((left, right) => left.createdAt - right.createdAt)
    : [];
}

async function deleteQueuedRequest(id) {
  const db = await openOfflineQueueDb();
  const tx = db.transaction(OFFLINE_QUEUE_STORE, 'readwrite');
  tx.objectStore(OFFLINE_QUEUE_STORE).delete(id);
  await transactionDone(tx);
}

function requestDone(request) {
  return new Promise((resolve, reject) => {
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error || new Error('IndexedDB request failed.'));
  });
}

function transactionDone(tx) {
  return new Promise((resolve, reject) => {
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error || new Error('IndexedDB transaction failed.'));
    tx.onabort = () => reject(tx.error || new Error('IndexedDB transaction aborted.'));
  });
}
