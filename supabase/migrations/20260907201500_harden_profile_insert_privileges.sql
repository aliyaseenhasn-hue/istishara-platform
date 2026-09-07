-- Harden profile identity and self-registration privileges without changing existing IDs.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  insert into public.profiles (auth_id, full_name, email, phone, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', 'مستخدم جديد'),
    new.email,
    new.phone,
    case
      when new.raw_user_meta_data->>'role' = 'lawyer' then 'lawyer'::public.user_role
      else 'user'::public.user_role
    end
  )
  on conflict (auth_id) do nothing;
  return new;
end;
$$;

revoke all on function public.handle_new_user() from public, anon, authenticated;

drop policy if exists profiles_insert_auth on public.profiles;
create policy profiles_insert_auth
on public.profiles
for insert
to authenticated
with check (
  (select auth.uid()) = auth_id
  and role in ('user'::public.user_role, 'lawyer'::public.user_role)
  and coalesce(is_verified, false) = false
  and status = 'active'::public.account_status
  and telegram_user_id is null
);

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
       or new.role is distinct from old.role
       or new.status is distinct from old.status
       or new.is_verified is distinct from old.is_verified
       or new.created_at is distinct from old.created_at
       or new.telegram_user_id is distinct from old.telegram_user_id then
      raise exception 'Sensitive profile fields can only be changed by an administrator';
    end if;
  end if;

  return new;
end;
$$;

revoke all on function public.protect_profile_sensitive_fields() from public, anon, authenticated;
