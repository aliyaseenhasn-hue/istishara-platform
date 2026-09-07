-- Canonicalize lawyer achievement ownership through lawyer_profiles -> profiles -> auth.users.

drop policy if exists "lawyer achievements owner insert" on public.lawyer_achievements;
drop policy if exists "lawyer achievements owner update" on public.lawyer_achievements;
drop policy if exists "lawyer achievements owner delete" on public.lawyer_achievements;

create policy "lawyer achievements owner insert"
on public.lawyer_achievements
for insert
to authenticated
with check (
  exists (
    select 1
    from public.lawyer_profiles lp
    join public.profiles p on p.id = lp.profile_id
    where lp.id = lawyer_achievements.lawyer_id
      and p.auth_id = (select auth.uid())
  )
);

create policy "lawyer achievements owner update"
on public.lawyer_achievements
for update
to authenticated
using (
  exists (
    select 1
    from public.lawyer_profiles lp
    join public.profiles p on p.id = lp.profile_id
    where lp.id = lawyer_achievements.lawyer_id
      and p.auth_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1
    from public.lawyer_profiles lp
    join public.profiles p on p.id = lp.profile_id
    where lp.id = lawyer_achievements.lawyer_id
      and p.auth_id = (select auth.uid())
  )
);

create policy "lawyer achievements owner delete"
on public.lawyer_achievements
for delete
to authenticated
using (
  exists (
    select 1
    from public.lawyer_profiles lp
    join public.profiles p on p.id = lp.profile_id
    where lp.id = lawyer_achievements.lawyer_id
      and p.auth_id = (select auth.uid())
  )
);
