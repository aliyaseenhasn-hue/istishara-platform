const CACHE_NAME = 'astshara-pwa-v6';
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
      url.pathname.endsWith('/index.html') ||
      url.pathname.endsWith('/flutter_bootstrap.js');

  event.respondWith(
    fetch(event.request, isNavigation ? { cache: 'no-store' } : undefined)
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
    // Keep icon/badge relative to the deployed PWA scope. This is important
    // for GitHub Pages deployments under /istishara-platform/.
    icon: data.icon || './icons/Icon-192.png',
    badge: data.badge || './icons/Icon-192.png',
    dir: 'rtl',
    lang: 'ar',
    tag: data.tag || 'astshara-notification',
    renotify: true,
    // Allow the browser/OS to use its normal notification sound behavior.
    silent: false,
    requireInteraction: Boolean(data.requireInteraction),
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
