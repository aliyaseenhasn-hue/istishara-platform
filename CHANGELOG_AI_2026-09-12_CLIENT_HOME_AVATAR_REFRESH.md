# Client home avatar refresh fix — 2026-09-12

## Symptom
The client's profile photo could appear correctly elsewhere but fail to appear on the cached client home page.

## Cause
The client home page primarily used the `AppUser.avatarUrl` value from the restored authentication state. Because the home tab remains mounted, that value could remain stale after an avatar URL was migrated or updated.

## Fix
- Added `clientHomeAvatarUrlProvider` to read the current `profiles.avatar_url` directly for the signed-in client.
- The home page prefers that live profile URL and falls back to the cached auth-state URL only when necessary.
- Added a `ValueKey(avatarUrl)` to the client home `SafeNetworkAvatar` so a changed URL remounts the image widget and clears a failed/stale image state.

## Scope
No booking, payment, authentication, database schema, or notification behavior was changed. This is limited to resolving the client home avatar URL and refreshing its image widget.
