alter table public.custom_appointment_requests
  add column if not exists negotiation_round integer not null default 1,
  add column if not exists rejected_by text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname='custom_appointment_requests_negotiation_round_check'
      and conrelid='public.custom_appointment_requests'::regclass
  ) then
    alter table public.custom_appointment_requests
      add constraint custom_appointment_requests_negotiation_round_check
      check (negotiation_round between 1 and 3);
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname='custom_appointment_requests_rejected_by_check'
      and conrelid='public.custom_appointment_requests'::regclass
  ) then
    alter table public.custom_appointment_requests
      add constraint custom_appointment_requests_rejected_by_check
      check (rejected_by is null or rejected_by in ('client','lawyer'));
  end if;
end $$;

create or replace function public.lawyer_respond_custom_appointment_request(
  p_request_id uuid,
  p_options jsonb default null,
  p_reject_reason text default null
)
returns public.custom_appointment_requests
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_lawyer_id uuid; v_request public.custom_appointment_requests;
  v_item jsonb; v_start timestamptz; v_balance numeric;
  v_option_text text := '';
  v_option_count integer := 0;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  perform public.expire_stale_custom_appointment_requests();
  select id into v_lawyer_id from public.profiles
  where auth_id=auth.uid() and role='lawyer' and status='active' limit 1;
  select * into v_request from public.custom_appointment_requests
  where id=p_request_id and lawyer_id=v_lawyer_id for update;
  if not found then raise exception 'طلب الموعد غير موجود'; end if;
  if v_request.status<>'بانتظار رد المحامي' or v_request.expires_at<=now() then
    raise exception 'انتهت مهلة الرد على هذا الطلب';
  end if;

  if nullif(trim(coalesce(p_reject_reason,'')),'') is not null then
    if v_request.reserved_amount>0 then
      update public.client_wallets set
        available_balance=available_balance+v_request.reserved_amount,
        held_balance=greatest(0,held_balance-v_request.reserved_amount),updated_at=now()
      where user_id=v_request.user_id returning available_balance into v_balance;
      insert into public.client_wallet_ledger(
        user_id,amount,entry_type,appointment_request_id,balance_after,idempotency_key
      ) values(
        v_request.user_id,v_request.reserved_amount,'appointment_release',v_request.id,v_balance,
        'appointment:'||v_request.id||':rejected-release'
      ) on conflict(idempotency_key) do nothing;
    end if;
    update public.custom_appointment_requests set
      status='مرفوض',rejection_reason=trim(p_reject_reason),rejected_by='lawyer',updated_at=now()
    where id=v_request.id returning * into v_request;
    perform public.enqueue_user_notification(
      v_request.user_id,'تعذر قبول طلب الموعد',
      'رفض المحامي الطلب نهائياً، وأُعيد المبلغ المحجوز إلى رصيدك.',
      'appointment_request_rejected',v_request.id,'appointment_request'
    );
    return v_request;
  end if;

  if jsonb_typeof(p_options)<>'array' or jsonb_array_length(p_options)<1 or jsonb_array_length(p_options)>3 then
    raise exception 'اقترح من موعد واحد إلى ثلاثة مواعيد';
  end if;
  for v_item in select value from jsonb_array_elements(p_options) loop
    begin v_start:=(v_item->>'start')::timestamptz;
    exception when others then raise exception 'أحد المواعيد المقترحة غير صالح'; end;
    if v_start<=now()+interval '30 minutes' then raise exception 'يجب أن يكون الموعد في المستقبل'; end if;
    if exists(
      select 1 from public.bookings b where b.lawyer_id=v_lawyer_id
      and b.status not in ('ملغي','مسترد','بانتظار الاسترداد','مكتمل')
      and tstzrange(b.scheduled_at,b.scheduled_at+make_interval(mins=>coalesce(b.package_duration_minutes,30)),'[)')
          && tstzrange(v_start,v_start+make_interval(mins=>v_request.duration_minutes),'[)')
    ) then raise exception 'أحد المواعيد المقترحة يتعارض مع حجز قائم'; end if;

    v_option_count := v_option_count + 1;
    v_option_text := v_option_text ||
      case when v_option_text='' then '' else '، ' end ||
      to_char(v_start at time zone 'Asia/Baghdad','YYYY/MM/DD HH24:MI');
  end loop;

  update public.custom_appointment_requests set
    lawyer_options=p_options,status='بانتظار اختيار العميل',selected_option=null,
    rejection_reason=null,rejected_by=null,expires_at=now()+interval '12 hours',updated_at=now()
  where id=v_request.id returning * into v_request;
  perform public.enqueue_user_notification(
    v_request.user_id,
    case when v_option_count=1 then 'موعد مقترح من المحامي' else 'مواعيد مقترحة من المحامي' end,
    case when v_option_count=1
      then 'اقترح المحامي الموعد '||v_option_text||'. افتح الطلب لقبوله أو تغييره أو رفضه خلال 12 ساعة.'
      else 'اقترح المحامي المواعيد '||v_option_text||'. افتح الطلب لقبول أحدها أو اقتراح تغيير أو الرفض خلال 12 ساعة.'
    end,
    'appointment_options_ready',v_request.id,'appointment_request'
  );
  return v_request;
end;
$$;

create or replace function public.client_respond_custom_appointment_request(
  p_request_id uuid,
  p_windows jsonb default null,
  p_reject_reason text default null
)
returns public.custom_appointment_requests
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_user_id uuid; v_request public.custom_appointment_requests;
  v_item jsonb; v_start timestamptz; v_end timestamptz; v_balance numeric;
  v_window_text text := ''; v_count integer := 0;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  perform public.expire_stale_custom_appointment_requests();
  select id into v_user_id from public.profiles
  where auth_id=auth.uid() and role='user' and status='active' limit 1;
  select * into v_request from public.custom_appointment_requests
  where id=p_request_id and user_id=v_user_id for update;
  if not found then raise exception 'طلب الموعد غير موجود'; end if;
  if v_request.status<>'بانتظار اختيار العميل' or v_request.expires_at<=now() then
    raise exception 'انتهت مهلة الرد على هذا الطلب';
  end if;

  if nullif(trim(coalesce(p_reject_reason,'')),'') is not null then
    if v_request.reserved_amount>0 then
      update public.client_wallets set
        available_balance=available_balance+v_request.reserved_amount,
        held_balance=greatest(0,held_balance-v_request.reserved_amount),updated_at=now()
      where user_id=v_user_id returning available_balance into v_balance;
      insert into public.client_wallet_ledger(
        user_id,amount,entry_type,appointment_request_id,balance_after,idempotency_key
      ) values(
        v_user_id,v_request.reserved_amount,'appointment_release',v_request.id,v_balance,
        'appointment:'||v_request.id||':client-rejected-release'
      ) on conflict(idempotency_key) do nothing;
    end if;
    update public.custom_appointment_requests set
      status='مرفوض',rejection_reason=trim(p_reject_reason),rejected_by='client',updated_at=now()
    where id=v_request.id returning * into v_request;
    perform public.enqueue_user_notification(
      v_request.lawyer_id,'رفض العميل الموعد المقترح',
      'رفض طالب الاستشارة المواعيد المقترحة وأنهى الطلب.',
      'appointment_request_rejected_by_client',v_request.id,'appointment_request'
    );
    return v_request;
  end if;

  if v_request.negotiation_round>=3 then
    raise exception 'وصل الطلب إلى الحد الأقصى لتعديل المواعيد؛ اختر موعداً أو ارفض الطلب';
  end if;
  if jsonb_typeof(p_windows)<>'array' or jsonb_array_length(p_windows)<1 or jsonb_array_length(p_windows)>3 then
    raise exception 'حدد من فترة واحدة إلى ثلاث فترات';
  end if;

  for v_item in select value from jsonb_array_elements(p_windows) loop
    begin
      v_start := (v_item->>'start')::timestamptz;
      v_end := (v_item->>'end')::timestamptz;
    exception when others then
      raise exception 'إحدى الفترات المقترحة غير صالحة';
    end;
    if v_start<=now()+interval '30 minutes' then raise exception 'يجب أن تبدأ الفترة في المستقبل'; end if;
    if v_end<=v_start then raise exception 'نهاية الفترة يجب أن تكون بعد بدايتها'; end if;
    if v_end-v_start>interval '12 hours' then raise exception 'الفترة الواحدة لا يمكن أن تتجاوز 12 ساعة'; end if;
    if v_end < v_start + make_interval(mins=>v_request.duration_minutes) then
      raise exception 'إحدى الفترات أقصر من مدة الاستشارة';
    end if;
    v_count := v_count + 1;
    v_window_text := v_window_text || case when v_window_text='' then '' else '، ' end ||
      to_char(v_start at time zone 'Asia/Baghdad','YYYY/MM/DD HH24:MI') || '–' ||
      to_char(v_end at time zone 'Asia/Baghdad','HH24:MI');
  end loop;

  update public.custom_appointment_requests set
    client_windows=p_windows,lawyer_options=null,selected_option=null,
    status='بانتظار رد المحامي',negotiation_round=negotiation_round+1,
    rejection_reason=null,rejected_by=null,expires_at=now()+interval '12 hours',updated_at=now()
  where id=v_request.id returning * into v_request;

  perform public.enqueue_user_notification(
    v_request.lawyer_id,
    case when v_count=1 then 'العميل اقترح وقتاً بديلاً' else 'العميل اقترح أوقاتاً بديلة' end,
    'الأوقات الجديدة: '||v_window_text||'. افتح الطلب لقبول وقت مناسب أو اقتراح بديل خلال 12 ساعة.',
    'appointment_client_counter_offer',v_request.id,'appointment_request'
  );
  return v_request;
end;
$$;

revoke all on function public.client_respond_custom_appointment_request(uuid,jsonb,text) from public,anon;
grant execute on function public.client_respond_custom_appointment_request(uuid,jsonb,text) to authenticated;
