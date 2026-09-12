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
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  select p.id into v_lawyer_id
  from public.profiles p
  where p.auth_id = auth.uid()
    and p.role = 'lawyer'
    and p.status = 'active'
  limit 1;

  if v_lawyer_id is null then
    raise exception 'هذا الإجراء متاح للمحامي ذي الحساب الفعال فقط';
  end if;

  if coalesce(array_length(p_requested_specializations, 1), 0) = 0 then
    raise exception 'اختر تخصصاً واحداً على الأقل';
  end if;

  if exists (
    select 1 from public.specialization_change_requests
    where lawyer_id = v_lawyer_id and status = 'pending'
  ) then
    raise exception 'لديك طلب تغيير تخصص قيد المراجعة بالفعل';
  end if;

  if nullif(trim(coalesce(p_union_id_card_url, '')), '') is null then
    raise exception 'هوية النقابة مطلوبة لمراجعة تغيير التخصص';
  end if;

  insert into public.specialization_change_requests(
    lawyer_id, requested_specializations, union_id_card_url, status
  ) values (
    v_lawyer_id, p_requested_specializations, trim(p_union_id_card_url), 'pending'
  ) returning id into v_request_id;

  return v_request_id;
end;
$$;

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
  if coalesce(array_length(v_request.requested_specializations, 1), 0) = 0 then
    raise exception 'الطلب لا يحتوي تخصصات صالحة';
  end if;

  if p_approved then
    if nullif(trim(coalesce(v_request.union_id_card_url, '')), '') is null then
      raise exception 'لا يمكن اعتماد تغيير التخصص بدون هوية نقابة';
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
    update public.lawyer_profiles
    set specialization = v_request.requested_specializations,
        updated_at = now()
    where profile_id = v_request.lawyer_id;
  end if;

  perform public.enqueue_user_notification(
    v_request.lawyer_id,
    case when p_approved then 'تمت الموافقة على تغيير التخصص' else 'تم رفض تغيير التخصص' end,
    case when p_approved then
      'تم اعتماد التخصصات الجديدة بعد مراجعة هوية النقابة.'
    else
      'تم رفض طلب تغيير التخصص: ' || v_note
    end,
    case when p_approved then 'specialization_change_approved' else 'specialization_change_rejected' end,
    v_request.id,
    'specialization_change_request'
  );

  return v_request;
end;
$$;

create or replace function public.notify_specialization_request_events()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  admin_id uuid;
begin
  if tg_op = 'INSERT' then
    for admin_id in select id from public.profiles where role = 'admin' and status = 'active' loop
      perform public.enqueue_user_notification(
        admin_id,
        'طلب تغيير تخصص جديد',
        'وصل طلب تغيير تخصص من محامٍ ويحتاج إلى مراجعة الإدارة.',
        'specialization_change_admin_review',
        new.id,
        'specialization_change_request'
      );
    end loop;
  end if;
  return new;
end;
$$;

revoke all on function public.request_specialization_change(text[],text) from public, anon;
grant execute on function public.request_specialization_change(text[],text) to authenticated;
revoke all on function public.review_specialization_change(uuid,boolean,text) from public, anon;
grant execute on function public.review_specialization_change(uuid,boolean,text) to authenticated;
revoke all on function public.notify_specialization_request_events() from public, anon, authenticated;

revoke insert, update, delete on table public.specialization_change_requests from authenticated, anon;
