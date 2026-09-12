alter table public.custom_appointment_requests
  add column if not exists expired_waiting_on text,
  add column if not exists expired_at timestamptz;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname='custom_appointment_requests_expired_waiting_on_check'
      and conrelid='public.custom_appointment_requests'::regclass
  ) then
    alter table public.custom_appointment_requests
      add constraint custom_appointment_requests_expired_waiting_on_check
      check (expired_waiting_on is null or expired_waiting_on in ('client','lawyer'));
  end if;
end $$;

create or replace function public.appointment_response_deadline(p_waiting_on text)
returns timestamptz
language plpgsql
stable
set search_path to 'public'
as $function$
declare
  v_deadline timestamptz;
  v_local timestamp;
begin
  v_deadline := now() + case when p_waiting_on='client' then interval '4 hours' else interval '6 hours' end;
  v_local := v_deadline at time zone 'Asia/Baghdad';
  if v_local::time < time '10:00' then
    v_deadline := ((v_local::date + time '10:00') at time zone 'Asia/Baghdad');
  end if;
  return v_deadline;
end;
$function$;

create or replace function public.is_lawyer_time_blocked(
  p_lawyer_id uuid,
  p_start timestamptz,
  p_duration_minutes integer,
  p_exclude_request_id uuid default null
)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select exists(
    select 1
    from public.bookings b
    where b.lawyer_id=p_lawyer_id
      and b.scheduled_at is not null
      and b.status not in ('ملغي','مسترد','بانتظار الاسترداد','مكتمل')
      and tstzrange(
            b.scheduled_at,
            b.scheduled_at + make_interval(mins=>greatest(1,coalesce(b.package_duration_minutes,30))),
            '[)'
          ) &&
          tstzrange(
            p_start,
            p_start + make_interval(mins=>greatest(1,coalesce(p_duration_minutes,30))),
            '[)'
          )
  ) or exists(
    select 1
    from public.custom_appointment_requests r
    cross join lateral jsonb_array_elements(coalesce(r.lawyer_options,'[]'::jsonb)) opt
    where r.lawyer_id=p_lawyer_id
      and r.status='بانتظار اختيار العميل'
      and r.expires_at>now()
      and (p_exclude_request_id is null or r.id<>p_exclude_request_id)
      and opt ? 'start'
      and tstzrange(
            (opt->>'start')::timestamptz,
            (opt->>'start')::timestamptz + make_interval(mins=>greatest(1,coalesce(r.duration_minutes,30))),
            '[)'
          ) &&
          tstzrange(
            p_start,
            p_start + make_interval(mins=>greatest(1,coalesce(p_duration_minutes,30))),
            '[)'
          )
  );
$function$;

create or replace function public.guard_booking_time_conflict()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_duration integer;
begin
  if new.lawyer_id is null or new.scheduled_at is null
     or new.status in ('ملغي','مسترد','بانتظار الاسترداد','مكتمل') then
    return new;
  end if;
  v_duration := greatest(1,coalesce(new.package_duration_minutes,30));
  perform pg_advisory_xact_lock(hashtextextended(new.lawyer_id::text,0));

  if exists(
    select 1 from public.bookings b
    where b.lawyer_id=new.lawyer_id
      and b.id<>new.id
      and b.scheduled_at is not null
      and b.status not in ('ملغي','مسترد','بانتظار الاسترداد','مكتمل')
      and tstzrange(b.scheduled_at,b.scheduled_at+make_interval(mins=>greatest(1,coalesce(b.package_duration_minutes,30))),'[)')
          && tstzrange(new.scheduled_at,new.scheduled_at+make_interval(mins=>v_duration),'[)')
  ) then
    raise exception 'هذا الموعد محجوز ويتداخل مع استشارة أخرى خلال كامل المدة. اختر موعداً آخر';
  end if;

  if exists(
    select 1
    from public.custom_appointment_requests r
    cross join lateral jsonb_array_elements(coalesce(r.lawyer_options,'[]'::jsonb)) opt
    where r.lawyer_id=new.lawyer_id
      and r.status='بانتظار اختيار العميل'
      and r.expires_at>now()
      and opt ? 'start'
      and tstzrange((opt->>'start')::timestamptz,(opt->>'start')::timestamptz+make_interval(mins=>greatest(1,coalesce(r.duration_minutes,30))),'[)')
          && tstzrange(new.scheduled_at,new.scheduled_at+make_interval(mins=>v_duration),'[)')
  ) then
    raise exception 'هذا الموعد محجوز مؤقتاً لطلب آخر بانتظار الرد. اختر موعداً آخر';
  end if;
  return new;
end;
$function$;

drop trigger if exists trg_guard_booking_time_conflict on public.bookings;
create trigger trg_guard_booking_time_conflict
before insert or update of lawyer_id,scheduled_at,package_duration_minutes,status
on public.bookings
for each row execute function public.guard_booking_time_conflict();

create or replace function public.guard_custom_appointment_slot_holds()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_item jsonb;
  v_prior jsonb := '[]'::jsonb;
  v_start timestamptz;
  v_duration integer := greatest(1,coalesce(new.duration_minutes,30));
begin
  if new.status<>'بانتظار اختيار العميل' or new.expires_at<=now()
     or jsonb_typeof(new.lawyer_options)<>'array' then
    return new;
  end if;
  perform pg_advisory_xact_lock(hashtextextended(new.lawyer_id::text,0));

  for v_item in select value from jsonb_array_elements(new.lawyer_options) loop
    begin
      v_start := (v_item->>'start')::timestamptz;
    exception when others then
      raise exception 'أحد المواعيد المقترحة غير صالح';
    end;

    if public.is_lawyer_time_blocked(new.lawyer_id,v_start,v_duration,new.id) then
      raise exception 'الموعد % محجوز أو يتداخل مع استشارة أخرى. اختر وقتاً مختلفاً',
        to_char(v_start at time zone 'Asia/Baghdad','YYYY/MM/DD HH24:MI');
    end if;

    if exists(
      select 1 from jsonb_array_elements(v_prior) p
      where tstzrange((p->>'start')::timestamptz,(p->>'start')::timestamptz+make_interval(mins=>v_duration),'[)')
            && tstzrange(v_start,v_start+make_interval(mins=>v_duration),'[)')
    ) then
      raise exception 'المواعيد المقترحة داخل الطلب نفسه متداخلة؛ اختر أوقاتاً منفصلة';
    end if;
    v_prior := v_prior || jsonb_build_array(v_item);
  end loop;
  return new;
end;
$function$;

drop trigger if exists trg_guard_custom_appointment_slot_holds on public.custom_appointment_requests;
create trigger trg_guard_custom_appointment_slot_holds
before insert or update of lawyer_options,status,expires_at,duration_minutes,lawyer_id
on public.custom_appointment_requests
for each row execute function public.guard_custom_appointment_slot_holds();

create or replace function public.get_lawyer_booking_slots(p_lawyer_id uuid)
returns table(
  id uuid,
  starts_at timestamptz,
  duration_minutes integer,
  price numeric,
  is_bookable boolean,
  unavailable_reason text
)
language sql
stable
security definer
set search_path to 'public'
as $function$
  with slots as (
    select s.id,s.starts_at,coalesce(s.duration_minutes,30) as duration_minutes,s.price,s.is_available,
           public.is_lawyer_time_blocked(s.lawyer_id,s.starts_at,coalesce(s.duration_minutes,30),null) as blocked
    from public.lawyer_availability_slots s
    where s.lawyer_id=p_lawyer_id and s.starts_at>now()
  )
  select id,starts_at,duration_minutes,price,
         (is_available and not blocked) as is_bookable,
         case when blocked then 'محجوز بالفعل لهذه المدة' when not is_available then 'غير متاح' else null end
  from slots
  where is_available or blocked
  order by starts_at;
$function$;

revoke all on function public.get_lawyer_booking_slots(uuid) from public,anon;
grant execute on function public.get_lawyer_booking_slots(uuid) to authenticated;

create or replace function public.expire_stale_custom_appointment_requests()
returns integer
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  r record;
  v_count integer:=0;
  v_balance numeric;
  v_waiting_on text;
  v_client_name text;
  v_lawyer_name text;
begin
  for r in
    select * from public.custom_appointment_requests
    where status in ('بانتظار رد المحامي','بانتظار اختيار العميل') and expires_at<=now()
    for update skip locked
  loop
    v_waiting_on := case when r.status='بانتظار رد المحامي' then 'lawyer' else 'client' end;
    select coalesce(nullif(trim(full_name),''),'طالب الاستشارة') into v_client_name from public.profiles where id=r.user_id;
    select coalesce(nullif(trim(full_name),''),'المحامي') into v_lawyer_name from public.profiles where id=r.lawyer_id;
    v_client_name := coalesce(v_client_name,'طالب الاستشارة');
    v_lawyer_name := coalesce(v_lawyer_name,'المحامي');

    if r.reserved_amount>0 then
      update public.client_wallets
      set available_balance=available_balance+r.reserved_amount,
          held_balance=greatest(0,held_balance-r.reserved_amount),updated_at=now()
      where user_id=r.user_id returning available_balance into v_balance;
      insert into public.client_wallet_ledger(
        user_id,amount,entry_type,appointment_request_id,balance_after,idempotency_key
      ) values(
        r.user_id,r.reserved_amount,'appointment_release',r.id,v_balance,
        'appointment:'||r.id||':expiry-release'
      ) on conflict(idempotency_key) do nothing;
    end if;

    update public.custom_appointment_requests
    set status='منتهي',expired_waiting_on=v_waiting_on,expired_at=now(),updated_at=now()
    where id=r.id;

    perform public.enqueue_user_notification(
      r.user_id,
      case when v_waiting_on='lawyer' then 'لم يرد '||v_lawyer_name||' — أُلغي الطلب' else 'انتهت مهلة ردك على '||v_lawyer_name end,
      case when v_waiting_on='lawyer'
        then 'لم يرد المحامي '||v_lawyer_name||' ضمن المهلة المحددة، لذلك أُلغي طلب الموعد وأُعيد المبلغ المحجوز. يمكنك الحجز مرة أخرى.'
        else 'لم يتم اختيار أو تغيير موعد '||v_lawyer_name||' ضمن المهلة المحددة، لذلك أُلغي الطلب وأُعيد المبلغ المحجوز. يمكنك الحجز مرة أخرى.' end,
      'appointment_request_expired',r.id,'appointment_request'
    );

    perform public.enqueue_user_notification(
      r.lawyer_id,
      case when v_waiting_on='lawyer' then 'انتهت مهلة ردك على '||v_client_name else 'لم يرد '||v_client_name||' — أُلغي الطلب' end,
      case when v_waiting_on='lawyer'
        then 'لم يتم الرد على طلب الموعد المرسل من '||v_client_name||' ضمن المهلة المحددة، لذلك أُلغي الطلب تلقائياً.'
        else 'لم يرد طالب الاستشارة '||v_client_name||' على المواعيد المقترحة ضمن المهلة المحددة، لذلك أُلغي الطلب تلقائياً.' end,
      'appointment_request_expired',r.id,'appointment_request'
    );
    v_count:=v_count+1;
  end loop;
  return v_count;
end;
$function$;

create or replace function public.submit_custom_appointment_request(
  p_lawyer_id uuid,
  p_package_name text,
  p_consultation_type text,
  p_consultation_mode text,
  p_description text,
  p_document_url text,
  p_client_windows jsonb
)
returns public.custom_appointment_requests
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_user_id uuid; v_whatsapp text; v_client_name text; v_lawyer_name text; v_lawyer_whatsapp text;
  v_package jsonb; v_price numeric; v_duration integer:=30; v_package_description text;
  v_type text:=case when trim(coalesce(p_consultation_type,''))='مرئية' then 'فيديو' else trim(coalesce(p_consultation_type,'')) end;
  v_mode text:=trim(coalesce(p_consultation_mode,'عن بعد'));
  v_free_beta boolean; v_payments_enabled boolean; v_manual_enabled boolean;
  v_payment_required boolean; v_wallet public.client_wallets%rowtype; v_balance numeric;
  v_item jsonb; v_start timestamptz; v_end timestamptz; v_request public.custom_appointment_requests;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  perform public.expire_stale_custom_appointment_requests();
  select id,nullif(trim(whatsapp_number),''),coalesce(nullif(trim(full_name),''),'طالب الاستشارة')
  into v_user_id,v_whatsapp,v_client_name
  from public.profiles where auth_id=auth.uid() and role='user' and status='active' limit 1;
  if v_user_id is null then raise exception 'طلب الموعد متاح لطالب الاستشارة فقط'; end if;
  if v_whatsapp is null then raise exception 'أضف رقم واتساب في الملف الشخصي أولاً'; end if;

  select coalesce(nullif(trim(p.full_name),''),'المحامي'),
         coalesce(nullif(trim(lp.whatsapp),''),nullif(trim(p.whatsapp_number),'')),lp.consultation_price
  into v_lawyer_name,v_lawyer_whatsapp,v_price
  from public.profiles p join public.lawyer_profiles lp on lp.profile_id=p.id
  where p.id=p_lawyer_id and p.role='lawyer' and p.status='active' and lp.verified=true and lp.availability=true;
  if not found then raise exception 'المحامي غير متاح لاستقبال الطلبات'; end if;
  if v_mode not in ('عن بعد','في المكتب') then raise exception 'طريقة التنفيذ غير صالحة'; end if;
  if v_mode='عن بعد' and v_lawyer_whatsapp is null then raise exception 'المحامي لم يضف رقم التواصل بعد'; end if;
  if v_type not in ('نصية','صوتية','فيديو') then raise exception 'نوع الاستشارة غير صالح'; end if;

  if lower(trim(coalesce(p_package_name,'')))<>lower('استشارة مختلفة') then
    select elem into v_package
    from public.lawyer_profiles lp,lateral jsonb_array_elements(coalesce(lp.services,'[]'::jsonb)) elem
    where lp.profile_id=p_lawyer_id and lower(coalesce(elem->>'title',''))=lower(trim(p_package_name)) limit 1;
    if v_package is null then raise exception 'الخدمة المحددة غير متاحة'; end if;
    v_price:=nullif(v_package->>'price','')::numeric;
    v_duration:=coalesce(nullif(v_package->>'duration_minutes','')::integer,30);
    v_package_description:=v_package->>'description';
  end if;
  if v_price is null or v_price<=0 then raise exception 'سعر الاستشارة غير محدد'; end if;

  if jsonb_typeof(p_client_windows)<>'array' or jsonb_array_length(p_client_windows)<1 or jsonb_array_length(p_client_windows)>3 then
    raise exception 'حدد من فترة واحدة إلى ثلاث فترات مناسبة';
  end if;
  for v_item in select value from jsonb_array_elements(p_client_windows) loop
    begin v_start:=(v_item->>'start')::timestamptz; v_end:=(v_item->>'end')::timestamptz;
    exception when others then raise exception 'إحدى الفترات المقترحة غير صالحة'; end;
    if v_start<=now()+interval '30 minutes' or v_end<=v_start or v_end-v_start>interval '12 hours' then
      raise exception 'يجب أن تكون الفترات مستقبلية وواضحة ولا تتجاوز 12 ساعة';
    end if;
    if v_end < v_start+make_interval(mins=>v_duration) then raise exception 'إحدى الفترات أقصر من مدة الاستشارة'; end if;
  end loop;

  select free_beta_enabled,payments_enabled into v_free_beta,v_payments_enabled from public.app_release_settings where id=true;
  select enabled into v_manual_enabled from public.manual_payment_settings where id=true;
  v_payment_required:=not coalesce(v_free_beta,false);
  if v_payment_required and not (coalesce(v_payments_enabled,false) and coalesce(v_manual_enabled,false)) then raise exception 'الحجوزات المدفوعة متوقفة مؤقتاً'; end if;

  if v_payment_required then
    select * into v_wallet from public.client_wallets where user_id=v_user_id for update;
    if not found or v_wallet.available_balance<v_price then raise exception 'رصيد المحفظة غير كافٍ لإرسال طلب الموعد'; end if;
    update public.client_wallets set available_balance=available_balance-v_price,held_balance=held_balance+v_price,updated_at=now()
    where user_id=v_user_id returning available_balance into v_balance;
  end if;

  insert into public.custom_appointment_requests(
    user_id,lawyer_id,package_name,package_description,consultation_type,consultation_mode,
    description,document_url,price,duration_minutes,payment_required,reserved_amount,client_windows,expires_at
  ) values(
    v_user_id,p_lawyer_id,coalesce(nullif(trim(p_package_name),''),'استشارة مختلفة'),v_package_description,v_type,v_mode,
    nullif(trim(coalesce(p_description,'')),''),p_document_url,case when v_payment_required then v_price else 0 end,
    v_duration,v_payment_required,case when v_payment_required then v_price else 0 end,p_client_windows,
    public.appointment_response_deadline('lawyer')
  ) returning * into v_request;

  if v_payment_required then
    insert into public.client_wallet_ledger(user_id,amount,entry_type,appointment_request_id,balance_after,idempotency_key)
    values(v_user_id,-v_price,'appointment_hold',v_request.id,v_balance,'appointment:'||v_request.id||':hold');
  end if;
  perform public.enqueue_user_notification(
    p_lawyer_id,'طلب موعد جديد من '||v_client_name,
    v_client_name||' حدد أوقاتاً مناسبة. اختر وقتاً منها أو اقترح موعداً بديلاً قبل '||
      to_char(v_request.expires_at at time zone 'Asia/Baghdad','YYYY/MM/DD HH24:MI')||'.',
    'appointment_request_new',v_request.id,'appointment_request'
  );
  return v_request;
end;
$function$;

create or replace function public.lawyer_respond_custom_appointment_request(
  p_request_id uuid,
  p_options jsonb default null,
  p_reject_reason text default null
)
returns public.custom_appointment_requests
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_lawyer_id uuid; v_lawyer_name text; v_request public.custom_appointment_requests;
  v_item jsonb; v_start timestamptz; v_balance numeric; v_option_text text := ''; v_option_count integer := 0;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  perform public.expire_stale_custom_appointment_requests();
  select id,coalesce(nullif(trim(full_name),''),'المحامي') into v_lawyer_id,v_lawyer_name
  from public.profiles where auth_id=auth.uid() and role='lawyer' and status='active' limit 1;
  select * into v_request from public.custom_appointment_requests where id=p_request_id and lawyer_id=v_lawyer_id for update;
  if not found then raise exception 'طلب الموعد غير موجود'; end if;
  if v_request.status<>'بانتظار رد المحامي' or v_request.expires_at<=now() then raise exception 'انتهت مهلة الرد على هذا الطلب'; end if;

  if nullif(trim(coalesce(p_reject_reason,'')),'') is not null then
    if v_request.reserved_amount>0 then
      update public.client_wallets set available_balance=available_balance+v_request.reserved_amount,
        held_balance=greatest(0,held_balance-v_request.reserved_amount),updated_at=now()
      where user_id=v_request.user_id returning available_balance into v_balance;
      insert into public.client_wallet_ledger(user_id,amount,entry_type,appointment_request_id,balance_after,idempotency_key)
      values(v_request.user_id,v_request.reserved_amount,'appointment_release',v_request.id,v_balance,
        'appointment:'||v_request.id||':rejected-release') on conflict(idempotency_key) do nothing;
    end if;
    update public.custom_appointment_requests set status='مرفوض',rejection_reason=trim(p_reject_reason),rejected_by='lawyer',
      expired_waiting_on=null,expired_at=null,updated_at=now() where id=v_request.id returning * into v_request;
    perform public.enqueue_user_notification(v_request.user_id,'رفض '||v_lawyer_name||' طلب الموعد',
      'رفض المحامي '||v_lawyer_name||' الطلب نهائياً، وأُعيد المبلغ المحجوز إلى رصيدك.',
      'appointment_request_rejected',v_request.id,'appointment_request');
    return v_request;
  end if;

  if jsonb_typeof(p_options)<>'array' or jsonb_array_length(p_options)<1 or jsonb_array_length(p_options)>3 then raise exception 'اقترح من موعد واحد إلى ثلاثة مواعيد'; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_lawyer_id::text,0));
  for v_item in select value from jsonb_array_elements(p_options) loop
    begin v_start:=(v_item->>'start')::timestamptz; exception when others then raise exception 'أحد المواعيد المقترحة غير صالح'; end;
    if v_start<=now()+interval '30 minutes' then raise exception 'يجب أن يكون الموعد في المستقبل'; end if;
    if public.is_lawyer_time_blocked(v_lawyer_id,v_start,v_request.duration_minutes,v_request.id) then
      raise exception 'الموعد % محجوز أو يتداخل مع استشارة أخرى خلال مدة الاستشارة',to_char(v_start at time zone 'Asia/Baghdad','YYYY/MM/DD HH24:MI');
    end if;
    v_option_count:=v_option_count+1;
    v_option_text:=v_option_text||case when v_option_text='' then '' else '، ' end||to_char(v_start at time zone 'Asia/Baghdad','YYYY/MM/DD HH24:MI');
  end loop;

  update public.custom_appointment_requests set lawyer_options=p_options,status='بانتظار اختيار العميل',selected_option=null,
    rejection_reason=null,rejected_by=null,expired_waiting_on=null,expired_at=null,
    expires_at=public.appointment_response_deadline('client'),updated_at=now()
  where id=v_request.id returning * into v_request;
  perform public.enqueue_user_notification(
    v_request.user_id,
    case when v_option_count=1 then 'موعد مقترح من '||v_lawyer_name else 'مواعيد مقترحة من '||v_lawyer_name end,
    case when v_option_count=1 then 'اقترح '||v_lawyer_name||' الموعد '||v_option_text else 'اقترح '||v_lawyer_name||' المواعيد '||v_option_text end||
      '. الموعد محجوز مؤقتاً لك حتى '||to_char(v_request.expires_at at time zone 'Asia/Baghdad','YYYY/MM/DD HH24:MI')||'. افتح الطلب للقبول أو التغيير أو الرفض.',
    'appointment_options_ready',v_request.id,'appointment_request'
  );
  return v_request;
end;
$function$;

create or replace function public.client_respond_custom_appointment_request(
  p_request_id uuid,
  p_windows jsonb default null,
  p_reject_reason text default null
)
returns public.custom_appointment_requests
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_user_id uuid; v_client_name text; v_request public.custom_appointment_requests;
  v_item jsonb; v_start timestamptz; v_end timestamptz; v_balance numeric; v_window_text text := ''; v_count integer := 0;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  perform public.expire_stale_custom_appointment_requests();
  select id,coalesce(nullif(trim(full_name),''),'طالب الاستشارة') into v_user_id,v_client_name
  from public.profiles where auth_id=auth.uid() and role='user' and status='active' limit 1;
  select * into v_request from public.custom_appointment_requests where id=p_request_id and user_id=v_user_id for update;
  if not found then raise exception 'طلب الموعد غير موجود'; end if;
  if v_request.status<>'بانتظار اختيار العميل' or v_request.expires_at<=now() then raise exception 'انتهت مهلة الرد على هذا الطلب'; end if;

  if nullif(trim(coalesce(p_reject_reason,'')),'') is not null then
    if v_request.reserved_amount>0 then
      update public.client_wallets set available_balance=available_balance+v_request.reserved_amount,
        held_balance=greatest(0,held_balance-v_request.reserved_amount),updated_at=now()
      where user_id=v_user_id returning available_balance into v_balance;
      insert into public.client_wallet_ledger(user_id,amount,entry_type,appointment_request_id,balance_after,idempotency_key)
      values(v_user_id,v_request.reserved_amount,'appointment_release',v_request.id,v_balance,
        'appointment:'||v_request.id||':client-rejected-release') on conflict(idempotency_key) do nothing;
    end if;
    update public.custom_appointment_requests set status='مرفوض',rejection_reason=trim(p_reject_reason),rejected_by='client',
      expired_waiting_on=null,expired_at=null,updated_at=now() where id=v_request.id returning * into v_request;
    perform public.enqueue_user_notification(v_request.lawyer_id,'رفض '||v_client_name||' الموعد المقترح',
      'رفض طالب الاستشارة '||v_client_name||' المواعيد المقترحة وأنهى الطلب.',
      'appointment_request_rejected_by_client',v_request.id,'appointment_request');
    return v_request;
  end if;

  if v_request.negotiation_round>=3 then raise exception 'وصل الطلب إلى الحد الأقصى لتعديل المواعيد؛ اختر موعداً أو ارفض الطلب'; end if;
  if jsonb_typeof(p_windows)<>'array' or jsonb_array_length(p_windows)<1 or jsonb_array_length(p_windows)>3 then raise exception 'حدد من فترة واحدة إلى ثلاث فترات'; end if;
  for v_item in select value from jsonb_array_elements(p_windows) loop
    begin v_start:=(v_item->>'start')::timestamptz; v_end:=(v_item->>'end')::timestamptz;
    exception when others then raise exception 'إحدى الفترات المقترحة غير صالحة'; end;
    if v_start<=now()+interval '30 minutes' then raise exception 'يجب أن تبدأ الفترة في المستقبل'; end if;
    if v_end<=v_start then raise exception 'نهاية الفترة يجب أن تكون بعد بدايتها'; end if;
    if v_end-v_start>interval '12 hours' then raise exception 'الفترة الواحدة لا يمكن أن تتجاوز 12 ساعة'; end if;
    if v_end < v_start+make_interval(mins=>v_request.duration_minutes) then raise exception 'إحدى الفترات أقصر من مدة الاستشارة'; end if;
    v_count:=v_count+1;
    v_window_text:=v_window_text||case when v_window_text='' then '' else '، ' end||
      to_char(v_start at time zone 'Asia/Baghdad','YYYY/MM/DD HH24:MI')||'–'||to_char(v_end at time zone 'Asia/Baghdad','HH24:MI');
  end loop;

  update public.custom_appointment_requests set client_windows=p_windows,lawyer_options=null,selected_option=null,
    status='بانتظار رد المحامي',negotiation_round=negotiation_round+1,rejection_reason=null,rejected_by=null,
    expired_waiting_on=null,expired_at=null,expires_at=public.appointment_response_deadline('lawyer'),updated_at=now()
  where id=v_request.id returning * into v_request;

  perform public.enqueue_user_notification(
    v_request.lawyer_id,
    case when v_count=1 then v_client_name||' اقترح وقتاً بديلاً' else v_client_name||' اقترح أوقاتاً بديلة' end,
    'الأوقات الجديدة من '||v_client_name||': '||v_window_text||'. رد قبل '||
      to_char(v_request.expires_at at time zone 'Asia/Baghdad','YYYY/MM/DD HH24:MI')||'.',
    'appointment_client_counter_offer',v_request.id,'appointment_request'
  );
  return v_request;
end;
$function$;

create or replace function public.client_confirm_custom_appointment(p_request_id uuid,p_option_index integer)
returns public.bookings
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_user_id uuid; v_whatsapp text; v_request public.custom_appointment_requests;
  v_option jsonb; v_start timestamptz; v_booking public.bookings; v_wallet public.client_wallets%rowtype;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  perform public.expire_stale_custom_appointment_requests();
  select id,nullif(trim(whatsapp_number),'') into v_user_id,v_whatsapp from public.profiles
  where auth_id=auth.uid() and role='user' and status='active' limit 1;
  select * into v_request from public.custom_appointment_requests where id=p_request_id and user_id=v_user_id for update;
  if not found then raise exception 'طلب الموعد غير موجود'; end if;
  if v_request.status<>'بانتظار اختيار العميل' or v_request.expires_at<=now() then raise exception 'انتهت مهلة اختيار الموعد'; end if;
  if p_option_index is null or p_option_index<0 or p_option_index>=jsonb_array_length(v_request.lawyer_options) then raise exception 'الموعد المختار غير صالح'; end if;
  v_option:=v_request.lawyer_options->p_option_index;
  v_start:=(v_option->>'start')::timestamptz;
  if v_start<=now() then raise exception 'الموعد المختار انتهى'; end if;

  perform pg_advisory_xact_lock(hashtextextended(v_request.lawyer_id::text,0));
  if public.is_lawyer_time_blocked(v_request.lawyer_id,v_start,v_request.duration_minutes,v_request.id) then
    raise exception 'الموعد لم يعد متاحاً لأنه يتداخل مع حجز آخر؛ اطلب من المحامي اقتراح موعد جديد';
  end if;

  if v_request.payment_required then
    select * into v_wallet from public.client_wallets where user_id=v_user_id for update;
    if not found or v_wallet.held_balance<v_request.reserved_amount then raise exception 'تعذر العثور على المبلغ المحجوز لهذا الطلب'; end if;
    update public.client_wallets set held_balance=held_balance-v_request.reserved_amount,updated_at=now() where user_id=v_user_id;
  end if;

  update public.custom_appointment_requests
  set status='مؤكد',selected_option=p_option_index,expired_waiting_on=null,expired_at=null,updated_at=now()
  where id=v_request.id;

  insert into public.bookings(
    user_id,lawyer_id,status,scheduled_at,price,consultation_type,consultation_mode,
    manual_payment_required,payment_required,payment_confirmed_at,payment_waived_at,payment_waiver_reason,
    description,document_url,whatsapp_number,package_name,package_description,package_duration_minutes,
    consultation_status,lawyer_approved,lawyer_approved_at
  ) values(
    v_user_id,v_request.lawyer_id,case when v_request.payment_required then 'قيد معالجة الدفع' else 'مؤكد' end,
    v_start,v_request.price,v_request.consultation_type,v_request.consultation_mode,false,v_request.payment_required,
    case when v_request.payment_required then now() else null end,
    case when v_request.payment_required then null else now() end,
    case when v_request.payment_required then null else 'free_beta' end,
    v_request.description,v_request.document_url,v_whatsapp,v_request.package_name,v_request.package_description,
    v_request.duration_minutes,'لم تبدأ',true,now()
  ) returning * into v_booking;

  if v_request.payment_required then
    insert into public.client_wallet_ledger(user_id,amount,entry_type,appointment_request_id,booking_id,balance_after,idempotency_key)
    values(v_user_id,0,'appointment_capture',v_request.id,v_booking.id,v_wallet.available_balance,'appointment:'||v_request.id||':capture');
    insert into public.payments(booking_id,amount,payment_method,transaction_number,status,verified_at,is_manual)
    values(v_booking.id,v_request.price,'wallet','wallet-'||v_booking.id,'تم الدفع',now(),false);
  end if;

  update public.custom_appointment_requests set booking_id=v_booking.id,updated_at=now() where id=v_request.id;
  select * into v_booking from public.bookings where id=v_booking.id;
  return v_booking;
end;
$function$;

revoke all on function public.is_lawyer_time_blocked(uuid,timestamptz,integer,uuid) from public,anon;
grant execute on function public.is_lawyer_time_blocked(uuid,timestamptz,integer,uuid) to authenticated;
revoke all on function public.appointment_response_deadline(text) from public,anon;
grant execute on function public.appointment_response_deadline(text) to authenticated;