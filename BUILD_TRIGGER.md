# CI trigger

This file intentionally triggers the repository CI/Android/PWA workflows after the latest verified changes.

## Production audit — 2026-09-06
- Applied `20260906173000_optimize_rls_auth_checks_and_remove_duplicate_indexes.sql` to production Supabase.
- Applied `20260906174500_consolidate_financial_select_rls_policies.sql` to production Supabase.
- The first migration removed confirmed duplicate indexes and optimized repeated `auth.uid()` evaluation in RLS policies.
- The second migration consolidated equivalent participant/admin SELECT policies for financial ledger and payment financials while preserving access rules.
- Supabase Performance Advisor was rechecked: the previous `auth_rls_initplan` and duplicate-index warnings are no longer present; remaining findings are INFO unused-index notices plus a small set of intentionally separate policy groups that require further semantic review before removal.

## Verification checkpoint — 2026-09-06
- Rechecked Security Advisor after the production performance hardening.
- Public lawyer-directory RPCs remain intentionally callable by `anon`/`authenticated`; participant/admin SECURITY DEFINER functions remain protected by in-function authorization and explicit grants.
- No destructive policy/index change was made solely to silence advisor INFO/WARN findings where doing so could alter application behavior.
- Android release verification is still a launch gate because the current release configuration uses temporary debug signing.

## Regression fix — 2026-09-07
- Latest client-home commit `5371c4214787a6bdc6f20300a20f94029acd84f9` introduced a Dart syntax regression in `lib/features/home/presentation/pages/home_page.dart` inside `_ConsultationActions`: both compact `Expanded/SizedBox/Button` expressions were missing a closing parenthesis.
- GitHub Actions confirmed the regression: Deploy to GitHub Pages run `1234` failed in both `analyze` and `build`; Android Release run `536` also failed on the same commit.
- Restored the known-good `home_page.dart` blob from commit `3b4cc7ce0b3774db8203767cf557a11a94b010cc` without reverting unrelated repository changes.
- Created corrective commit `9552ad12f64e743ba43a931c53670a6e8b3470a5` and moved `main` to it.
- New CI workflows were triggered from the corrective commit; PASS will only be claimed after all required stages complete successfully.
