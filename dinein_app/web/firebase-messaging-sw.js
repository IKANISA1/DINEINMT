importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyANrlSIDdY30yGkvmrmZaDYOoSCmWc7ZlM',
  appId: '1:1074154147498:web:40ff2d11ccfa7d2cdc4ad3',
  messagingSenderId: '1074154147498',
  projectId: 'gen-lang-client-0172279957',
  authDomain: 'gen-lang-client-0172279957.firebaseapp.com',
  storageBucket: 'gen-lang-client-0172279957.firebasestorage.app',
  measurementId: 'G-ZB65WBPLJ4',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notification = payload.notification || {};
  const data = payload.data || {};
  const title = notification.title || data.title || 'Venue alert';
  const body =
    notification.body ||
    data.body ||
    'Open DineIn to review the latest venue activity.';
  const route = resolveNotificationRoute(data);

  self.registration.showNotification(title, {
    body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-maskable-192.png',
    data: { route, eventType: data.event_type || null },
    tag: `dinein-${data.event_type || 'venue-alert'}`,
    requireInteraction: true,
  });
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const route = event.notification.data && event.notification.data.route
    ? event.notification.data.route
    : '/venue/orders';
  const targetUrl = new URL(route, self.location.origin).toString();

  event.waitUntil((async () => {
    const clientList = await self.clients.matchAll({
      type: 'window',
      includeUncontrolled: true,
    });

    for (const client of clientList) {
      if (!client.url.startsWith(self.location.origin)) {
        continue;
      }

      if ('navigate' in client) {
        await client.navigate(targetUrl);
      }

      if ('focus' in client) {
        await client.focus();
      }
      return;
    }

    await self.clients.openWindow(targetUrl);
  })());
});

function resolveNotificationRoute(data) {
  switch ((data.event_type || '').trim()) {
    case 'new_order':
      return '/venue/orders';
    case 'bell_request':
      return '/venue/waves';
    default:
      if (typeof data.route === 'string' && data.route.trim().length > 0) {
        return data.route.trim();
      }
      return '/venue/orders';
  }
}
