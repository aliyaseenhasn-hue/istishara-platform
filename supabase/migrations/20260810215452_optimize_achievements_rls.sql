drop policy if exists "lawyer achievements owner insert" on public.lawyer_achievements;
create policy "lawyer achievements owner insert" on public.lawyer_achievements for insert to authenticated with check (lawyer_id in (select lp.id from public.lawyer_profiles lp join public.profiles p on p.id=lp.profile_id where p.id=(select auth.uid())));
drop policy if exists "lawyer achievements owner update" on public.lawyer_achievements;
create policy "lawyer achievements owner update" on public.lawyer_achievements for update to authenticated using (lawyer_id in (select lp.id from public.lawyer_profiles lp join public.profiles p on p.id=lp.profile_id where p.id=(select auth.uid()))) with check (lawyer_id in (select lp.id from public.lawyer_profiles lp join public.profiles p on p.id=lp.profile_id where p.id=(select auth.uid())));
drop policy if exists "lawyer achievements owner delete" on public.lawyer_achievements;
create policy "lawyer achievements owner delete" on public.lawyer_achievements for delete to authenticated using (lawyer_id in (select lp.id from public.lawyer_profiles lp join public.profiles p on p.id=lp.profile_id where p.id=(select auth.uid())));
