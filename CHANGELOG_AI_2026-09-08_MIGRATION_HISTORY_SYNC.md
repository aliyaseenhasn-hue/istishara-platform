# Supabase Migration History Sync — 2026-09-08

## Change

- File: `supabase/migrations/20260908000154_final_production_identity_auth_chat_and_storage_hardening.sql`
- Reason: Supabase Production recorded the migration as version `20260908000154`, while the repository filename used `20260908003000`.
- Description: Renamed the existing migration without changing its SQL so GitHub and Supabase Migration History use the same version and name.
- Result: Production migration drift is removed; no database operation or data rewrite is required.
- Commit: Pending.
