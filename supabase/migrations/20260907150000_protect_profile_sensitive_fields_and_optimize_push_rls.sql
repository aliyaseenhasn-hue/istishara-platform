-- Production hardening: protect identity/authorization fields and optimize push-token RLS.
-- Applied to the production Supabase project on 2026-09-07.

create or replace function public.protect_profile_sensitive_fields()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  -- service-role/backend operations do not have an auth.uid(); keep them able
  -- to perform trusted administrative/profile synchronization work.
  if (select auth.uid()) is null then
    return new;
  end if;

  -- A normal user may update their own editable profile fields, but may not
  -- self-escalate to admin/moderator, self-verify, change identity ownership,
  -- or alter the audit/Telegram identity fields.
  if old.auth_id = (select auth.uid())
     and public.get_my_role() not in ('admin'::public.user_role, 'moderator'::public.user_role)
  then
    if new.id is distinct from old.id
       or new.auth_id is distinct from old.auth_id
       or new.role is distinct from old.role
       or new.status is distinct from old.status
       or new.is_verified is distinct from old.is_verified
       or new.created_at is distinct from old.created_at
       or new.telegram_user_id is distinct from old.telegram_user_id
    then
      raise exception 'Sensitive profile fields can only be changed by an administrator';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists protect_profile_sensitive_fields on public.profiles;
create trigger protect_profile_sensitive_fields
before update on public.profiles
for each row execute function public.protect_profile_sensitive_fields();

-- Supabase Performance Advisor: evaluate auth.uid() once per statement rather
-- than once per row while preserving the existing ownership semantics.
drop policy if exists push_device_tokens_delete_own on public.push_device_tokens;
drop policy if exists push_device_tokens_insert_own on public.push_device_tokens;
drop policy if exists push_device_tokens_select_own on public.push_device_tokens;
drop policy if exists push_device_tokens_update_own on public.push_device_tokens;

create policy push_device_tokens_delete_own
on public.push_device_tokens
for delete to authenticated
using (
  user_id = (
    select p.id
    from public.profiles p
    where p.auth_id = (select auth.uid())
    limit 1
  )
);

create policy push_device_tokens_insert_own
on public.push_device_tokens
for insert to authenticated
with check (
  user_id = (
    select p.id
    from public.profiles p
    where p.auth_id = (select auth.uid())
    limit 1
  )
);

create policy push_device_tokens_select_own
on public.push_device_tokens
for select to authenticated
using (
  user_id = (
    select p.id
    from public.profiles p
    where p.auth_id = (select auth.uid())
    limit 1
  )
);

create policy push_device_tokens_update_own
on public.push_device_tokens
for update to authenticated
using (
  user_id = (
    select p.id
    from public.profiles p
    where p.auth_id = (select auth.uid())
    limit 1
  )
)
with check (
  user_id = (
    select p.id
    from public.profiles p
    where p.auth_id = (select auth.uid())
    limit 1
  )
);
