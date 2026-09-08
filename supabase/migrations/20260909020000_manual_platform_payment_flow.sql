-- Manual platform payment flow.
-- Client transfers the full consultation amount to the platform, uploads a receipt,
-- and payment is financially recognized only after an admin verifies it.

create table if not exists public.manual_payment_settings (
  id boolean primary key default true check (id),
  enabled boolean not null default false,
  provider_name text not null default 'تحويل يدوي',
  account_name text,
  account_number text,
  instructions text,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles(id) on delete set null
);

insert into public.manual_payment_settings(id) values(true) on conflict (id) do nothing;
alter table public.manual_payment_settings enable row level security;
revoke all on public.manual_payment_settings from public, anon, authenticated;
grant select on public.manual_payment_settings to authenticated;

drop policy if exists manual_payment_settings_read on public.manual_payment_settings;
create policy manual_payment_settings_read on public.manual_payment_settings
for select to authenticated using (id=true);

alter table public.payments add column if not exists admin_review_note text;

create or replace function public.get_manual_payment_settings()
returns table(enabled boolean, provider_name text, account_name text, account_number text, instructions text)
language sql security definer set search_path=public
as $$
  select s.enabled,s.provider_name,s.account_name,s.account_number,s.instructions
  from public.manual_payment_settings s where s.id=true;
$$;
revoke execute on function public.get_manual_payment_settings() from public,anon;
grant execute on function public.get_manual_payment_settings() to authenticated;

create or replace function public.admin_update_manual_payment_settings(
  p_enabled boolean,
  p_provider_name text,
  p_account_name text,
  p_account_number text,
  p_instructions text default null
) returns void
language plpgsql security definer set search_path=public
as $$
declare v_admin uuid;
begin
  if auth.uid() is null or not public.is_admin() then raise exception 'غير مصرح: هذه العملية للإدارة فقط'; end if;
  select id into v_admin from public.profiles where auth_id=auth.uid() limit 1;
  if coalesce(p_enabled,false) and nullif(trim(coalesce(p_account_number,'')),'') is null then
    raise exception 'يجب تحديد رقم الحساب أو المحفظة قبل تفعيل الدفع اليدوي';
  end if;

  update public.manual_payment_settings
  set enabled=coalesce(p_enabled,false),
      provider_name=coalesce(nullif(trim(p_provider_name),''),'تحويل يدوي'),
      account_name=nullif(trim(coalesce(p_account_name,'')),''),
      account_number=nullif(trim(coalesce(p_account_number,'')),''),
      instructions=nullif(trim(coalesce(p_instructions,'')),''),
      updated_at=now(), updated_by=v_admin
  where id=true;

  if coalesce(p_enabled,false) then
    update public.app_release_settings
    set free_beta_enabled=false,payments_enabled=true,updated_at=now()
    where id=true;
  else
    update public.app_release_settings
    set payments_enabled=false,updated_at=now()
    where id=true;
  end if;
end;
$$;
revoke execute on function public.admin_update_manual_payment_settings(boolean,text,text,text,text) from public,anon;
grant execute on function public.admin_update_manual_payment_settings(boolean,text,text,text,text) to authenticated;

create or replace function public.submit_payment(
  p_booking_id uuid,
  p_payment_method text,
  p_transaction_number text,
  p_receipt_url text default null
) returns public.payments
language plpgsql security definer set search_path=public
as $$
declare
  v_user_id uuid;
  v_booking public.bookings;
  v_payment public.payments;
  v_manual public.manual_payment_settings%rowtype;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  select id into v_user_id from public.profiles where auth_id=auth.uid() limit 1;
  if v_user_id is null then raise exception 'ملف المستخدم غير مكتمل'; end if;

  select * into v_booking from public.bookings where id=p_booking_id and user_id=v_user_id for update;
  if not found then raise exception 'الحجز غير موجود أو لا تملكه'; end if;
  if v_booking.status<>'قيد انتظار الدفع' then raise exception 'لا يمكن إرسال الدفع في حالة الحجز الحالية'; end if;

  select * into v_manual from public.manual_payment_settings where id=true;
  if not coalesce(v_manual.enabled,false) then raise exception 'الدفع اليدوي غير متاح حالياً'; end if;
  if nullif(trim(coalesce(p_receipt_url,'')),'') is null then raise exception 'يجب رفع إيصال الدفع قبل الضغط على تم الدفع'; end if;
  if nullif(trim(coalesce(p_transaction_number,'')),'') is null then raise exception 'يرجى إدخال رقم عملية التحويل'; end if;

  insert into public.payments(booking_id,amount,payment_method,transaction_number,receipt_url,status,is_manual)
  values(v_booking.id,v_booking.price,'bank_transfer',trim(p_transaction_number),trim(p_receipt_url),'قيد معالجة الدفع',true)
  returning * into v_payment;

  update public.bookings set status='قيد معالجة الدفع' where id=v_booking.id;
  return v_payment;
exception when unique_violation then
  raise exception 'هناك إثبات دفع قيد المراجعة لهذا الحجز';
end;
$$;
revoke execute on function public.submit_payment(uuid,text,text,text) from public,anon;
grant execute on function public.submit_payment(uuid,text,text,text) to authenticated;

create or replace function public.admin_review_manual_payment(
  p_payment_id uuid,
  p_approved boolean,
  p_note text default null
) returns public.payments
language plpgsql security definer set search_path=public
as $$
declare v_payment public.payments;
begin
  if auth.uid() is null or not public.is_admin() then raise exception 'غير مصرح: هذه العملية للإدارة فقط'; end if;
  select * into v_payment from public.payments where id=p_payment_id for update;
  if not found then raise exception 'عملية الدفع غير موجودة'; end if;
  if v_payment.status<>'قيد معالجة الدفع' or not coalesce(v_payment.is_manual,false) then
    raise exception 'هذه الدفعة ليست بانتظار مراجعة يدوية';
  end if;
  if nullif(trim(coalesce(v_payment.receipt_url,'')),'') is null then raise exception 'لا يوجد إيصال دفع مرفوع'; end if;

  update public.payments
  set status=case when p_approved then 'تم الدفع' else 'فشل الدفع' end,
      admin_review_note=nullif(trim(coalesce(p_note,'')),'')
  where id=p_payment_id
  returning * into v_payment;
  return v_payment;
end;
$$;
revoke execute on function public.admin_review_manual_payment(uuid,boolean,text) from public,anon;
grant execute on function public.admin_review_manual_payment(uuid,boolean,text) to authenticated;

create or replace function public.notify_payment_events()
returns trigger
language plpgsql security definer set search_path=public
as $$
declare
  v_user_id uuid;
  v_lawyer_id uuid;
  v_client_name text;
  v_lawyer_name text;
  v_type text;
  v_scheduled_at timestamptz;
  v_price numeric;
  v_admin record;
  v_date_text text;
begin
  select b.user_id,b.lawyer_id,b.price,b.consultation_type,b.scheduled_at,
         coalesce(nullif(trim(cp.full_name),''),'طالب الاستشارة'),
         coalesce(nullif(trim(lp.full_name),''),nullif(trim(lpp.full_name),''),'المحامي')
  into v_user_id,v_lawyer_id,v_price,v_type,v_scheduled_at,v_client_name,v_lawyer_name
  from public.bookings b
  left join public.profiles cp on cp.id=b.user_id
  left join public.lawyer_profiles lp on lp.profile_id=b.lawyer_id
  left join public.profiles lpp on lpp.id=b.lawyer_id
  where b.id=coalesce(new.booking_id,old.booking_id);

  v_date_text:=case when v_scheduled_at is null then 'غير محدد'
    else to_char(v_scheduled_at at time zone 'Asia/Baghdad','YYYY/MM/DD HH24:MI') end;

  if tg_op='INSERT' or new.status is distinct from old.status then
    if new.status='قيد معالجة الدفع' and coalesce(new.is_manual,false) then
      perform public.enqueue_user_notification(
        v_user_id,'تم إرسال إثبات الدفع',
        'تم إرسال إيصال بقيمة '||coalesce(to_char(v_price,'FM999G999G999G990'),'0')||' د.ع لاستشارة '||coalesce(v_type,'قانونية')||' مع '||v_lawyer_name||' بتاريخ '||v_date_text||'. بانتظار تحقق الإدارة.',
        'manual_payment_submitted',new.id,'payment');
      perform public.enqueue_user_notification(
        v_lawyer_id,'أرسل العميل إثبات الدفع',
        v_client_name||' أرسل إثبات دفع بقيمة '||coalesce(to_char(v_price,'FM999G999G999G990'),'0')||' د.ع لاستشارة '||coalesce(v_type,'قانونية')||' بتاريخ '||v_date_text||'. بانتظار تحقق الإدارة.',
        'manual_payment_submitted',new.id,'payment');
      for v_admin in select id from public.profiles where role::text='admin' loop
        perform public.enqueue_user_notification(
          v_admin.id,'دفعة تحتاج مراجعة',
          v_client_name||' رفع إيصالاً بقيمة '||coalesce(to_char(v_price,'FM999G999G999G990'),'0')||' د.ع لحجز مع '||v_lawyer_name||' ('||coalesce(v_type,'استشارة قانونية')||') بتاريخ '||v_date_text||'.',
          'manual_payment_admin_review',new.id,'payment');
      end loop;
    elsif new.status='تم الدفع' then
      perform public.enqueue_user_notification(
        v_user_id,'تم تأكيد الدفع',
        'تحققت الإدارة من دفع مبلغ '||coalesce(to_char(v_price,'FM999G999G999G990'),'0')||' د.ع لاستشارتك مع '||v_lawyer_name||'.',
        'payment_confirmed',new.id,'payment');
      perform public.enqueue_user_notification(
        v_lawyer_id,'تم تأكيد دفع الاستشارة',
        'تحققت الإدارة من دفع '||v_client_name||' مبلغ '||coalesce(to_char(v_price,'FM999G999G999G990'),'0')||' د.ع للاستشارة بتاريخ '||v_date_text||'.',
        'payment_confirmed',new.id,'payment');
    elsif new.status='فشل الدفع' then
      perform public.enqueue_user_notification(
        v_user_id,'تم رفض إثبات الدفع',
        'تعذر اعتماد إثبات دفع استشارتك مع '||v_lawyer_name||'. راجع بيانات التحويل وأعد المحاولة.',
        'payment_rejected',new.id,'payment');
    elsif new.status='تم استرداد المبلغ' then
      perform public.enqueue_user_notification(v_user_id,'تم استرداد المبلغ','تم تسجيل استرداد مبلغ الاستشارة.','payment_refunded',new.id,'payment');
    end if;
  end if;
  return new;
end;
$$;

-- New paid bookings use the platform transfer flow for both remote and office consultations.
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
) returns public.bookings
language plpgsql security definer set search_path=public
as $$
declare
  v_user_id uuid;
  v_booking public.bookings;
  v_package jsonb;
  v_price numeric;
  v_duration integer:=30;
  v_description text;
  v_methods jsonb;
  v_slot_id uuid;
  v_slot_starts_at timestamptz;
  v_slot_duration integer;
  v_slot_price numeric;
  v_is_custom boolean:=lower(trim(coalesce(p_package_name,'')))=lower('استشارة مختلفة');
  v_consultation_type text:=case when trim(coalesce(p_consultation_type,''))='مرئية' then 'فيديو' else trim(coalesce(p_consultation_type,'')) end;
  v_mode text:=trim(coalesce(p_consultation_mode,'عن بعد'));
  v_whatsapp text;
  v_lawyer_whatsapp text;
  v_initial_status text;
  v_free_beta boolean;
  v_payments_enabled boolean;
  v_manual_enabled boolean;
  v_payment_required boolean;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  select free_beta_enabled,payments_enabled into v_free_beta,v_payments_enabled from public.app_release_settings where id=true;
  select enabled into v_manual_enabled from public.manual_payment_settings where id=true;
  v_free_beta:=coalesce(v_free_beta,false);
  v_payments_enabled:=coalesce(v_payments_enabled,false);
  v_manual_enabled:=coalesce(v_manual_enabled,false);
  if not v_free_beta and not (v_payments_enabled and v_manual_enabled) then raise exception 'إنشاء الحجوزات متوقف مؤقتاً حتى تفعيل وسيلة الدفع'; end if;
  v_payment_required:=not v_free_beta;

  select id,nullif(trim(whatsapp_number),'') into v_user_id,v_whatsapp from public.profiles where auth_id=auth.uid() limit 1;
  if v_user_id is null then raise exception 'ملف المستخدم غير مكتمل'; end if;
  if v_whatsapp is null then raise exception 'يجب إضافة رقم واتساب في الملف الشخصي قبل طلب الاستشارة'; end if;
  if v_mode not in ('عن بعد','في المكتب') then raise exception 'طريقة التنفيذ غير صالحة'; end if;

  select coalesce(nullif(trim(lp.whatsapp),''),nullif(trim(p.whatsapp_number),'')) into v_lawyer_whatsapp
  from public.lawyer_profiles lp join public.profiles p on p.id=lp.profile_id
  where lp.profile_id=p_lawyer_id and lp.verified=true and lp.availability=true;
  if v_mode='عن بعد' and v_lawyer_whatsapp is null then raise exception 'لا يمكن طلب استشارة عن بعد قبل أن يضيف المحامي رقم واتساب للتواصل'; end if;

  if p_slot_id is not null then
    select id,starts_at,duration_minutes,price into v_slot_id,v_slot_starts_at,v_slot_duration,v_slot_price
    from public.lawyer_availability_slots where id=p_slot_id and lawyer_id=p_lawyer_id and is_available=true for update;
  else
    select id,starts_at,duration_minutes,price into v_slot_id,v_slot_starts_at,v_slot_duration,v_slot_price
    from public.lawyer_availability_slots
    where lawyer_id=p_lawyer_id and starts_at between p_scheduled_at-interval '60 seconds' and p_scheduled_at+interval '60 seconds' and is_available=true
    order by abs(extract(epoch from (starts_at-p_scheduled_at))) limit 1 for update;
  end if;
  if v_slot_id is null then raise exception 'عذراً، هذا الموعد لم يعد متاحاً'; end if;
  if v_slot_starts_at<=now() then raise exception 'الموعد يجب أن يكون في المستقبل'; end if;
  if v_consultation_type='' then raise exception 'يرجى تحديد نوع الاستشارة'; end if;

  if v_is_custom then
    select consultation_price into v_price from public.lawyer_profiles where profile_id=p_lawyer_id;
    if v_price is null or v_price<=0 then raise exception 'سعر الاستشارة غير محدد لدى المحامي'; end if;
  else
    select elem into v_package from public.lawyer_profiles lp,lateral jsonb_array_elements(coalesce(lp.services,'[]'::jsonb)) elem
    where lp.profile_id=p_lawyer_id and lower(coalesce(elem->>'title',''))=lower(trim(p_package_name)) limit 1;
    if v_package is null then raise exception 'الباقة المحددة غير متاحة'; end if;
    v_price:=nullif(v_package->>'price','')::numeric;
    v_duration:=coalesce(nullif(v_package->>'duration_minutes','')::integer,30);
    v_description:=v_package->>'description';
    v_methods:=v_package->'consultation_types';
    if v_price is null or v_price<=0 then raise exception 'سعر الباقة غير صالح'; end if;
    if v_consultation_type not in ('نصية','صوتية','فيديو') then raise exception 'طريقة الاستشارة غير صالحة'; end if;
    if jsonb_typeof(v_methods)='array' and not (v_methods ? v_consultation_type) and not (v_consultation_type='فيديو' and v_methods ? 'مرئية') then raise exception 'طريقة الاستشارة غير متاحة لهذه الباقة'; end if;
  end if;

  v_duration:=coalesce(v_slot_duration,v_duration,30);
  v_price:=coalesce(v_slot_price,v_price);
  if v_duration<15 or v_duration>180 then raise exception 'مدة الموعد غير صالحة'; end if;
  if v_price is null or v_price<=0 then raise exception 'سعر الموعد غير صالح'; end if;

  if exists(select 1 from public.bookings b where b.lawyer_id=p_lawyer_id and b.scheduled_at between v_slot_starts_at-interval '1 second' and v_slot_starts_at+interval '1 second' and b.status not in ('ملغي','مسترد')) then
    raise exception 'عذراً، هذا الموعد لم يعد متاحاً';
  end if;

  v_initial_status:=case when v_free_beta then 'قيد مراجعة المحامي' else 'قيد انتظار الدفع' end;

  insert into public.bookings(
    user_id,lawyer_id,status,scheduled_at,price,consultation_type,consultation_mode,
    manual_payment_required,payment_required,payment_waived_at,payment_waiver_reason,
    description,document_url,whatsapp_number,package_name,package_description,
    package_duration_minutes,consultation_status,lawyer_approved,lawyer_approved_at
  ) values(
    v_user_id,p_lawyer_id,v_initial_status,v_slot_starts_at,v_price,v_consultation_type,v_mode,
    false,v_payment_required,
    case when v_payment_required then null else now() end,
    case when v_payment_required then null else 'free_beta' end,
    nullif(trim(p_description),''),p_document_url,v_whatsapp,
    case when v_is_custom then 'استشارة مختلفة' else trim(p_package_name) end,
    v_description,v_duration,'لم تبدأ',false,null
  ) returning * into v_booking;

  update public.lawyer_availability_slots set is_available=false where id=v_slot_id;
  return v_booking;
end;
$$;

-- The stale payment cleanup job must only resolve abandoned Qi Card payments.
create or replace function public.cleanup_stale_processing_bookings()
returns integer
language plpgsql security definer set search_path=public
as $$
declare v_booking_id uuid; v_count integer:=0;
begin
  for v_booking_id in
    select b.id from public.bookings b
    where b.status='قيد معالجة الدفع'
      and not exists(select 1 from public.payments paid where paid.booking_id=b.id and paid.status='تم الدفع')
      and exists(select 1 from public.payments p where p.booking_id=b.id and p.status='قيد معالجة الدفع' and (p.payment_method='Qi Card' or p.qicard_payment_id is not null or p.qicard_request_id is not null))
      and not exists(select 1 from public.payments recent where recent.booking_id=b.id and recent.status='قيد معالجة الدفع' and (recent.payment_method='Qi Card' or recent.qicard_payment_id is not null or recent.qicard_request_id is not null) and recent.created_at>now()-interval '24 hours')
    for update
  loop
    update public.payments set status='فشل الدفع'
    where booking_id=v_booking_id and status='قيد معالجة الدفع'
      and (payment_method='Qi Card' or qicard_payment_id is not null or qicard_request_id is not null);
    update public.bookings set status='ملغي',cancelled_at=coalesce(cancelled_at,now())
    where id=v_booking_id and status in ('قيد انتظار الدفع','قيد معالجة الدفع');
    if found then v_count:=v_count+1; end if;
  end loop;
  return v_count;
end;
$$;
