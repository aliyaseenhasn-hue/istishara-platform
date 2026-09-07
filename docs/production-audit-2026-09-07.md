# Production Audit — 2026-09-07

## Purpose
Document the current production-safety audit and prevent speculative UI changes from being treated as fixes.

## Verified fixes already present
- Booking archive/restore RPC execution is restricted to `service_role`.
- Payment data was checked for orphaned records; current audit found 10 payments associated with 10 distinct bookings.
- Client home and landing page UI refinements preserve existing routes and business/data flow.

## UI contrast audit
The audit identified explicit button foreground/background color declarations that require contextual review rather than blanket replacement. In particular, lawyer onboarding uses a gold secondary background with white foreground text. This is now treated as a contrast-review item, not automatically changed without rendered verification.

## Safety rule for subsequent changes
1. Inspect the complete widget/theme context before changing a color.
2. Prefer shared theme/AppColors fixes where appropriate instead of scattered overrides.
3. Do not change authentication, Telegram, notification routing, booking, payment, or data-flow logic as part of a visual fix.
4. Do not declare PASS until CI and rendered-device verification succeed.

## Current status
`WARNING — NOT FULLY TESTED`

This document is intentionally limited to verified observations and does not claim that unverified UI issues are fixed.
