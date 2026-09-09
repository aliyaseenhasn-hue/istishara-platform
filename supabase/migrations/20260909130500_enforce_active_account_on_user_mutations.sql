create or replace function public.require_active_actor()
returns void
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_status public.account_status;
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  select p.status into v_status
  from public.profiles p
  where p.auth_id = auth.uid()
  limit 1;

  if v_status is null then
    raise exception 'ملف المستخدم غير موجود';
  end if;

  if v_status <> 'active'::public.account_status then
    raise exception 'الحساب غير فعال. لا يمكن تنفيذ هذا الإجراء حالياً';
  end if;
end;
$$;

revoke all on function public.require_active_actor() from public, anon;
grant execute on function public.require_active_actor() to authenticated;

create or replace function public.enforce_active_actor_on_mutation()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if auth.uid() is null then
    return coalesce(new, old);
  end if;

  perform public.require_active_actor();
  return coalesce(new, old);
end;
$$;

revoke all on function public.enforce_active_actor_on_mutation() from public, anon, authenticated;

do $$
declare
  t text;
begin
  foreach t in array array[
    'bookings',
    'payments',
    'cancellation_requests',
    'no_show_review_requests',
    'lawyer_payout_requests',
    'client_payout_accounts',
    'messages',
    'custom_consultation_requests',
    'reviews',
    'lawyer_followers',
    'specialization_change_requests',
    'lawyer_availability_slots'
  ] loop
    execute format('drop trigger if exists trg_require_active_actor on public.%I', t);
    execute format('create trigger trg_require_active_actor before insert or update or delete on public.%I for each row execute function public.enforce_active_actor_on_mutation()', t);
  end loop;
end $$;

create or replace function public.enforce_active_actor_on_profile_mutation()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if current_setting('app.allow_account_closure', true) = '1' then
    return coalesce(new, old);
  end if;
  if auth.uid() is null then
    return coalesce(new, old);
  end if;
  perform public.require_active_actor();
  return coalesce(new, old);
end;
$$;
revoke all on function public.enforce_active_actor_on_profile_mutation() from public, anon, authenticated;

drop trigger if exists trg_require_active_actor_profile on public.profiles;
create trigger trg_require_active_actor_profile
before update or delete on public.profiles
for each row execute function public.enforce_active_actor_on_profile_mutation();

drop trigger if exists trg_require_active_actor_lawyer_profile on public.lawyer_profiles;
create trigger trg_require_active_actor_lawyer_profile
before insert or update or delete on public.lawyer_profiles
for each row execute function public.enforce_active_actor_on_profile_mutation();
