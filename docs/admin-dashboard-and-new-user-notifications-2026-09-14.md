# Admin dashboard and new-user notifications — 2026-09-14

## Scope

This change reorganizes the administration dashboard and adds an administration notification for each newly-created non-admin profile.

## Admin dashboard UI

`lib/features/admin/presentation/pages/admin_dashboard_page.dart`

- Reorganized administration actions into clear card groups:
  - Accounts and lawyers
  - Reviews and requests
  - Payments and finance
  - Notifications and monitoring
- Added a direct **Payment Management** card that opens `/admin/payments` so the platform receiving account and payment receipts are easy to reach.
- Added an administration notification bell with unread count.
- Added a dedicated administration notifications card.
- Kept the overview metrics and revenue card, with restrained gold accents consistent with the current brand palette.
- Added pull-to-refresh and realtime invalidation of notification counts.

## Admin notifications route

`lib/app/router.dart`

- Added `/admin/notifications` as an admin-only nested route using the existing `NotificationsPage`.
- This avoids the existing admin redirect that prevents an administrator from using the regular `/notifications` route.

## New-user notification

Migration:

`supabase/migrations/20260914133000_notify_admins_on_new_profile.sql`

Behavior:

- After a new non-admin row is inserted into `public.profiles`, every active admin profile receives a notification.
- Notification type: `admin_new_user`.
- Reference type: `admin_user`.
- The notification references the newly-created profile id.
- The notification body includes the display name when available and a user-facing role label.
- Admin profiles themselves are excluded from this registration alert.
- The trigger function is `SECURITY DEFINER`, uses an explicit search path, and execute privileges are revoked from `public`, `anon`, and `authenticated`.

The migration was applied successfully to the production Supabase project through the migration API.

## Notification navigation

`lib/features/profile/presentation/pages/notifications_page.dart`

- Pressing an `admin_new_user` / `admin_user` notification opens `/admin/users`.

## Non-goals

- No Auth role names were changed.
- No booking, payment, wallet, financial accounting, or lawyer verification logic was changed.
- Existing notification and Web Push infrastructure was retained.
