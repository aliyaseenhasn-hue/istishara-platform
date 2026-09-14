# Admin full user profile — 2026-09-14

## Scope

The administration area now provides a complete operational profile for consultation requesters and lawyers without exposing authentication secrets.

## Admin user list

- Every user card in **إدارة المستخدمين** can be opened.
- The details view is shared by consultation requesters and lawyers.
- Existing account status controls remain available.

## Secure backend

`public.admin_get_user_detail(p_user_id uuid)` is the server-side source for the details page.

Security properties:

- `SECURITY DEFINER` with an explicit fixed `search_path`.
- Requires the signed-in profile to have the `admin` role.
- Execution is limited to authenticated users; anonymous execution is revoked.
- Passwords, sessions, OTP values, auth tokens, and other authentication secrets are not returned.

## Details shown to administration

### All users

- Name and account type.
- Account status and onboarding state.
- Phone, WhatsApp, email, and city when stored in the profile.
- Registration and last-update timestamps.
- Consultation activity summary.
- Recent consultations.
- Payment summary and recent payment records.
- Platform payout/refund wallet details required for financial operations.

### Lawyers

In addition to the common account data:

- Professional specialization information.
- Practice/license information available in the lawyer profile.
- Years of experience and consultation price.
- Verification state, availability, rating, and review count.
- Lawyer wallet balances and earnings summary.
- Recent payout requests.

## New-user notifications

New consultation-requester and lawyer profiles generate an administration notification with `reference_type = admin_user` and the new profile id as the reference.

When administration taps a **تسجيل مستخدم جديد** notification, the app now opens that exact user's full admin profile directly. If an older notification has no profile reference, it safely falls back to the general users page.

## Compatibility

- No booking, payment, authentication, RLS, or lawyer-public-directory architecture was rewritten.
- Existing notification read/delete/realtime behavior is preserved.
- Existing non-admin notification navigation is preserved.
