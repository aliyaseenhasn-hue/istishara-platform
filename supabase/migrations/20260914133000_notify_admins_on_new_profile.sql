-- Notify every active admin when a new non-admin profile is created.
-- The notification references the newly-created profile so the admin UI can
-- identify the account without changing authentication or profile ownership.

create or replace function public.notify_admins_on_new_profile()
returns trigger
language plpgsql
security definer
set search_path = 'public', 'pg_catalog'
as $$
declare
  v_role_label text;
  v_display_name text;
begin
  if new.role::text = 'admin' then
    return new;
  end if;

  v_role_label := case
    when new.role::text = 'lawyer' then 'محامٍ'
    else 'طالب استشارة'
  end;

  v_display_name := coalesce(nullif(btrim(new.full_name), ''), 'مستخدم جديد');

  insert into public.notifications (
    user_id,
    title,
    body,
    type,
    is_read,
    reference_id,
    reference_type,
    actor_profile_id
  )
  select
    admin_profile.id,
    'تسجيل مستخدم جديد',
    format('%s سجّل حساباً جديداً كـ %s.', v_display_name, v_role_label),
    'admin_new_user',
    false,
    new.id,
    'admin_user',
    new.id
  from public.profiles admin_profile
  where admin_profile.role::text = 'admin'
    and admin_profile.id <> new.id
    and coalesce(admin_profile.status, 'active') = 'active';

  return new;
end;
$$;

drop trigger if exists trg_notify_admins_on_new_profile on public.profiles;

create trigger trg_notify_admins_on_new_profile
after insert on public.profiles
for each row
execute function public.notify_admins_on_new_profile();

revoke all on function public.notify_admins_on_new_profile() from public, anon, authenticated;
