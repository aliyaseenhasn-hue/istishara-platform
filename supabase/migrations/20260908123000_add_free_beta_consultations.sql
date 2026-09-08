-- Server-controlled complimentary beta consultations.
-- A waived booking never creates a payment, financial ledger entry, commission,
-- wallet credit, or payout entitlement.

create table if not exists public.app_release_settings (
  id boolean primary key default true check (id),
  release_channel text not null default 'beta' check (release_channel in ('beta', 'production')),
  free_beta_enabled boolean not null default true,
  payments_enabled boolean not null default false,
  beta_notice text not null default 'الاستشارات مجانية خلال الفترة التجريبية، ولن يتم تحصيل أي مبلغ.',
  updated_at timestamptz not null default now()
);

insert into public.app_release_settings (
  id,
  release_channel,
  free_beta_enabled,
  payments_enabled,
  beta_notice
)
values (
  true,
  'beta',
  true,
  false,
  'الاستشارات مجانية خلال الفترة التجريبية، ولن يتم تحصيل أي مبلغ.'
)
on conflict (id) do nothing;

alter table public.app_release_settings enable row level security;

drop policy if exists app_release_settings_public_read on public.app_release_settings;
create policy app_release_settings_public_read
on public.app_release_settings
for select
to anon, authenticated
using (id = true);

drop policy if exists app_release_settings_admin_update on public.app_release_settings;
create policy app_release_settings_admin_update
on public.app_release_settings
for update
to authenticated
using (
  exists (
    select 1
    from public.profiles
    where profiles.auth_id = (select auth.uid())
      and profiles.role = 'admin'::public.user_role
  )
)
with check (
  id = true
  and exists (
    select 1
    from public.profiles
    where profiles.auth_id = (select auth.uid())
      and profiles.role = 'admin'::public.user_role
  )
);

revoke all on table public.app_release_settings from public, anon, authenticated;
grant select on table public.app_release_settings to anon, authenticated;
grant update (release_channel, free_beta_enabled, payments_enabled, beta_notice, updated_at)
  on table public.app_release_settings to authenticated;

alter table public.bookings
  add column if not exists payment_required boolean not null default true,
  add column if not exists payment_waived_at timestamptz,
  add column if not exists payment_waiver_reason text;

alter table public.bookings
  drop constraint if exists bookings_payment_waiver_consistency;

alter table public.bookings
  add constraint bookings_payment_waiver_consistency check (
    (
      payment_required
      and payment_waived_at is null
      and payment_waiver_reason is null
    )
    or
    (
      not payment_required
      and payment_waived_at is not null
      and payment_waiver_reason = 'free_beta'
    )
  );

create or replace function public.create_booking(
  p_lawyer_id uuid,
  p_scheduled_at timestamptz,
  p_package_name text,
  p_consultation_type text,
  p_description text default null,
  p_document_url text default null,
  p_client_whatsapp text default null,
  p_slot_id uuid default null,
  p_consultation_mode text default 'عن بعد'
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
  v_consultation_type text := case
    when trim(coalesce(p_consultation_type, '')) = 'مرئية' then 'فيديو'
    else trim(coalesce(p_consultation_type, ''))
  end;
  v_mode text := trim(coalesce(p_consultation_mode, 'عن بعد'));
  v_whatsapp text;
  v_lawyer_whatsapp text;
  v_initial_status text;
  v_free_beta boolean;
  v_payments_enabled boolean;
  v_payment_required boolean;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;

  select free_beta_enabled, payments_enabled
  into v_free_beta, v_payments_enabled
  from public.app_release_settings
  where id = true;

  v_free_beta := coalesce(v_free_beta, false);
  v_payments_enabled := coalesce(v_payments_enabled, false);
  if not v_free_beta and not v_payments_enabled then
    raise exception 'إنشاء الحجوزات متوقف مؤقتاً حتى تفعيل وسيلة الدفع';
  end if;
  v_payment_required := not v_free_beta;

  select id, nullif(trim(whatsapp_number), '')
  into v_user_id, v_whatsapp
  from public.profiles
  where auth_id = auth.uid()
  limit 1;
  if v_user_id is null then raise exception 'ملف المستخدم غير مكتمل'; end if;
  if v_whatsapp is null then raise exception 'يجب إضافة رقم واتساب في الملف الشخصي قبل طلب الاستشارة'; end if;
  if v_mode not in ('عن بعد', 'في المكتب') then raise exception 'طريقة التنفيذ غير صالحة'; end if;

  select coalesce(nullif(trim(lp.whatsapp), ''), nullif(trim(lp_profile.whatsapp_number), ''))
  into v_lawyer_whatsapp
  from public.lawyer_profiles lp
  join public.profiles lp_profile on lp_profile.id = lp.profile_id
  where lp.profile_id = p_lawyer_id
    and lp.verified = true
    and lp.availability = true;

  if v_mode = 'عن بعد' and v_lawyer_whatsapp is null then
    raise exception 'لا يمكن طلب استشارة عن بعد قبل أن يضيف المحامي رقم واتساب للتواصل';
  end if;

  if p_slot_id is not null then
    select id, starts_at into v_slot_id, v_slot_starts_at
    from public.lawyer_availability_slots
    where id = p_slot_id and lawyer_id = p_lawyer_id and is_available = true
    for update;
  else
    select id, starts_at into v_slot_id, v_slot_starts_at
    from public.lawyer_availability_slots
    where lawyer_id = p_lawyer_id
      and starts_at between p_scheduled_at - interval '60 seconds' and p_scheduled_at + interval '60 seconds'
      and is_available = true
    order by abs(extract(epoch from (starts_at - p_scheduled_at)))
    limit 1
    for update;
  end if;
  if v_slot_id is null then raise exception 'عذراً، هذا الموعد لم يعد متاحاً'; end if;
  if v_slot_starts_at <= now() then raise exception 'الموعد يجب أن يكون في المستقبل'; end if;
  if v_consultation_type = '' then raise exception 'يرجى تحديد نوع الاستشارة'; end if;

  if v_is_custom then
    select consultation_price into v_price
    from public.lawyer_profiles
    where profile_id = p_lawyer_id;
    if v_price is null or v_price <= 0 then raise exception 'سعر الاستشارة غير محدد لدى المحامي'; end if;
  else
    select elem into v_package
    from public.lawyer_profiles lp,
      lateral jsonb_array_elements(coalesce(lp.services, '[]'::jsonb)) elem
    where lp.profile_id = p_lawyer_id
      and lower(coalesce(elem ->> 'title', '')) = lower(trim(p_package_name))
    limit 1;
    if v_package is null then raise exception 'الباقة المحددة غير متاحة'; end if;
    v_price := nullif(v_package ->> 'price', '')::numeric;
    v_duration := coalesce(nullif(v_package ->> 'duration_minutes', '')::integer, 30);
    v_description := v_package ->> 'description';
    v_methods := v_package -> 'consultation_types';
    if v_price is null or v_price <= 0 then raise exception 'سعر الباقة غير صالح'; end if;
    if v_consultation_type not in ('نصية', 'صوتية', 'فيديو') then raise exception 'طريقة الاستشارة غير صالحة'; end if;
    if jsonb_typeof(v_methods) = 'array'
      and not (v_methods ? v_consultation_type)
      and not (v_consultation_type = 'فيديو' and v_methods ? 'مرئية') then
      raise exception 'طريقة الاستشارة غير متاحة لهذه الباقة';
    end if;
  end if;

  if exists (
    select 1
    from public.bookings b
    where b.lawyer_id = p_lawyer_id
      and b.scheduled_at between v_slot_starts_at - interval '1 second' and v_slot_starts_at + interval '1 second'
      and b.status not in ('ملغي', 'مسترد')
  ) then raise exception 'عذراً، هذا الموعد لم يعد متاحاً'; end if;

  v_initial_status := case
    when v_free_beta then 'قيد مراجعة المحامي'
    when v_mode = 'في المكتب' then 'بانتظار التأكيد'
    else 'قيد انتظار الدفع'
  end;

  insert into public.bookings (
    user_id, lawyer_id, status, scheduled_at, price, consultation_type, consultation_mode,
    manual_payment_required, payment_required, payment_waived_at, payment_waiver_reason,
    description, document_url, whatsapp_number, package_name, package_description,
    package_duration_minutes, consultation_status, lawyer_approved, lawyer_approved_at
  )
  values (
    v_user_id, p_lawyer_id, v_initial_status, v_slot_starts_at, v_price, v_consultation_type, v_mode,
    v_payment_required and v_mode = 'في المكتب', v_payment_required,
    case when v_payment_required then null else now() end,
    case when v_payment_required then null else 'free_beta' end,
    nullif(trim(p_description), ''), p_document_url, v_whatsapp,
    case when v_is_custom then 'استشارة مختلفة' else trim(p_package_name) end,
    v_description, v_duration, 'لم تبدأ', false, null
  )
  returning * into v_booking;

  update public.lawyer_availability_slots
  set is_available = false
  where id = v_slot_id;

  return v_booking;
end;
$function$;

revoke execute on function public.create_booking(uuid, timestamptz, text, text, text, text, text, uuid, text)
  from public, anon;
grant execute on function public.create_booking(uuid, timestamptz, text, text, text, text, text, uuid, text)
  to authenticated;

create or replace function public.review_booking(p_booking_id uuid, p_approved boolean)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_actor uuid := auth.uid();
  v_profile_id uuid;
  v_booking public.bookings;
  v_is_paid boolean;
begin
  if v_actor is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;

  select id into v_profile_id
  from public.profiles
  where auth_id = v_actor
  limit 1;

  select * into v_booking
  from public.bookings
  where id = p_booking_id
  for update;
  if not found then raise exception 'الحجز غير موجود'; end if;
  if v_booking.lawyer_id <> v_profile_id then raise exception 'غير مصرح بهذا الإجراء'; end if;
  if v_booking.lawyer_approved then raise exception 'تمت مراجعة هذا الطلب مسبقاً'; end if;
  if v_booking.status not in ('قيد انتظار الدفع', 'قيد معالجة الدفع', 'قيد مراجعة المحامي') then
    raise exception 'لا يمكن مراجعة هذا الطلب في حالته الحالية';
  end if;

  select exists (
    select 1 from public.payments
    where booking_id = v_booking.id and status = 'تم الدفع'
  ) into v_is_paid;

  if p_approved then
    update public.bookings
    set lawyer_approved = true,
        lawyer_approved_at = now(),
        status = case
          when not payment_required then 'مؤكد'
          when v_is_paid then 'مؤكد'
          else v_booking.status
        end
    where id = p_booking_id
    returning * into v_booking;
  else
    update public.bookings
    set lawyer_approved = false,
        lawyer_approved_at = null,
        status = case when v_is_paid then 'بانتظار الاسترداد' else 'ملغي' end,
        cancelled_at = case when not v_is_paid then now() else null end
    where id = p_booking_id
    returning * into v_booking;
  end if;

  return v_booking;
end;
$function$;

revoke execute on function public.review_booking(uuid, boolean) from public, anon;
grant execute on function public.review_booking(uuid, boolean) to authenticated;

create or replace function public.change_booking_status(p_booking_id uuid, p_new_status text)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_actor uuid := auth.uid();
  v_profile_id uuid;
  v_booking public.bookings;
  v_is_admin boolean := public.is_admin();
  v_is_paid boolean;
  v_payment_satisfied boolean;
  v_duration integer;
  v_now timestamptz := now();
begin
  if v_actor is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  if p_new_status not in ('مؤكد', 'قيد التنفيذ', 'مكتمل', 'ملغي', 'مسترد') then
    raise exception 'حالة الحجز غير صالحة';
  end if;

  select id into v_profile_id
  from public.profiles
  where auth_id = v_actor
  limit 1;

  select * into v_booking
  from public.bookings
  where id = p_booking_id
  for update;
  if not found then raise exception 'الحجز غير موجود'; end if;

  select exists (
    select 1 from public.payments
    where booking_id = v_booking.id and status = 'تم الدفع'
  ) into v_is_paid;
  v_payment_satisfied := (not v_booking.payment_required) or v_is_paid;

  if v_is_admin then
    null;
  elsif v_booking.user_id = v_profile_id
    and p_new_status = 'ملغي'
    and v_booking.status in ('قيد انتظار الدفع', 'قيد معالجة الدفع', 'قيد مراجعة المحامي', 'مؤكد') then
    null;
  elsif v_booking.lawyer_id = v_profile_id and p_new_status = 'قيد التنفيذ' then
    if v_booking.status <> 'مؤكد'
      or not v_payment_satisfied
      or not v_booking.lawyer_approved
      or v_booking.consultation_status <> 'لم تبدأ' then
      raise exception 'لا يمكن بدء الاستشارة قبل تأكيد الحجز وموافقة المحامي';
    end if;
    if v_booking.payment_required
      and v_booking.consultation_mode = 'في المكتب'
      and (
        v_booking.manual_payment_required = false
        or v_booking.manual_received_at is null
        or round(coalesce(v_booking.manual_received_amount, 0)::numeric, 2) <> round(v_booking.price::numeric, 2)
      ) then
      raise exception 'لا يمكن بدء الاستشارة المكتبية قبل تسجيل مبلغ الدفع المستلم بالكامل';
    end if;
    v_duration := coalesce(v_booking.package_duration_minutes, 30);
    if v_now < v_booking.scheduled_at - interval '5 minutes' then raise exception 'لم يحِن موعد الاستشارة بعد'; end if;
    if v_now > v_booking.scheduled_at + make_interval(mins => v_duration) then raise exception 'انتهى وقت الاستشارة المحدد'; end if;
  elsif v_booking.lawyer_id = v_profile_id and p_new_status = 'مكتمل' then
    if v_booking.status <> 'قيد التنفيذ'
      or v_booking.consultation_status <> 'قيد التنفيذ'
      or v_booking.started_at is null then
      raise exception 'لا يمكن إنهاء الاستشارة في حالتها الحالية';
    end if;
  else
    raise exception 'غير مصرح بهذا الإجراء';
  end if;

  update public.bookings
  set status = p_new_status,
      consultation_status = case
        when p_new_status = 'قيد التنفيذ' then 'قيد التنفيذ'
        when p_new_status = 'مكتمل' then 'انتهت'
        when p_new_status = 'ملغي' and status = 'قيد التنفيذ' then 'أُلغيت'
        else consultation_status
      end,
      started_at = case when p_new_status = 'قيد التنفيذ' then coalesce(started_at, now()) else started_at end,
      completed_at = case when p_new_status = 'مكتمل' then now() else completed_at end,
      cancelled_at = case when p_new_status = 'ملغي' then now() else cancelled_at end
  where id = p_booking_id
  returning * into v_booking;

  return v_booking;
end;
$function$;

revoke execute on function public.change_booking_status(uuid, text) from public, anon;
grant execute on function public.change_booking_status(uuid, text) to authenticated;

create or replace function public.sync_booking_from_payment()
returns trigger
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_booking public.bookings%rowtype;
  v_verifier uuid;
begin
  select * into v_booking
  from public.bookings
  where id = new.booking_id
  for update;
  if not found then raise exception 'الحجز غير موجود'; end if;

  if not v_booking.payment_required then
    raise exception 'لا يمكن إنشاء أو اعتماد دفعة لحجز مجاني تجريبي';
  end if;

  select id into v_verifier
  from public.profiles
  where auth_id = auth.uid()
  limit 1;

  if new.status = 'تم الدفع' then
    if v_booking.status not in ('قيد معالجة الدفع', 'قيد انتظار الدفع', 'قيد مراجعة المحامي') then
      raise exception 'لا يمكن اعتماد الدفع في حالة الحجز الحالية';
    end if;
    new.verified_by := v_verifier;
    new.verified_at := now();
    update public.bookings
    set status = case when lawyer_approved then 'مؤكد' else 'قيد مراجعة المحامي' end
    where id = new.booking_id;
  elsif new.status = 'فشل الدفع' then
    if v_booking.status not in ('قيد معالجة الدفع', 'قيد انتظار الدفع') then
      raise exception 'لا يمكن رفض الدفع في حالة الحجز الحالية';
    end if;
    new.verified_by := v_verifier;
    new.verified_at := now();
    update public.bookings set status = 'قيد انتظار الدفع' where id = new.booking_id;
  elsif new.status = 'تم استرداد المبلغ' then
    if v_booking.status not in ('بانتظار الاسترداد', 'مؤكد', 'قيد التنفيذ', 'مكتمل') then
      raise exception 'لا يمكن استرداد هذا الحجز في حالته الحالية';
    end if;
    new.verified_by := v_verifier;
    new.verified_at := now();
    update public.bookings set status = 'مسترد' where id = new.booking_id;
  end if;

  return new;
end;
$function$;

revoke execute on function public.sync_booking_from_payment() from public, anon, authenticated;
