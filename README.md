# astshara

A new Flutter project.

For help getting started with Flutter development, view the online Flutter documentation.

## Production Audit — 2026-09-07

- Latest repository change: `7772f22aec1ed5659ce8f20c97cb8c612cce8a4b` — modernized the notifications page visual system with a vibrant navy/teal/gold gradient header, notification-type accents, elevated cards, and explicit high-contrast text colors.
- Notification behavior was preserved: loading/error/empty states, pull-to-refresh, mark-read, mark-all-read, and booking/chat/profile navigation remain in place.
- Text-over-background collisions were addressed by separating notification content onto white cards, using high-contrast `AppColors.textPrimary`/`textSecondary`, bounded title/body lines with ellipsis, and responsive `Expanded`/`Flexible` layout constraints.
- Status: `WARNING — NOT FULLY TESTED` pending GitHub CI and rendered-device verification.

### Security hardening — public database role privileges

- Production migration: `supabase/migrations/20260907030000_harden_public_role_privileges.sql`.
- Repository commit: `186105611415d11a896cb57e78c6234f92f9f72c`.
- Removed unnecessary `REFERENCES`, `TRIGGER`, and `TRUNCATE` privileges from both `anon` and `authenticated` on all `public` tables.
- Removed all direct `INSERT`, `UPDATE`, and `DELETE` privileges from `anon`; anonymous reads continue to use the existing public RLS/views/RPC paths.
- Production verification after the migration returned zero remaining `anon`/`authenticated` grants for `REFERENCES`, `TRIGGER`, or `TRUNCATE`, and zero anonymous `INSERT`/`UPDATE`/`DELETE` grants.
- No application-facing authenticated data privileges were removed; existing RLS policies remain the row-level authorization boundary.
- Status: `PASS — TESTED` for the database-grant verification query. Full application regression and CI for the new commit remain `WARNING — NOT FULLY TESTED` until an associated workflow/device result exists.

- Previous repository change: `0f7be7fcef9eda5d537d9ff00b01f1e83348ff63` — replaced the client-callable `get_profile_auth_id(uuid)` RLS helper with a boolean ownership helper and removed its `authenticated` EXECUTE grant.
- Root cause: `get_profile_auth_id(uuid)` returned raw `profiles.auth_id` values and was still executable by `authenticated`, even though it was primarily used internally by RLS policies.
- Fix: added `is_profile_owned_by_actor(uuid)` as a SECURITY DEFINER boolean helper, rewired all affected conversation/message/lawyer-profile/notification/specialization RLS policies to use the boolean ownership check, and revoked client execution of `get_profile_auth_id(uuid)`.
- Supabase production migration: `20260907023000_replace_profile_auth_id_rls_helper` applied successfully.
- Verification: payment and booking RPCs were re-inspected. `submit_payment` and `create_booking` are executable by `authenticated` but not `anon`; direct `bookings`/`payments` INSERT policies remain blocked and status/payment mutations remain RPC-controlled. The new helper is not executable by `anon`; the old raw-auth-id helper is no longer executable by `authenticated`.
- Remaining production security blockers: Supabase Auth leaked-password protection is still disabled; anonymous-sign-in configuration still requires explicit verification; Qi Card vendor replay/idempotency remains unproven without vendor test credentials; latest UI contrast commits still require CI/rendered-device verification.

## Production Audit — 2026-09-06

- Main-branch workflow `34043144047` was successful for an earlier commit; it is not evidence for the newer commits above. The latest commits currently have no associated workflow run returned by the GitHub integration, so they remain `WARNING — NOT FULLY TESTED` until CI evidence exists.
- Public database tables were checked: all exposed `public` tables currently have RLS enabled.
- Booking/payment authorization was rechecked after the booking hardening work. Direct payment INSERT remains blocked by RLS, while payment submission is performed through the guarded `submit_payment` RPC.
- Supabase security-advisor findings were reviewed. Remaining SECURITY DEFINER functions were classified; trusted trigger/internal functions have client EXECUTE revoked, while application RPCs retain explicit auth/ownership checks.
- `telegram_login_requests` intentionally has RLS enabled without direct table policies; the application accesses it through trusted security-definer functions. No Telegram flow was changed.
- Storage policies were reviewed for avatars, lawyer documents, lawyer achievements, and receipts. Ownership checks are present for writes; sensitive reads are restricted to owner or admin/moderator.
- Qi Card integration remains configuration-dependent; no production credentials or payment behavior were fabricated or changed.

## Latest Production Fix — Booking Actions

- Repository commit: `f24fb0e74c4e3dbf9c0a32ff4c5d7d3b409acd8a`
- Added guarded lawyer approval/rejection and cancellation-request actions plus eligible client cancellation, duplicate-submit protection, and provider invalidation after successful state changes.
- Database authorization was preserved; no public execute grants were added.
- Verification: production RPCs were inspected and `authenticated` execute grants verified while `anon` execute remained disabled. `review_booking` was exercised inside a transaction and rolled back successfully.

## Latest Production Fix — PWA Notification State

- Repository commit: `6163de41167b005a982603a01db558bae5a4299c`
- Aligned the web/non-web notification service API by adding `isEnabled()` to the stub and synchronizing settings state after enable/disable operations.
- Existing `pwa_push_subscriptions` RLS remains owner-scoped; no public access was added.
- GitHub Actions run `34036615327` completed successfully for that change.

## Latest Production Fix — Consultation Type Compatibility

- Migration: `supabase/migrations/20260906160000_normalize_video_consultation_type_for_booking.sql`
- Repository commit: `197e37f1acbedba7e075554dc0fbe9ee0e8702c2`
- Normalized the booking input `مرئية` to canonical `فيديو` while preserving compatibility with existing package configurations.
- Migration was applied successfully in production.

## Latest Security Hardening — Booking Archive/Restore RPCs

- Migration: `supabase/migrations/20260906162000_lock_down_booking_archive_restore_functions.sql`
- Revoked `anon`/`authenticated` EXECUTE and retained trusted `service_role` execution for archive/restore maintenance functions.
- Production verification showed `anon_exec=false`, `auth_exec=false`, `service_exec=true` for both functions.

## Production UI Contrast Hardening — 2026-09-06

- `e0303b040854b0d240aaa1b5c00c728ec4fcb7be`: corrected lawyer setup hero and primary submission button foreground contrast.
- `54e9ff533794d8deb5ee89cd832fe3b693cbb294`: corrected lawyer onboarding hero, verification indicators, step badges, camera action, success dialog action, and submission button contrast.
- Status: `WARNING — NOT FULLY TESTED` pending CI and rendered-device verification.

## Production UI Responsive Fix — Landing Login Action — 2026-09-06

- `09977f2308b8755b2a805d13a5d78c0eeadd376f`: reduced AppBar action padding/minimum sizing and tightened title spacing so `تسجيل الدخول` remains visible on narrow mobile layouts without changing its `/login` route.
- Status: `WARNING — NOT FULLY TESTED` pending CI and rendered-device verification.
