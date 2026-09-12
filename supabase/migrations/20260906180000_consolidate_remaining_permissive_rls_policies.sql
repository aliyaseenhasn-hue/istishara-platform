-- Keep the public achievements read model but avoid duplicate identical SELECT policies.
drop policy if exists "lawyer achievements public select" on public.lawyer_achievements;

-- Merge the two legacy owner predicates for each write action without changing access.
drop policy if exists "lawyer achievements own delete" on public.lawyer_achievements;
drop policy if exists "lawyer achievements owner delete" on public.lawyer_achievements;
create policy "lawyer achievements owner delete" on public.lawyer_achievements
for delete to authenticated
using (
  lawyer_id = (select auth.uid())
  or exists (select 1 from public.profiles p where p.id = lawyer_id and p.auth_id = (select auth.uid()))
  or exists (
    select 1 from public.lawyer_profiles lp
    where lp.id = lawyer_id
      and (lp.profile_id = (select auth.uid()) or exists (select 1 from public.profiles p where p.id = lp.profile_id and p.auth_id = (select auth.uid())))
  )
);

drop policy if exists "lawyer achievements own insert" on public.lawyer_achievements;
drop policy if exists "lawyer achievements owner insert" on public.lawyer_achievements;
create policy "lawyer achievements owner insert" on public.lawyer_achievements
for insert to authenticated
with check (
  lawyer_id = (select auth.uid())
  or exists (select 1 from public.profiles p where p.id = lawyer_id and p.auth_id = (select auth.uid()))
  or exists (
    select 1 from public.lawyer_profiles lp
    where lp.id = lawyer_id
      and (lp.profile_id = (select auth.uid()) or exists (select 1 from public.profiles p where p.id = lp.profile_id and p.auth_id = (select auth.uid())))
  )
);

drop policy if exists "lawyer achievements own update" on public.lawyer_achievements;
drop policy if exists "lawyer achievements owner update" on public.lawyer_achievements;
create policy "lawyer achievements owner update" on public.lawyer_achievements
for update to authenticated
using (
  lawyer_id = (select auth.uid())
  or exists (select 1 from public.profiles p where p.id = lawyer_id and p.auth_id = (select auth.uid()))
  or exists (
    select 1 from public.lawyer_profiles lp
    where lp.id = lawyer_id
      and (lp.profile_id = (select auth.uid()) or exists (select 1 from public.profiles p where p.id = lp.profile_id and p.auth_id = (select auth.uid())))
  )
)
with check (
  lawyer_id = (select auth.uid())
  or exists (select 1 from public.profiles p where p.id = lawyer_id and p.auth_id = (select auth.uid()))
  or exists (
    select 1 from public.lawyer_profiles lp
    where lp.id = lawyer_id
      and (lp.profile_id = (select auth.uid()) or exists (select 1 from public.profiles p where p.id = lp.profile_id and p.auth_id = (select auth.uid())))
  )
);

-- Replace admin ALL with explicit write policies so participant SELECT remains the only SELECT policy.
drop policy if exists "lawyer payout attempts admin all" on public.lawyer_payout_attempts;
create policy "lawyer payout attempts admin insert" on public.lawyer_payout_attempts for insert to authenticated with check (is_admin());
create policy "lawyer payout attempts admin update" on public.lawyer_payout_attempts for update to authenticated using (is_admin()) with check (is_admin());
create policy "lawyer payout attempts admin delete" on public.lawyer_payout_attempts for delete to authenticated using (is_admin());

drop policy if exists "lawyer penalties admin all" on public.lawyer_penalties;
create policy "lawyer penalties admin insert" on public.lawyer_penalties for insert to authenticated with check (is_admin());
create policy "lawyer penalties admin update" on public.lawyer_penalties for update to authenticated using (is_admin()) with check (is_admin());
create policy "lawyer penalties admin delete" on public.lawyer_penalties for delete to authenticated using (is_admin());

drop policy if exists "penalty settlements admin all" on public.lawyer_penalty_settlements;
create policy "penalty settlements admin insert" on public.lawyer_penalty_settlements for insert to authenticated with check (is_admin());
create policy "penalty settlements admin update" on public.lawyer_penalty_settlements for update to authenticated using (is_admin()) with check (is_admin());
create policy "penalty settlements admin delete" on public.lawyer_penalty_settlements for delete to authenticated using (is_admin());
