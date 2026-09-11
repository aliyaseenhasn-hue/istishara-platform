const CACHE_NAME = 'astshara-pwa-v15';
const APP_SHELL = [
  './',
  './index.html',
  './manifest.json',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => cache.addAll(APP_SHELL))
      .then(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(
      keys
        .filter((key) => key.startsWith('astshara-pwa-') && key !== CACHE_NAME)
        .map((key) => caches.delete(key)),
    )).then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) return;

  const isNavigation = event.request.mode === 'navigate' ||
      url.pathname.endsWith('/index.html');
  const isCriticalFlutterAsset =
      url.pathname.endsWith('/flutter_bootstrap.js') ||
      url.pathname.endsWith('/main.dart.js') ||
      url.pathname.endsWith('/flutter.js');

  if (isNavigation) {
    event.respondWith(
      fetch(event.request, { cache: 'no-store' })
        .then((response) => {
          if (response.ok) {
            const copy = response.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(event.request, copy));
          }
          return response;
        })
        .catch(() => caches.match(event.request).then((cached) => cached || caches.match('./'))),
    );
    return;
  }

  // Flutter's main JS is the largest startup payload. After the first load,
  // answer from the PWA cache immediately and refresh it in the background.
  // The refresh bypasses HTTP cache, so a newly deployed bundle is ready for
  // the next launch without blocking the current one on the network.
  if (isCriticalFlutterAsset) {
    const networkRefresh = fetch(event.request, { cache: 'no-store' })
      .then((response) => {
        if (response.ok) {
          const copy = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, copy));
        }
        return response;
      });

    event.waitUntil(networkRefresh.catch(() => undefined));
    event.respondWith(
      caches.match(event.request).then((cached) => {
        if (cached) return cached;
        return networkRefresh.catch(() => caches.match('./'));
      }),
    );
    return;
  }

  event.respondWith(
    fetch(event.request)
      .then((response) => {
        if (response.ok) {
          const copy = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, copy));
        }
        return response;
      })
      .catch(() => caches.match(event.request).then((cached) => cached || caches.match('./'))),
  );
});

self.addEventListener('push', (event) => {
  let data = {};
  try { data = event.data ? event.data.json() : {}; } catch (_) {}

  const title = data.title || 'استشارة';
  const options = {
    body: data.body || 'لديك إشعار جديد',
    icon: data.icon || './assets/assets/icons/app_icon_v2.png',
    badge: data.badge || './assets/assets/icons/app_icon_v2.png',
    dir: 'rtl',
    lang: 'ar',
    tag: data.tag || 'astshara-notification',
    renotify: true,
    silent: data.silent === true ? true : false,
    requireInteraction: Boolean(data.requireInteraction),
    timestamp: Date.now(),
    data: { url: data.url || './', notification_id: data.notification_id || null },
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const rawTarget = event.notification.data?.url || './';
  let target;
  try {
    target = new URL(rawTarget, self.registration.scope).href;
  } catch (_) {
    target = self.registration.scope;
  }

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if ('navigate' in client && 'focus' in client) {
          return client.navigate(target).then(() => client.focus());
        }
      }
      return clients.openWindow(target);
    }),
  );
});
