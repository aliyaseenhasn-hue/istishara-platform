# iOS Web/PWA black avatar fix — 2026-09-11

## Symptom
On iPhone Web/PWA, a user profile image could render as a solid black circle after navigation/repaint even though the stored avatar URL was valid.

## Cause and scope
The affected UI used Flutter network image textures (`NetworkImage` / `CachedNetworkImageProvider`) inside CanvasKit-rendered widgets. Recent Flutter 3.47 web/iOS rendering issues can leave network-image/WebGL textures black or invalid after route/sliver transitions.

## Fix
Added `lib/shared/widgets/safe_network_avatar.dart`.

`SafeNetworkAvatar` keeps the regular Flutter network-image path on native Android/iOS and non-iOS web, but on iOS Web/PWA it uses `Image.network` with `WebHtmlElementStrategy.prefer`, avoiding the CanvasKit/WebGL texture path for avatar images. It also supplies an icon fallback when the URL is empty or fails to load.

Applied to:
- Client avatar on the client home page.
- Suggested lawyer avatars on the client home page.
- User avatar in the profile/settings hero.

The temporary one-shot patch workflow deleted itself after applying the code changes and is not part of the final repository state.

## Functional impact
No authentication, profile-storage, Supabase, upload, booking, payment, or notification logic was changed. Only avatar rendering was changed.

## Verification requirement
Run the normal repository CI on the final HEAD: generated source checks, Flutter analyze, Flutter tests, web release build, GitHub Pages deployment, and Android release workflow. On-device iPhone/PWA behavior still requires user confirmation after deployment.
