# PWA single service worker fix — 2026-09-12

## Symptom
The client avatar could be correct in Supabase and visible on other screens while the client home page still behaved as if an older implementation was running. Similar stale/white rendering behavior had also been observed during tab navigation on iOS PWA.

## Verified root cause
Inspection of the actual deployed GitHub Pages artifact showed two service-worker registration paths on the same application scope:

1. Flutter's generated `flutter_bootstrap.js` registered `flutter_service_worker.js` through a `_flutter.loader.load({ ... })` invocation with `serviceWorkerSettings`.
2. `web/index.html` separately registered the app-owned `pwa_service_worker_v5.js` used for Web Push and PWA caching.

The app-owned worker also served critical Flutter runtime files such as `main.dart.js` cache-first and refreshed them only in the background. Therefore a newly deployed fix could still launch using an older JavaScript bundle on iOS PWA.

The client avatar data itself was verified as valid: the current `profiles.avatar_url` is a permanent public Supabase Storage URL and the corresponding JPEG object exists.

## Fix
- Added `web/flutter_bootstrap.js` that calls `_flutter.loader.load()` without a Flutter service-worker configuration.
- The application now owns one service worker: `pwa_service_worker_v5.js`.
- Bumped the custom PWA cache from `astshara-pwa-v15` to `astshara-pwa-v16`.
- Changed critical Flutter runtime assets (`flutter_bootstrap.js`, `main.dart.js`, `flutter.js`) to network-first with cache used only as an offline fallback.
- Bumped the service-worker registration URL to `pwa_service_worker_v5.js?v=16`.
- The GitHub Pages build now uses `--pwa-strategy=none`.
- CI verifies that the built bootstrap uses `_flutter.loader.load();` and rejects a `_flutter.loader.load({ ... })` invocation that would configure/register Flutter's second service worker. The Flutter loader implementation itself may still contain the `serviceWorkerSettings` symbol internally; that alone is not a registration.
- CI also verifies the v16 worker before deployment.

## Avatar-specific safeguards already present
- The client home screen reads the current avatar URL directly from `profiles.avatar_url` and falls back to the auth-state value only when needed.
- The home avatar uses `ValueKey(avatarUrl)` so a changed URL remounts the image widget.
- `SafeNetworkAvatar` provides an explicit fallback if image loading fails.

## Scope
No booking, payment, wallet, authentication, Realtime, notification payload, or Supabase schema behavior was changed by this PWA fix. Web Push remains handled by the app-owned custom service worker.
