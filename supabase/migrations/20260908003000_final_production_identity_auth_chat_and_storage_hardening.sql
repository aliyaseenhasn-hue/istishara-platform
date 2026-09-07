-- Final production hardening for profile identity, Telegram signup,
-- lawyer self-registration, chat creation boundaries, and payment idempotency.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if new.email like 'telegram.%@login.astshara.app' then
    return new;
  end if;
  insert into public.profiles (auth_id, full_name, email, phone, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', 'مستخدم جديد'),
    new.email,
    new.phone,
    case when new.raw_user_meta_data->>'role' = 'lawyer' then 'lawyer'::public.user_role else 'user'::public.user_role end
  )
  on conflict (auth_id) do nothing;
  return new;
end;
$$;
revoke all on function public.handle_new_user() from public, anon, authenticated;

insert into public.profiles (auth_id, full_name, email, phone, role)
select u.id,
       coalesce(nullif(trim(u.raw_user_meta_data->>'full_name'), ''), 'مستخدم جديد'),
       u.email,
       u.phone,
       case when u.raw_user_meta_data->>'role' = 'lawyer' then 'lawyer'::public.user_role else 'user'::public.user_role end
from auth.users u
left join public.profiles p on p.auth_id = u.id
where p.id is null
on conflict (auth_id) do nothing;

create or replace function public.protect_profile_sensitive_fields()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if (select auth.uid()) is null then return new; end if;
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
      if not (old.role = 'user'::public.user_role and new.role = 'lawyer'::public.user_role and current_setting('app.allow_self_lawyer_registration', true) = '1') then
        raise exception 'Profile role cannot be changed directly';
      end if;
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.protect_profile_sensitive_fields() from public, anon, authenticated;

create or replace function public.register_self_as_lawyer()
returns uuid
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare v_profile_id uuid; v_role public.user_role;
begin
  if (select auth.uid()) is null then raise exception 'Authentication required'; end if;
  select p.id, p.role into v_profile_id, v_role from public.profiles p where p.auth_id = (select auth.uid()) for update;
  if v_profile_id is null then raise exception 'Profile not found'; end if;
  if v_role = 'lawyer'::public.user_role then return v_profile_id; end if;
  if v_role <> 'user'::public.user_role then raise exception 'Current role is not eligible for lawyer registration'; end if;
  perform set_config('app.allow_self_lawyer_registration', '1', true);
  update public.profiles set role = 'lawyer'::public.user_role, updated_at = now()
   where id = v_profile_id and auth_id = (select auth.uid()) and role = 'user'::public.user_role;
  return v_profile_id;
end;
$$;
revoke all on function public.register_self_as_lawyer() from public, anon;
grant execute on function public.register_self_as_lawyer() to authenticated;

create or replace function public.enforce_telegram_login_request_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare v_recent integer;
begin
  select count(*)::integer into v_recent
  from public.telegram_login_requests r
  where r.phone = new.phone and r.created_at >= now() - interval '10 minutes';
  if v_recent >= 5 then raise exception 'Too many Telegram login attempts. Try again later.'; end if;
  return new;
end;
$$;
revoke all on function public.enforce_telegram_login_request_rate_limit() from public, anon, authenticated;
drop trigger if exists telegram_login_requests_rate_limit on public.telegram_login_requests;
create trigger telegram_login_requests_rate_limit before insert on public.telegram_login_requests for each row execute function public.enforce_telegram_login_request_rate_limit();

drop policy if exists conversations_insert on public.conversations;

create unique index if not exists ux_payments_one_active_per_booking
  on public.payments (booking_id)
  where status in ('قيد معالجة الدفع', 'تم الدفع');
