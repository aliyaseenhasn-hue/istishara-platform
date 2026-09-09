create or replace function public.notify_booking_events()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
  v_client_name text;
  v_lawyer_name text;
  v_type text;
  v_service text;
  v_mode text;
  v_when text;
  v_amount text;
  v_client_cancel_pending boolean:=false;
begin
  select coalesce(nullif(trim(full_name),''),'طالب الاستشارة') into v_client_name from public.profiles where id=NEW.user_id;
  select coalesce(nullif(trim(full_name),''),'المحامي') into v_lawyer_name from public.profiles where id=NEW.lawyer_id;
  v_client_name:=coalesce(v_client_name,'طالب الاستشارة');
  v_lawyer_name:=coalesce(v_lawyer_name,'المحامي');
  v_type:=coalesce(nullif(trim(NEW.consultation_type),''),'استشارة قانونية');
  v_service:=coalesce(nullif(trim(NEW.package_name),''),'استشارة قانونية');
  v_mode:=coalesce(nullif(trim(NEW.consultation_mode),''),'غير محدد');
  v_when:=case when NEW.scheduled_at is null then 'غير محدد' else to_char(NEW.scheduled_at at time zone 'Asia/Baghdad','YYYY/MM/DD HH24:MI') end;
  v_amount:=case when NEW.price is null then 'غير محدد' else trim(to_char(NEW.price,'FM999999999999990'))||' د.ع' end;

  if NEW.cancellation_source='client_cancellation_request' then
    select exists(
      select 1 from public.cancellation_requests cr
      where cr.id=NEW.cancellation_request_id
        and cr.requester_role='client'
        and cr.status='بانتظار مراجعة الإدارة'
    ) into v_client_cancel_pending;
  end if;

  if tg_op='INSERT' then
    perform public.enqueue_user_notification(NEW.user_id,'تم إرسال طلب الاستشارة','تم إرسال طلبك إلى '||v_lawyer_name||' • الخدمة: '||v_service||' • النوع: '||v_type||' • الموعد: '||v_when||' • المبلغ: '||v_amount,'booking',NEW.id,'booking');
    perform public.enqueue_user_notification(NEW.lawyer_id,'طلب استشارة جديد من '||v_client_name,'الخدمة: '||v_service||' • النوع: '||v_type||' • التنفيذ: '||v_mode||' • الموعد: '||v_when||' • المبلغ: '||v_amount||' • الحالة: '||coalesce(NEW.status,'غير محددة'),'booking',NEW.id,'booking');
    return NEW;
  end if;

  if NEW.status is distinct from OLD.status then
    perform public.enqueue_user_notification(
      NEW.user_id,
      case
        when NEW.status='بانتظار الاسترداد' and v_client_cancel_pending then 'طلب الإلغاء قيد مراجعة الإدارة'
        when NEW.status='قيد مراجعة المحامي' then 'طلبك قيد مراجعة المحامي'
        when NEW.status='مؤكد' then 'تم تأكيد الاستشارة'
        when NEW.status='قيد التنفيذ' then 'بدأت الاستشارة'
        when NEW.status='مكتمل' then 'اكتملت الاستشارة'
        when NEW.status='ملغي' then 'تم إلغاء الاستشارة'
        when NEW.status='مسترد' then 'تم استرداد المبلغ'
        when NEW.status='بانتظار الاسترداد' then 'طلب الاسترداد قيد المعالجة'
        else 'تم تحديث حالة الاستشارة'
      end,
      case
        when NEW.status='بانتظار الاسترداد' and v_client_cancel_pending then
          'تم إلغاء الموعد، لكن مبلغ الاسترداد النهائي لم يُحدد بعد. ستراجع الإدارة سبب الإلغاء لتحديد استرداد 100% أو 99% مع غرامة 1% للمحامي.'
        else
          'المحامي: '||v_lawyer_name||' • الخدمة: '||v_service||' • النوع: '||v_type||' • الموعد: '||v_when||' • الحالة: '||coalesce(NEW.status,'غير محددة')
      end,
      'booking',NEW.id,'booking'
    );

    perform public.enqueue_user_notification(
      NEW.lawyer_id,
      case when NEW.status='بانتظار الاسترداد' and v_client_cancel_pending then 'إلغاء العميل قيد مراجعة الإدارة' else 'تحديث استشارة '||v_client_name end,
      case when NEW.status='بانتظار الاسترداد' and v_client_cancel_pending then
        'ألغى العميل الموعد، وستراجع الإدارة السبب لتحديد ما إذا كانت غرامة 1% ستسجل لصالحك.'
      else
        'طالب الاستشارة: '||v_client_name||' • الخدمة: '||v_service||' • النوع: '||v_type||' • الموعد: '||v_when||' • الحالة: '||coalesce(NEW.status,'غير محددة')
      end,
      'booking',NEW.id,'booking'
    );
  end if;

  if NEW.manual_received_at is distinct from OLD.manual_received_at and NEW.manual_received_at is not null then
    v_amount:=case when NEW.manual_received_amount is null then 'غير محدد' else trim(to_char(NEW.manual_received_amount,'FM999999999999990'))||' د.ع' end;
    perform public.enqueue_user_notification(NEW.user_id,'تم تسجيل الدفع اليدوي','المحامي: '||v_lawyer_name||' • المبلغ: '||v_amount||' • الاستشارة: '||v_type||' • الموعد: '||v_when,'payment',NEW.id,'booking');
  end if;
  return NEW;
end $$;

update public.notifications n
set title='طلب الإلغاء قيد مراجعة الإدارة',
    body='تم إلغاء الموعد، لكن مبلغ الاسترداد النهائي لم يُحدد بعد. ستراجع الإدارة سبب الإلغاء لتحديد استرداد 100% أو 99% مع غرامة 1% للمحامي.'
where n.reference_type='booking'
  and n.type='booking'
  and n.reference_id in (
    select b.id from public.bookings b
    join public.cancellation_requests cr on cr.id=b.cancellation_request_id
    where b.cancellation_source='client_cancellation_request'
      and cr.requester_role='client'
      and cr.status='بانتظار مراجعة الإدارة'
  )
  and n.title='طلب الاسترداد قيد المعالجة';
