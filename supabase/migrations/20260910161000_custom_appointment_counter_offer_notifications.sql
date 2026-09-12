create or replace function public.lawyer_respond_custom_appointment_request(
  p_request_id uuid,
  p_options jsonb default null::jsonb,
  p_reject_reason text default null::text
) returns public.custom_appointment_requests
language plpgsql
security definer
set search_path to 'public'
as $function$
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
      );
    end if;
    update public.custom_appointment_requests set
      status='مرفوض',rejection_reason=trim(p_reject_reason),updated_at=now()
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
    lawyer_options=p_options,status='بانتظار اختيار العميل',expires_at=now()+interval '12 hours',updated_at=now()
  where id=v_request.id returning * into v_request;
  perform public.enqueue_user_notification(
    v_request.user_id,
    case when v_option_count=1 then 'موعد مقترح من المحامي' else 'مواعيد مقترحة من المحامي' end,
    case when v_option_count=1
      then 'اقترح المحامي الموعد '||v_option_text||'. افتح الطلب لتأكيده خلال 12 ساعة.'
      else 'اقترح المحامي المواعيد '||v_option_text||'. افتح الطلب واختر موعداً واحداً خلال 12 ساعة.'
    end,
    'appointment_options_ready',v_request.id,'appointment_request'
  );
  return v_request;
end;
$function$;
