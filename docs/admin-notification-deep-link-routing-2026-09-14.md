# Admin notification target routing — 2026-09-14

## Goal
Make every actionable administration notification open the administration page responsible for that event instead of falling back to the dashboard or to client/lawyer pages.

## Routing rules
- New user (`admin_new_user` / `admin_user`) → the exact administrative user profile when a profile id is available; otherwise `/admin/users`.
- Manual payment review and payment administration notifications → `/admin/payments`.
- Wallet top-up review / overdue top-up → `/admin/payments`.
- Client wallet withdrawal, client credit, lawyer payout, and lawyer penalty administration notifications → `/admin/financial`.
- Cancellation review notifications → `/admin/cancellation-requests`.
- No-show review notifications → `/admin/no-show-reviews`.
- Specialization change review notifications → `/admin/specialization-change-requests`.
- Lawyer verification notifications → `/admin/lawyer-verifications`.
- Review moderation notifications → `/admin/reviews`.
- Unknown generic admin notifications fall back to `/admin` rather than attempting to open client/lawyer pages.

## Safety and compatibility
- Routing is role-aware: these administration mappings apply only when the signed-in profile role is `admin`.
- Existing client and lawyer notification routing remains in place.
- No database schema, RLS policy, payment logic, booking state machine, or notification generation logic was changed.
