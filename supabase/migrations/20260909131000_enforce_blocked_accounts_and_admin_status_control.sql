create table if not exists public.account_status_audit (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  old_status public.account_status not null,
  new_status public.account_status not null,
  reason text,
  changed_by uuid not null references public.profiles(id),
  changed_at timestamptz not null default now()
);

alter table public.account_status_audit enable row level security;
drop policy if exists account_status_audit_read on public.account_status_audit;
create policy account_status_audit_read
on public.account_status_audit
for select
to authenticated
using (
  user_id in (select p.id from public.profiles p where p.auth_id = auth.uid())
  or public.is_admin()
);
revoke insert, update, delete on table public.account_status_audit from authenticated, anon;
revoke all on table public.account_status_audit from anon;
grant select on table public.account_status_audit to authenticated;

create or replace function public.admin_set_user_status(
  p_user_id uuid,
  p_new_status public.account_status,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_admin_id uuid;
  v_target public.profiles%rowtype;
  v_reason text;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'غير مصرح: هذه العملية للإدارة فقط';
  end if;

  perform public.require_active_actor();

  select id into v_admin_id from public.profiles where auth_id = auth.uid() limit 1;
  select * into v_target from public.profiles where id = p_user_id for update;
  if not found then raise exception 'المستخدم غير موجود'; end if;

  if v_target.id = v_admin_id then
    raise exception 'لا يمكن تغيير حالة حساب الإدارة الحالي من هذه الشاشة';
  end if;

  if v_target.role in ('admin'::public.user_role, 'moderator'::public.user_role) then
    raise exception 'حسابات الإدارة والمشرفين تتطلب إجراءً إدارياً منفصلاً';
  end if;

  if p_new_status not in ('active'::public.account_status, 'blocked'::public.account_status) then
    raise exception 'يمكن من هذه الشاشة التفعيل أو الإيقاف فقط';
  end if;

  if v_target.status = p_new_status then return; end if;

  v_reason := nullif(trim(coalesce(p_reason, '')), '');
  if p_new_status = 'blocked'::public.account_status and v_reason is null then
    raise exception 'سبب إيقاف الحساب إلزامي';
  end if;

  update public.profiles
  set status = p_new_status,
      updated_at = now()
  where id = p_user_id;

  insert into public.account_status_audit(user_id,old_status,new_status,reason,changed_by)
  values(v_target.id,v_target.status,p_new_status,v_reason,v_admin_id);

  perform public.enqueue_user_notification(
    v_target.id,
    case when p_new_status='blocked'::public.account_status then 'تم إيقاف حسابك' else 'تمت إعادة تفعيل حسابك' end,
    case when p_new_status='blocked'::public.account_status then
      'تم إيقاف الحساب مؤقتاً. السبب: ' || v_reason
    else
      'تمت إعادة تفعيل حسابك ويمكنك استخدام خدمات المنصة مجدداً.'
    end,
    'account_status_changed',
    v_target.id,
    'profile'
  );
end;
$$;
revoke all on function public.admin_set_user_status(uuid,public.account_status,text) from public, anon;
grant execute on function public.admin_set_user_status(uuid,public.account_status,text) to authenticated;

create or replace function public.guard_booking_target_lawyer_active()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if new.lawyer_id is null then raise exception 'المحامي غير محدد'; end if;
  if not exists (
    select 1
    from public.profiles p
    join public.lawyer_profiles lp on lp.profile_id=p.id
    where p.id=new.lawyer_id
      and p.status='active'::public.account_status
      and p.role='lawyer'::public.user_role
      and lp.verified=true
  ) then
    raise exception 'هذا المحامي غير متاح لاستقبال الحجوزات حالياً';
  end if;
  return new;
end;
$$;
revoke all on function public.guard_booking_target_lawyer_active() from public, anon, authenticated;
drop trigger if exists trg_guard_booking_target_lawyer_active on public.bookings;
create trigger trg_guard_booking_target_lawyer_active
before insert on public.bookings
for each row execute function public.guard_booking_target_lawyer_active();

create or replace function public.get_public_lawyers(p_limit integer default 20, p_offset integer default 0)
returns table(id uuid, profile_id uuid, full_name text, avatar_url text, bio text, specialization text[], years_experience integer, consultation_price numeric, rating numeric, review_count integer, verified boolean, availability boolean, services jsonb)
language sql
stable
set search_path = public
as $$
  select d.lawyer_profile_id, d.profile_id, d.full_name, d.avatar_url, d.bio,
         d.specialization, d.years_experience, d.consultation_price, d.rating,
         d.review_count, d.is_verified, d.availability, d.services
  from public.public_lawyer_directory d
  join public.profiles p on p.id=d.profile_id
  where d.is_verified is true
    and p.status='active'::public.account_status
    and p.role='lawyer'::public.user_role
  order by d.lawyer_profile_id
  limit least(greatest(coalesce(p_limit,20),1),100)
  offset greatest(coalesce(p_offset,0),0);
$$;

create or replace function public.get_public_lawyer(p_profile_id uuid)
returns table(id uuid, profile_id uuid, full_name text, avatar_url text, bio text, specialization text[], years_experience integer, consultation_price numeric, rating numeric, review_count integer, verified boolean, availability boolean, services jsonb)
language sql
stable
set search_path = public
as $$
  select d.lawyer_profile_id, d.profile_id, d.full_name, d.avatar_url, d.bio,
         d.specialization, d.years_experience, d.consultation_price, d.rating,
         d.review_count, d.is_verified, d.availability, d.services
  from public.public_lawyer_directory d
  join public.profiles p on p.id=d.profile_id
  where d.profile_id=p_profile_id
    and d.is_verified is true
    and p.status='active'::public.account_status
    and p.role='lawyer'::public.user_role;
$$;

drop policy if exists availability_select_auth on public.lawyer_availability_slots;
create policy availability_select_auth
on public.lawyer_availability_slots
for select
to anon, authenticated
using (
  (
    is_available=true
    and exists (
      select 1
      from public.profiles p
      join public.lawyer_profiles lp on lp.profile_id=p.id
      where p.id=lawyer_id
        and p.status='active'::public.account_status
        and lp.verified=true
    )
  )
  or lawyer_id in (select p.id from public.profiles p where p.auth_id=auth.uid())
  or public.is_admin()
);
