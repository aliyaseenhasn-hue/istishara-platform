-- Final production hardening for profile identity, lawyer self-registration,
-- orphan profile recovery, and chat creation boundaries.

-- Recover legitimate auth users that were created while profile creation failed.
-- profiles.id remains database-generated and independent from auth.users.id.
insert into public.profiles (auth_id, full_name, email, phone, role)
select
  u.id,
  coalesce(nullif(trim(u.raw_user_meta_data->>'full_name'), ''), 'مستخدم جديد'),
  u.email,
  u.phone,
  case
    when u.raw_user_meta_data->>'role' = 'lawyer' then 'lawyer'::public.user_role
    else 'user'::public.user_role
  end
from auth.users u
left join public.profiles p on p.auth_id = u.id
where p.id is null
on conflict (auth_id) do nothing;

-- Keep direct profile updates unable to alter security-sensitive identity fields.
-- The only self-service role transition allowed is user -> lawyer and only while
-- the guarded registration RPC sets a transaction-local marker.
create or replace function public.protect_profile_sensitive_fields()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if (select auth.uid()) is null then
    return new;
  end if;

  if tg_op = 'UPDATE'
     and old.auth_id = (select auth.uid())
     and public.get_my_role() not in ('admin'::public.user_role, 'moderator'::public.user_role) then
    if new.id is distinct from old.id
       or new.auth_id is distinct from old.auth_id
       or new.status is distinct from old.status
       or new.is_verified is distinct from old.is_verified
       or new.created_at is distinct from old.created_at
       or new.telegram_user_id is distinct from old.telegram_user_id then
      raise exception 'Sensitive profile fields can only be changed by an administrator';
    end if;

    if new.role is distinct from old.role then
      if not (
        old.role = 'user'::public.user_role
        and new.role = 'lawyer'::public.user_role
        and current_setting('app.allow_self_lawyer_registration', true) = '1'
      ) then
        raise exception 'Profile role cannot be changed directly';
      end if;
    end if;
  end if;

  return new;
end;
$$;

revoke all on function public.protect_profile_sensitive_fields() from public, anon, authenticated;

-- Explicit, one-way lawyer self-registration. It never accepts a profile UUID,
-- role, verification flag, or administrative state from the caller.
create or replace function public.register_self_as_lawyer()
returns uuid
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_profile_id uuid;
  v_role public.user_role;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required';
  end if;

  select p.id, p.role
    into v_profile_id, v_role
  from public.profiles p
  where p.auth_id = (select auth.uid())
  for update;

  if v_profile_id is null then
    raise exception 'Profile not found';
  end if;

  if v_role = 'lawyer'::public.user_role then
    return v_profile_id;
  end if;

  if v_role <> 'user'::public.user_role then
    raise exception 'Current role is not eligible for lawyer registration';
  end if;

  perform set_config('app.allow_self_lawyer_registration', '1', true);

  update public.profiles
  set role = 'lawyer'::public.user_role,
      updated_at = now()
  where id = v_profile_id
    and auth_id = (select auth.uid())
    and role = 'user'::public.user_role;

  return v_profile_id;
end;
$$;

revoke all on function public.register_self_as_lawyer() from public, anon;
grant execute on function public.register_self_as_lawyer() to authenticated;

-- Conversations are created by the booking lifecycle trigger after a legitimate
-- booking reaches the allowed state. Clients must not fabricate conversations by
-- supplying arbitrary participant UUIDs.
drop policy if exists conversations_insert on public.conversations;
