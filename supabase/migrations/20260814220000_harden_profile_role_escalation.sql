-- Prevent public signup/profile updates from granting privileged roles.
-- Admin accounts must be provisioned through a trusted backend/admin workflow.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  requested_role text;
  safe_role text;
begin
  requested_role := lower(coalesce(new.raw_user_meta_data->>'role', 'user'));

  -- Public registration may create only normal users or lawyers.
  -- Privileged roles are never accepted from client-controlled metadata.
  safe_role := case
    when requested_role in ('user', 'lawyer') then requested_role
    else 'user'
  end;

  insert into public.profiles (
    id,
    auth_id,
    full_name,
    phone,
    email,
    role,
    onboarding_completed
  )
  values (
    new.id,
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', 'مستخدم جديد'),
    new.phone,
    new.email,
    safe_role::user_role,
    false
  )
  on conflict (id) do update set
    email = excluded.email,
    phone = excluded.phone,
    full_name = coalesce(excluded.full_name, public.profiles.full_name),
    updated_at = now();

  return new;
end;
$$;

-- Keep self-service profile editing, but never allow a normal account to
-- promote itself to admin/moderator. A normal user may transition to lawyer
-- through the existing lawyer onboarding flow.
drop policy if exists "Self Manage" on public.profiles;
create policy "Self Manage"
on public.profiles
for all
to authenticated
using (
  (select auth.uid()) = id
  or (select auth.uid()) = auth_id
)
with check (
  get_my_role() = any(array['admin'::user_role, 'moderator'::user_role])
  or (
    ((select auth.uid()) = id or (select auth.uid()) = auth_id)
    and role in ('user'::user_role, 'lawyer'::user_role)
    and (
      role::text = get_my_role()::text
      or (get_my_role()::text = 'user' and role::text = 'lawyer')
    )
  )
);
