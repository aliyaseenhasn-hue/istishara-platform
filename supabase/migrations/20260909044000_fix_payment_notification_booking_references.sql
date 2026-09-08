create or replace function public.notify_payment_events()
returns trigger
language plpgsql
security definer
set search_path = public
as $function$
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
  v_booking_id uuid := coalesce(new.booking_id, old.booking_id);
begin
  select b.user_id,b.lawyer_id,b.price,b.consultation_type,b.scheduled_at,
         coalesce(nullif(trim(cp.full_name),''),'طالب الاستشارة'),
         coalesce(nullif(trim(lp.full_name),''),nullif(trim(lpp.full_name),''),'المحامي')
  into v_user_id,v_lawyer_id,v_price,v_type,v_scheduled_at,v_client_name,v_lawyer_name
  from public.bookings b
  left join public.profiles cp on cp.id=b.user_id
  left join public.lawyer_profiles lp on lp.profile_id=b.lawyer_id
  left join public.profiles lpp on lpp.id=b.lawyer_id
  where b.id=v_booking_id;

  v_date_text := case when v_scheduled_at is null then 'غير محدد'
    else to_char(v_scheduled_at at time zone 'Asia/Baghdad','YYYY/MM/DD HH24:MI') end;

  if tg_op='INSERT' or new.status is distinct from old.status then
    if new.status='قيد معالجة الدفع' and coalesce(new.is_manual,false) then
      perform public.enqueue_user_notification(
        v_user_id,
        'تم إرسال إثبات الدفع',
        'تم إرسال إيصال بقيمة '||coalesce(to_char(v_price,'FM999G999G999G990'),'0')||' د.ع لاستشارة '||coalesce(v_type,'قانونية')||' مع '||v_lawyer_name||' بتاريخ '||v_date_text||'. بانتظار تحقق الإدارة.',
        'manual_payment_submitted',v_booking_id,'booking');
      perform public.enqueue_user_notification(
        v_lawyer_id,
        'أرسل العميل إثبات الدفع',
        v_client_name||' أرسل إثبات دفع بقيمة '||coalesce(to_char(v_price,'FM999G999G999G990'),'0')||' د.ع لاستشارة '||coalesce(v_type,'قانونية')||' بتاريخ '||v_date_text||'. بانتظار تحقق الإدارة.',
        'manual_payment_submitted',v_booking_id,'booking');
      for v_admin in select id from public.profiles where role::text='admin' loop
        perform public.enqueue_user_notification(
          v_admin.id,
          'دفعة تحتاج مراجعة',
          v_client_name||' رفع إيصالاً بقيمة '||coalesce(to_char(v_price,'FM999G999G999G990'),'0')||' د.ع لحجز مع '||v_lawyer_name||' ('||coalesce(v_type,'استشارة قانونية')||') بتاريخ '||v_date_text||'.',
          'manual_payment_admin_review',v_booking_id,'booking');
      end loop;
    elsif new.status='تم الدفع' then
      perform public.enqueue_user_notification(
        v_user_id,'تم تأكيد الدفع',
        'تحققت الإدارة من دفع مبلغ '||coalesce(to_char(v_price,'FM999G999G999G990'),'0')||' د.ع لاستشارتك مع '||v_lawyer_name||'.',
        'payment_confirmed',v_booking_id,'booking');
      perform public.enqueue_user_notification(
        v_lawyer_id,'تم تأكيد دفع الاستشارة',
        'تحققت الإدارة من دفع '||v_client_name||' مبلغ '||coalesce(to_char(v_price,'FM999G999G999G990'),'0')||' د.ع للاستشارة بتاريخ '||v_date_text||'.',
        'payment_confirmed',v_booking_id,'booking');
    elsif new.status='فشل الدفع' then
      perform public.enqueue_user_notification(
        v_user_id,'تم رفض إثبات الدفع',
        'تعذر اعتماد إثبات دفع استشارتك مع '||v_lawyer_name||'. راجع بيانات التحويل وأعد المحاولة.',
        'payment_rejected',v_booking_id,'booking');
    elsif new.status='تم استرداد المبلغ' then
      perform public.enqueue_user_notification(
        v_user_id,'تم استرداد المبلغ','تم تسجيل استرداد مبلغ الاستشارة.',
        'payment_refunded',v_booking_id,'booking');
    end if;
  end if;
  return new;
end;
$function$;
