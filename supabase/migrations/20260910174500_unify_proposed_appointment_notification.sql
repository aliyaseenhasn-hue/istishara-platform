create or replace function public.submit_custom_appointment_request(
  p_lawyer_id uuid,
  p_package_name text,
  p_consultation_type text,
  p_consultation_mode text,
  p_description text,
  p_document_url text,
  p_client_windows jsonb
) returns public.custom_appointment_requests
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_user_id uuid; v_whatsapp text; v_lawyer_name text; v_lawyer_whatsapp text;
  v_package jsonb; v_price numeric; v_duration integer:=30; v_package_description text;
  v_type text:=case when trim(coalesce(p_consultation_type,''))='مرئية' then 'فيديو' else trim(coalesce(p_consultation_type,'')) end;
  v_mode text:=trim(coalesce(p_consultation_mode,'عن بعد'));
  v_free_beta boolean; v_payments_enabled boolean; v_manual_enabled boolean;
  v_payment_required boolean; v_wallet public.client_wallets%rowtype; v_balance numeric;
  v_item jsonb; v_start timestamptz; v_end timestamptz; v_request public.custom_appointment_requests;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  perform public.expire_stale_custom_appointment_requests();
  select id,nullif(trim(whatsapp_number),'') into v_user_id,v_whatsapp from public.profiles
  where auth_id=auth.uid() and role='user' and status='active' limit 1;
  if v_user_id is null then raise exception 'طلب الموعد متاح لطالب الاستشارة فقط'; end if;
  if v_whatsapp is null then raise exception 'أضف رقم واتساب في الملف الشخصي أولاً'; end if;

  select coalesce(nullif(trim(p.full_name),''),'المحامي'),
         coalesce(nullif(trim(lp.whatsapp),''),nullif(trim(p.whatsapp_number),'')),
         lp.consultation_price
  into v_lawyer_name,v_lawyer_whatsapp,v_price
  from public.profiles p join public.lawyer_profiles lp on lp.profile_id=p.id
  where p.id=p_lawyer_id and p.role='lawyer' and p.status='active'
    and lp.verified=true and lp.availability=true;
  if not found then raise exception 'المحامي غير متاح لاستقبال الطلبات'; end if;
  if v_mode not in ('عن بعد','في المكتب') then raise exception 'طريقة التنفيذ غير صالحة'; end if;
  if v_mode='عن بعد' and v_lawyer_whatsapp is null then raise exception 'المحامي لم يضف رقم التواصل بعد'; end if;
  if v_type not in ('نصية','صوتية','فيديو') then raise exception 'نوع الاستشارة غير صالح'; end if;

  if lower(trim(coalesce(p_package_name,'')))<>lower('استشارة مختلفة') then
    select elem into v_package
    from public.lawyer_profiles lp,
      lateral jsonb_array_elements(coalesce(lp.services,'[]'::jsonb)) elem
    where lp.profile_id=p_lawyer_id
      and lower(coalesce(elem->>'title',''))=lower(trim(p_package_name)) limit 1;
    if v_package is null then raise exception 'الخدمة المحددة غير متاحة'; end if;
    v_price:=nullif(v_package->>'price','')::numeric;
    v_duration:=coalesce(nullif(v_package->>'duration_minutes','')::integer,30);
    v_package_description:=v_package->>'description';
  end if;
  if v_price is null or v_price<=0 then raise exception 'سعر الاستشارة غير محدد'; end if;

  if jsonb_typeof(p_client_windows)<>'array'
     or jsonb_array_length(p_client_windows)<1
     or jsonb_array_length(p_client_windows)>3 then
    raise exception 'حدد من فترة واحدة إلى ثلاث فترات مناسبة';
  end if;
  for v_item in select value from jsonb_array_elements(p_client_windows) loop
    begin
      v_start:=(v_item->>'start')::timestamptz;
      v_end:=(v_item->>'end')::timestamptz;
    exception when others then raise exception 'إحدى الفترات المقترحة غير صالحة'; end;
    if v_start<=now()+interval '30 minutes' or v_end<=v_start or v_end-v_start>interval '12 hours' then
      raise exception 'يجب أن تكون الفترات مستقبلية وواضحة ولا تتجاوز 12 ساعة';
    end if;
  end loop;

  select free_beta_enabled,payments_enabled into v_free_beta,v_payments_enabled
  from public.app_release_settings where id=true;
  select enabled into v_manual_enabled from public.manual_payment_settings where id=true;
  v_payment_required:=not coalesce(v_free_beta,false);
  if v_payment_required and not (coalesce(v_payments_enabled,false) and coalesce(v_manual_enabled,false)) then
    raise exception 'الحجوزات المدفوعة متوقفة مؤقتاً';
  end if;

  if v_payment_required then
    select * into v_wallet from public.client_wallets where user_id=v_user_id for update;
    if not found or v_wallet.available_balance<v_price then
      raise exception 'رصيد المحفظة غير كافٍ لإرسال طلب الموعد';
    end if;
    update public.client_wallets
    set available_balance=available_balance-v_price,held_balance=held_balance+v_price,updated_at=now()
    where user_id=v_user_id returning available_balance into v_balance;
  end if;

  insert into public.custom_appointment_requests(
    user_id,lawyer_id,package_name,package_description,consultation_type,consultation_mode,
    description,document_url,price,duration_minutes,payment_required,reserved_amount,client_windows
  ) values(
    v_user_id,p_lawyer_id,coalesce(nullif(trim(p_package_name),''),'استشارة مختلفة'),
    v_package_description,v_type,v_mode,nullif(trim(coalesce(p_description,'')),''),p_document_url,
    case when v_payment_required then v_price else 0 end,v_duration,v_payment_required,
    case when v_payment_required then v_price else 0 end,p_client_windows
  ) returning * into v_request;

  if v_payment_required then
    insert into public.client_wallet_ledger(
      user_id,amount,entry_type,appointment_request_id,balance_after,idempotency_key
    ) values(
      v_user_id,-v_price,'appointment_hold',v_request.id,v_balance,
      'appointment:'||v_request.id||':hold'
    );
  end if;
  perform public.enqueue_user_notification(
    p_lawyer_id,'طلب موعد جديد',
    'حدد طالب الاستشارة أوقاتاً مناسبة له. اختر وقتاً منها أو اقترح مواعيد بديلة خلال 12 ساعة.',
    'appointment_request_new',v_request.id,'appointment_request'
  );
  return v_request;
end;
$function$;
