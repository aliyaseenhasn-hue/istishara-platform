create or replace function public.cancel_custom_appointment_request(p_request_id uuid)
returns public.custom_appointment_requests
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_user_id uuid;
  v_client_name text;
  v_request public.custom_appointment_requests;
  v_balance numeric;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  select id,coalesce(nullif(trim(full_name),''),'طالب الاستشارة')
  into v_user_id,v_client_name
  from public.profiles where auth_id=auth.uid() and status='active' limit 1;
  select * into v_request from public.custom_appointment_requests
  where id=p_request_id and user_id=v_user_id for update;
  if not found then raise exception 'طلب الموعد غير موجود'; end if;
  if v_request.status not in ('بانتظار رد المحامي','بانتظار اختيار العميل') then
    raise exception 'لا يمكن إلغاء الطلب في حالته الحالية';
  end if;
  if v_request.reserved_amount>0 then
    update public.client_wallets set
      available_balance=available_balance+v_request.reserved_amount,
      held_balance=greatest(0,held_balance-v_request.reserved_amount),updated_at=now()
    where user_id=v_user_id returning available_balance into v_balance;
    insert into public.client_wallet_ledger(
      user_id,amount,entry_type,appointment_request_id,balance_after,idempotency_key
    ) values(
      v_user_id,v_request.reserved_amount,'appointment_release',v_request.id,v_balance,
      'appointment:'||v_request.id||':cancel-release'
    ) on conflict(idempotency_key) do nothing;
  end if;
  update public.custom_appointment_requests
  set status='ملغي',expired_waiting_on=null,expired_at=null,updated_at=now()
  where id=v_request.id returning * into v_request;
  perform public.enqueue_user_notification(
    v_request.lawyer_id,'ألغى '||v_client_name||' طلب الموعد',
    'ألغى طالب الاستشارة '||v_client_name||' طلب الموعد قبل تأكيده.',
    'appointment_request_cancelled',v_request.id,'appointment_request'
  );
  return v_request;
end;
$function$;