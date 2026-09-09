-- Specialization management policy:
-- - Primary specialization changes require admin review + union ID document.
-- - Up to two additional practice areas can be changed directly once every 30 days.
-- - Every effective specialization change is kept in an internal audit history.
-- - Direct table updates cannot bypass these rules.

create table if not exists public.lawyer_specialization_history (
  id uuid primary key default gen_random_uuid(),
  lawyer_id uuid not null references public.profiles(id) on delete cascade,
  change_type text not null check (change_type in ('primary_approved', 'additional_direct')),
  old_specializations text[] not null default '{}'::text[],
  new_specializations text[] not null default '{}'::text[],
  changed_by uuid references public.profiles(id) on delete set null,
  source_request_id uuid references public.specialization_change_requests(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists lawyer_specialization_history_lawyer_created_idx
  on public.lawyer_specialization_history(lawyer_id, created_at desc);
create index if not exists lawyer_specialization_history_additional_idx
  on public.lawyer_specialization_history(lawyer_id, created_at desc)
  where change_type = 'additional_direct';

alter table public.lawyer_specialization_history enable row level security;
revoke all on table public.lawyer_specialization_history from anon, authenticated;
grant select on table public.lawyer_specialization_history to authenticated;

drop policy if exists lawyer_specialization_history_admin_select on public.lawyer_specialization_history;
create policy lawyer_specialization_history_admin_select
on public.lawyer_specialization_history
for select
to authenticated
using (public.is_admin());

create or replace function public.is_allowed_lawyer_specialization(p_value text)
returns boolean
language sql
immutable
set search_path = public
as $$
  select trim(coalesce(p_value, '')) = any(array[
    'إداري','قوى الأمن الداخلي','شركات','تسجيل عقاري','معاملات مؤسسة الشهداء',
    'أحوال شخصية','مدني','جنائي','تجاري','عمالي','ضمان اجتماعي','مروري',
    'عقود واتفاقيات','صياغة العقود','تحصيل الديون','تنفيذ الأحكام','دعاوى التعويض',
    'ملكية فكرية','علامات تجارية','ضرائب','كمارك','استثمار','مصارف وتمويل',
    'منازعات عقارية','إيجارات','مقاولات','مناقصات حكومية','قضايا الأسرة والطفولة',
    'إرث ووصايا','نفقة وحضانة','زواج وطلاق','قضايا المخدرات','قضايا إلكترونية',
    'قضايا عسكرية','قضايا دولية','إقامة وجنسية','تأسيس الشركات','تصفية الشركات',
    'الوكالات التجارية','تسجيل العلامات والبراءات','منازعات العمل','التأمين','الوساطة والتحكيم'
  ]::text[]);
$$;

revoke all on function public.is_allowed_lawyer_specialization(text) from public, anon, authenticated;

create or replace function public.validate_lawyer_specializations()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_count integer;
  v_distinct_count integer;
begin
  if new.specialization is null then return new; end if;

  v_count := coalesce(cardinality(new.specialization), 0);
  if v_count < 1 or v_count > 3 then
    raise exception 'يجب اختيار تخصص رئيسي واحد ويمكن إضافة تخصصين فقط';
  end if;

  select count(distinct trim(x)) into v_distinct_count
  from unnest(new.specialization) as u(x)
  where nullif(trim(x), '') is not null;

  if v_distinct_count <> v_count then
    raise exception 'لا يمكن تكرار التخصص نفسه';
  end if;

  if exists (
    select 1 from unnest(new.specialization) as u(x)
    where not public.is_allowed_lawyer_specialization(x)
  ) then
    raise exception 'أحد التخصصات المختارة غير معتمد في المنصة';
  end if;

  return new;
end;
$$;

create or replace function public.enforce_specialization_change_channel()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_mode text := coalesce(current_setting('app.specialization_change_mode', true), '');
begin
  if new.specialization is not distinct from old.specialization then
    return new;
  end if;

  -- Trusted SQL/service operations have no authenticated end-user context.
  if auth.uid() is null then
    return new;
  end if;

  if v_mode not in ('additional_direct', 'primary_review') then
    raise exception 'يجب تغيير التخصص الرئيسي عبر مراجعة الإدارة، والتخصصات الإضافية عبر صفحة إدارة التخصصات';
  end if;

  return new;
end;
$$;

revoke all on function public.enforce_specialization_change_channel() from public, anon, authenticated;

drop trigger if exists trg_enforce_specialization_change_channel on public.lawyer_profiles;
create trigger trg_enforce_specialization_change_channel
before update of specialization on public.lawyer_profiles
for each row execute function public.enforce_specialization_change_channel();

create or replace function public.get_specialization_management_status()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_catalog
as $$
declare
  v_lawyer_id uuid;
  v_specs text[];
  v_last_additional timestamptz;
  v_next_additional timestamptz;
  v_pending_primary text;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;

  select p.id into v_lawyer_id
  from public.profiles p
  where p.auth_id = auth.uid()
    and p.role = 'lawyer'
    and p.status = 'active'
  limit 1;

  if v_lawyer_id is null then
    raise exception 'هذا الإجراء متاح للمحامي ذي الحساب الفعال فقط';
  end if;

  select coalesce(lp.specialization, '{}'::text[])
    into v_specs
  from public.lawyer_profiles lp
  where lp.profile_id = v_lawyer_id;

  if v_specs is null then v_specs := '{}'::text[]; end if;

  select max(h.created_at)
    into v_last_additional
  from public.lawyer_specialization_history h
  where h.lawyer_id = v_lawyer_id
    and h.change_type = 'additional_direct';

  if v_last_additional is not null then
    v_next_additional := v_last_additional + interval '30 days';
  end if;

  select r.requested_specializations[1]
    into v_pending_primary
  from public.specialization_change_requests r
  where r.lawyer_id = v_lawyer_id
    and r.status = 'pending'
  order by r.created_at desc
  limit 1;

  return jsonb_build_object(
    'primary_specialization', v_specs[1],
    'additional_specializations', to_jsonb(coalesce(v_specs[2:3], '{}'::text[])),
    'last_additional_change_at', v_last_additional,
    'next_additional_change_at', v_next_additional,
    'can_change_additional', v_last_additional is null or now() >= v_next_additional,
    'cooldown_days', 30,
    'pending_primary_specialization', v_pending_primary
  );
end;
$$;

revoke all on function public.get_specialization_management_status() from public, anon;
grant execute on function public.get_specialization_management_status() to authenticated;

create or replace function public.update_additional_specializations(p_additional_specializations text[])
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_lawyer_id uuid;
  v_old_specs text[];
  v_primary text;
  v_additional text[];
  v_new_specs text[];
  v_count integer;
  v_distinct_count integer;
  v_last_change timestamptz;
  v_next_change timestamptz;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;

  select p.id into v_lawyer_id
  from public.profiles p
  where p.auth_id = auth.uid()
    and p.role = 'lawyer'
    and p.status = 'active'
  limit 1;

  if v_lawyer_id is null then
    raise exception 'هذا الإجراء متاح للمحامي ذي الحساب الفعال فقط';
  end if;

  select coalesce(lp.specialization, '{}'::text[])
    into v_old_specs
  from public.lawyer_profiles lp
  where lp.profile_id = v_lawyer_id
  for update;

  if not found then raise exception 'الملف المهني غير موجود'; end if;

  v_primary := v_old_specs[1];
  if nullif(trim(coalesce(v_primary, '')), '') is null then
    raise exception 'يجب اعتماد تخصص رئيسي أولاً';
  end if;

  select coalesce(array_agg(trim(x) order by ord), '{}'::text[])
    into v_additional
  from unnest(coalesce(p_additional_specializations, '{}'::text[])) with ordinality as u(x, ord)
  where nullif(trim(x), '') is not null;

  v_count := cardinality(v_additional);
  if v_count > 2 then
    raise exception 'يمكن اختيار تخصصين إضافيين كحد أقصى';
  end if;

  if array_position(v_additional, v_primary) is not null then
    raise exception 'لا يمكن اختيار التخصص الرئيسي كتخصص إضافي';
  end if;

  select count(distinct x) into v_distinct_count from unnest(v_additional) as u(x);
  if v_distinct_count <> v_count then
    raise exception 'لا يمكن تكرار التخصص نفسه';
  end if;

  if exists (
    select 1 from unnest(v_additional) as u(x)
    where not public.is_allowed_lawyer_specialization(x)
  ) then
    raise exception 'أحد التخصصات الإضافية غير معتمد في المنصة';
  end if;

  v_new_specs := array[v_primary] || v_additional;
  if v_new_specs = v_old_specs then
    return jsonb_build_object(
      'specializations', to_jsonb(v_old_specs),
      'changed', false,
      'next_additional_change_at', null
    );
  end if;

  select max(h.created_at)
    into v_last_change
  from public.lawyer_specialization_history h
  where h.lawyer_id = v_lawyer_id
    and h.change_type = 'additional_direct';

  if v_last_change is not null and now() < v_last_change + interval '30 days' then
    v_next_change := v_last_change + interval '30 days';
    raise exception 'يمكن تغيير مجالات الممارسة الإضافية مرة كل 30 يوماً. التغيير التالي متاح بتاريخ %',
      to_char(v_next_change at time zone 'Asia/Baghdad', 'YYYY-MM-DD');
  end if;

  perform set_config('app.specialization_change_mode', 'additional_direct', true);

  update public.lawyer_profiles
  set specialization = v_new_specs,
      updated_at = now()
  where profile_id = v_lawyer_id;

  insert into public.lawyer_specialization_history(
    lawyer_id, change_type, old_specializations, new_specializations, changed_by
  ) values (
    v_lawyer_id, 'additional_direct', v_old_specs, v_new_specs, v_lawyer_id
  );

  v_next_change := now() + interval '30 days';

  return jsonb_build_object(
    'specializations', to_jsonb(v_new_specs),
    'changed', true,
    'next_additional_change_at', v_next_change
  );
end;
$$;

revoke all on function public.update_additional_specializations(text[]) from public, anon;
grant execute on function public.update_additional_specializations(text[]) to authenticated;

-- Keep the existing RPC signature for older clients, but only the first item is
-- treated as the requested PRIMARY specialization. Additional areas are never
-- changed through the admin-review request.
create or replace function public.request_specialization_change(
  p_requested_specializations text[],
  p_union_id_card_url text
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_lawyer_id uuid;
  v_request_id uuid;
  v_primary text;
  v_current_primary text;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;

  select p.id into v_lawyer_id
  from public.profiles p
  where p.auth_id = auth.uid()
    and p.role = 'lawyer'
    and p.status = 'active'
  limit 1;

  if v_lawyer_id is null then
    raise exception 'هذا الإجراء متاح للمحامي ذي الحساب الفعال فقط';
  end if;

  v_primary := nullif(trim(coalesce(p_requested_specializations[1], '')), '');
  if v_primary is null then raise exception 'اختر التخصص الرئيسي المطلوب'; end if;
  if not public.is_allowed_lawyer_specialization(v_primary) then
    raise exception 'التخصص الرئيسي المختار غير معتمد في المنصة';
  end if;

  select lp.specialization[1]
    into v_current_primary
  from public.lawyer_profiles lp
  where lp.profile_id = v_lawyer_id;

  if v_current_primary = v_primary then
    raise exception 'هذا هو تخصصك الرئيسي الحالي بالفعل';
  end if;

  if exists (
    select 1 from public.specialization_change_requests
    where lawyer_id = v_lawyer_id and status = 'pending'
  ) then
    raise exception 'لديك طلب تغيير تخصص رئيسي قيد المراجعة بالفعل';
  end if;

  if nullif(trim(coalesce(p_union_id_card_url, '')), '') is null then
    raise exception 'هوية النقابة مطلوبة لمراجعة تغيير التخصص الرئيسي';
  end if;

  insert into public.specialization_change_requests(
    lawyer_id, requested_specializations, union_id_card_url, status
  ) values (
    v_lawyer_id, array[v_primary], trim(p_union_id_card_url), 'pending'
  ) returning id into v_request_id;

  return v_request_id;
end;
$$;

revoke all on function public.request_specialization_change(text[],text) from public, anon;
grant execute on function public.request_specialization_change(text[],text) to authenticated;

create or replace function public.review_specialization_change(
  p_request_id uuid,
  p_approved boolean,
  p_note text default null
)
returns public.specialization_change_requests
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_actor uuid := auth.uid();
  v_profile_id uuid;
  v_request public.specialization_change_requests;
  v_note text;
  v_old_specs text[];
  v_new_specs text[];
  v_new_primary text;
  v_additional text[];
begin
  if v_actor is null or not public.is_admin() then
    raise exception 'غير مصرح';
  end if;

  select id into v_profile_id
  from public.profiles
  where auth_id = v_actor
  limit 1;

  select * into v_request
  from public.specialization_change_requests
  where id = p_request_id
  for update;

  if not found then raise exception 'الطلب غير موجود'; end if;
  if v_request.status <> 'pending' then raise exception 'تمت مراجعة الطلب مسبقاً'; end if;

  v_new_primary := nullif(trim(coalesce(v_request.requested_specializations[1], '')), '');
  if v_new_primary is null or not public.is_allowed_lawyer_specialization(v_new_primary) then
    raise exception 'الطلب لا يحتوي تخصصاً رئيسياً صالحاً';
  end if;

  if p_approved then
    if nullif(trim(coalesce(v_request.union_id_card_url, '')), '') is null then
      raise exception 'لا يمكن اعتماد تغيير التخصص الرئيسي بدون هوية نقابة';
    end if;
    v_note := nullif(trim(coalesce(p_note, '')), '');
  else
    v_note := nullif(trim(coalesce(p_note, '')), '');
    if v_note is null then
      raise exception 'سبب رفض طلب تغيير التخصص إلزامي';
    end if;
  end if;

  update public.specialization_change_requests
  set status = case when p_approved then 'approved' else 'rejected' end,
      reviewed_at = now(),
      reviewed_by = v_profile_id,
      review_note = v_note
  where id = p_request_id
  returning * into v_request;

  if p_approved then
    select coalesce(lp.specialization, '{}'::text[])
      into v_old_specs
    from public.lawyer_profiles lp
    where lp.profile_id = v_request.lawyer_id
    for update;

    if not found then raise exception 'الملف المهني للمحامي غير موجود'; end if;

    select coalesce(array_agg(x order by ord), '{}'::text[])
      into v_additional
    from unnest(coalesce(v_old_specs[2:3], '{}'::text[])) with ordinality as u(x, ord)
    where x <> v_new_primary;

    v_new_specs := array[v_new_primary] || v_additional[1:2];

    perform set_config('app.specialization_change_mode', 'primary_review', true);

    update public.lawyer_profiles
    set specialization = v_new_specs,
        updated_at = now()
    where profile_id = v_request.lawyer_id;

    insert into public.lawyer_specialization_history(
      lawyer_id, change_type, old_specializations, new_specializations, changed_by, source_request_id
    ) values (
      v_request.lawyer_id, 'primary_approved', v_old_specs, v_new_specs, v_profile_id, v_request.id
    );
  end if;

  perform public.enqueue_user_notification(
    v_request.lawyer_id,
    case when p_approved then 'تمت الموافقة على تغيير التخصص الرئيسي' else 'تم رفض تغيير التخصص الرئيسي' end,
    case when p_approved then
      'تم اعتماد تخصصك الرئيسي الجديد. مجالات الممارسة الإضافية الحالية بقيت كما هي ما لم تتعارض معه.'
    else
      'تم رفض طلب تغيير التخصص الرئيسي: ' || v_note
    end,
    case when p_approved then 'specialization_change_approved' else 'specialization_change_rejected' end,
    v_request.id,
    'specialization_change_request'
  );

  return v_request;
end;
$$;

revoke all on function public.review_specialization_change(uuid,boolean,text) from public, anon;
grant execute on function public.review_specialization_change(uuid,boolean,text) to authenticated;
