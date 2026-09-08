# Client / Lawyer palette alignment — 2026-09-08

## Scope

Align the client home screen with the established lawyer dashboard visual palette without changing navigation, data loading, authentication, booking, payment, or notification behavior.

## Changes

- Client page background now uses `AppColors.background`, matching the lawyer dashboard.
- Client profile hero now uses the same deep-blue to blue gradient family used by the lawyer profile hero: `primaryDark`, `primary`, and `secondary`.
- Gold accent treatment is used for the client role badge and hero border, matching the lawyer dashboard accent language.
- Client consultation metric cards now use the lawyer dashboard semantic card colors (`tertiary` and `success`) with high-contrast white text.
- Client category and suggested-lawyer cards now use `AppColors.surface` with `AppColors.outlineVariant` borders.
- Primary actions, notification icon, labels, and supporting text now use the same `AppColors` tokens as the lawyer dashboard.

## Non-goals

- No layout redesign.
- No route changes.
- No Supabase, RLS, Auth, booking, payment, Telegram, Realtime, storage, or notification logic changes.
- No dependency upgrades.

## Validation

GitHub Actions for the resulting `main` commit must pass Flutter analyze, Flutter tests, and the production web build before the change is considered release-ready.
