drop function if exists public.create_booking(uuid, timestamp with time zone, text, text, text, text, text);

create or replace function public.create_booking(
  p_lawyer_id uuid,
  p_scheduled_at timestamp with time zone,
  p_package_name text,
  p_consultation_type text,
  p_description text default null,
  p_document_url text default null,
  p_client_whatsapp text default null,
  p_slot_id uuid default null
)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_user_id uuid;
  v_booking public.bookings;
  v_package jsonb;
  v_price numeric;
  v_duration integer := 30;
  v_description text;
  v_methods jsonb;
  v_slot_id uuid;
  v_slot_starts_at timestamptz;
  v_is_custom boolean := lower(trim(coalesce(p_package_name, ''))) = lower('استشارة مختلفة');
  v_consultation_type text := trim(coalesce(p_consultation_type, ''));
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  select id into v_user_id from public.profiles where auth_id = auth.uid() limit 1;
  if v_user_id is null then raise exception 'ملف المستخدم غير مكتمل'; end if;
  if not exists (select 1 from public.lawyer_profiles where profile_id = p_lawyer_id and verified = true and availability = true) then raise exception 'المحامي غير متاح للحجز حالياً'; end if;

  if p_slot_id is not null then
    select id, starts_at into v_slot_id, v_slot_starts_at from public.lawyer_availability_slots where id = p_slot_id and lawyer_id = p_lawyer_id and is_available = true for update;
  else
    select id, starts_at into v_slot_id, v_slot_starts_at from public.lawyer_availability_slots where lawyer_id = p_lawyer_id and starts_at between p_scheduled_at - interval '60 seconds' and p_scheduled_at + interval '60 seconds' and is_available = true order by abs(extract(epoch from (starts_at - p_scheduled_at))) limit 1 for update;
  end if;
  if v_slot_id is null then raise exception 'عذراً، هذا الموعد لم يعد متاحاً'; end if;
  if v_slot_starts_at <= now() then raise exception 'الموعد يجب أن يكون في المستقبل'; end if;
  if v_consultation_type = '' then raise exception 'يرجى تحديد نوع الاستشارة'; end if;

  if v_is_custom then
    select consultation_price into v_price from public.lawyer_profiles where profile_id = p_lawyer_id;
    if v_price is null or v_price <= 0 then raise exception 'سعر الاستشارة غير محدد لدى المحامي'; end if;
  else
    select elem into v_package from public.lawyer_profiles lp, lateral jsonb_array_elements(coalesce(lp.services, '[]'::jsonb)) elem where lp.profile_id = p_lawyer_id and lower(coalesce(elem->>'title', '')) = lower(trim(p_package_name)) limit 1;
    if v_package is null then raise exception 'الباقة المحددة غير متاحة'; end if;
    v_price := nullif(v_package->>'price', '')::numeric;
    v_duration := coalesce(nullif(v_package->>'duration_minutes', '')::integer, 30);
    v_description := v_package->>'description';
    v_methods := v_package->'consultation_types';
    if v_price is null or v_price <= 0 then raise exception 'سعر الباقة غير صالح'; end if;
    if v_consultation_type not in ('نصية', 'صوتية', 'فيديو') then raise exception 'طريقة الاستشارة غير صالحة'; end if;
    if jsonb_typeof(v_methods) = 'array' and not (v_methods ? v_consultation_type) then raise exception 'طريقة الاستشارة غير متاحة لهذه الباقة'; end if;
  end if;

  if exists (select 1 from public.bookings b where b.lawyer_id = p_lawyer_id and b.scheduled_at between v_slot_starts_at - interval '1 second' and v_slot_starts_at + interval '1 second' and b.status not in ('ملغي', 'مسترد')) then raise exception 'عذراً، هذا الموعد لم يعد متاحاً'; end if;

  insert into public.bookings (user_id, lawyer_id, status, scheduled_at, price, consultation_type, description, document_url, whatsapp_number, package_name, package_description, package_duration_minutes, consultation_status, lawyer_approved, lawyer_approved_at)
  values (v_user_id, p_lawyer_id, 'قيد انتظار الدفع', v_slot_starts_at, v_price, v_consultation_type, nullif(trim(p_description), ''), p_document_url, nullif(trim(p_client_whatsapp), ''), case when v_is_custom then 'استشارة مختلفة' else trim(p_package_name) end, v_description, v_duration, 'لم تبدأ', false, null)
  returning * into v_booking;

  update public.lawyer_availability_slots set is_available = false where id = v_slot_id;
  return v_booking;
end;
$function$;

grant execute on function public.create_booking(uuid, timestamp with time zone, text, text, text, text, text, uuid) to authenticated;
