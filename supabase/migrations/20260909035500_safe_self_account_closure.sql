create table if not exists public.closed_auth_accounts (
  auth_id uuid primary key,
  closed_at timestamptz not null default now()
);
alter table public.closed_auth_accounts enable row level security;
revoke all on public.closed_auth_accounts from public, anon, authenticated;

create or replace function public.protect_profile_sensitive_fields()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if current_setting('app.allow_account_closure', true) = '1' then return new; end if;
  if (select auth.uid()) is null then return new; end if;
  if tg_op='UPDATE' and old.auth_id=(select auth.uid()) and public.get_my_role() not in ('admin'::public.user_role,'moderator'::public.user_role) then
    if new.id is distinct from old.id or new.auth_id is distinct from old.auth_id or new.status is distinct from old.status or new.is_verified is distinct from old.is_verified or new.created_at is distinct from old.created_at or new.telegram_user_id is distinct from old.telegram_user_id then
      raise exception 'Sensitive profile fields can only be changed by an administrator';
    end if;
    if new.role is distinct from old.role then
      if not (old.role='user'::public.user_role and new.role='lawyer'::public.user_role and current_setting('app.allow_self_lawyer_registration',true)='1') then raise exception 'Profile role cannot be changed directly'; end if;
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.protect_lawyer_profile_sensitive_fields()
returns trigger language plpgsql security definer set search_path=public,pg_catalog as $$
declare v_owner boolean:=false;
begin
  if current_setting('app.allow_account_closure', true)='1' then return new; end if;
  if auth.uid() is null then return new; end if;
  select exists(select 1 from public.profiles p where p.id=old.profile_id and p.auth_id=auth.uid()) into v_owner;
  if v_owner and not public.is_admin() and public.get_my_role()<>'moderator'::public.user_role then
    if new.id is distinct from old.id or new.profile_id is distinct from old.profile_id or new.verified is distinct from old.verified or new.rating is distinct from old.rating or new.review_count is distinct from old.review_count or new.completed_consultations is distinct from old.completed_consultations or new.specialization is distinct from old.specialization or new.created_at is distinct from old.created_at or new.full_name is distinct from old.full_name then
      raise exception 'لا يمكن للمحامي تعديل حقول التوثيق أو التقييم أو التخصص مباشرة';
    end if;
  end if;
  return new;
end;
$$;

drop policy if exists profiles_insert_auth on public.profiles;
create policy profiles_insert_auth on public.profiles for insert to authenticated with check (
  auth.uid()=auth_id and role in ('user'::public.user_role,'lawyer'::public.user_role) and coalesce(is_verified,false)=false and status='active'::public.account_status and telegram_user_id is null and not exists(select 1 from public.closed_auth_accounts c where c.auth_id=auth.uid())
);

create or replace function public.close_my_account()
returns void language plpgsql security definer set search_path=public,auth,pg_catalog as $$
declare v_uid uuid:=auth.uid(); v_profile public.profiles%rowtype;
begin
  if v_uid is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  select * into v_profile from public.profiles where auth_id=v_uid for update;
  if not found then raise exception 'الحساب غير موجود'; end if;
  if exists(select 1 from public.bookings b where (b.user_id=v_profile.id or b.lawyer_id=v_profile.id) and b.status not in ('ملغي','مرفوض','مسترد','مكتمل')) then raise exception 'لا يمكن إغلاق الحساب قبل إنهاء أو إلغاء جميع الاستشارات النشطة'; end if;
  insert into public.closed_auth_accounts(auth_id) values(v_uid) on conflict(auth_id) do nothing;
  perform set_config('app.allow_account_closure','1',true);
  if v_profile.role='lawyer'::public.user_role then
    update public.lawyer_profiles set verified=false,availability=false,whatsapp=null,id_card_url=null,updated_at=now() where profile_id=v_profile.id;
  end if;
  update public.client_payout_accounts set account_number='REMOVED',account_holder_name='حساب محذوف',bank_name=null,updated_at=now() where user_id=v_profile.id;
  update public.profiles set auth_id=null,full_name='حساب محذوف',phone=null,email=null,avatar_url=null,city=null,is_verified=false,status='deleted'::public.account_status,onboarding_completed=false,wallet_number=null,whatsapp_number=null,telegram_user_id=null,wallet_type=null,wallet_holder_name=null,updated_at=now() where id=v_profile.id;
  delete from public.public_lawyer_directory where profile_id=v_profile.id;
  delete from public.lawyer_followers where follower_id=v_profile.id;
end;
$$;
revoke all on function public.close_my_account() from public,anon;
grant execute on function public.close_my_account() to authenticated;