-- Consolidate overlapping SELECT policies without changing visibility semantics.

drop policy if exists availability_select_owner_admin on public.lawyer_availability_slots;
drop policy if exists availability_select_public on public.lawyer_availability_slots;

create policy availability_select_public
on public.lawyer_availability_slots
for select to anon
using (
  is_available
  and exists (
    select 1
    from public.get_public_lawyer(lawyer_availability_slots.lawyer_id)
  )
);

create policy availability_select_authenticated
on public.lawyer_availability_slots
for select to authenticated
using (
  (
    is_available
    and exists (
      select 1
      from public.get_public_lawyer(lawyer_availability_slots.lawyer_id)
    )
  )
  or lawyer_id in (
    select p.id from public.profiles p
    where p.auth_id = (select auth.uid())
  )
  or public.is_admin()
);
