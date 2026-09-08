create or replace function public.get_booking_participant_identity(p_booking_id uuid)
returns table(
  client_name text,
  client_avatar_url text,
  lawyer_name text,
  lawyer_avatar_url text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    coalesce(nullif(trim(client.full_name), ''), 'طالب استشارة') as client_name,
    client.avatar_url as client_avatar_url,
    coalesce(nullif(trim(lawyer.full_name), ''), 'المحامي') as lawyer_name,
    lawyer.avatar_url as lawyer_avatar_url
  from public.bookings b
  join public.profiles client on client.id = b.user_id
  join public.profiles lawyer on lawyer.id = b.lawyer_id
  where b.id = p_booking_id
    and exists (
      select 1
      from public.profiles me
      where me.auth_id = auth.uid()
        and me.id in (b.user_id, b.lawyer_id)
    );
$$;

revoke all on function public.get_booking_participant_identity(uuid) from public;
grant execute on function public.get_booking_participant_identity(uuid) to authenticated;

create or replace function public.notify_booking_events()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    perform public.enqueue_user_notification(NEW.user_id,'تم إرسال طلب الاستشارة','تم إنشاء طلب الاستشارة بنجاح، وسيتم إشعارك عند تحديث حالته.','booking',NEW.id,'booking');
    perform public.enqueue_user_notification(NEW.lawyer_id,'طلب استشارة جديد','وصل طلب استشارة جديد من أحد طالبي الاستشارة.','booking',NEW.id,'booking');
    return NEW;
  end if;

  if NEW.status is distinct from OLD.status then
    perform public.enqueue_user_notification(
      NEW.user_id,
      case NEW.status
        when 'قيد مراجعة المحامي' then 'طلبك قيد مراجعة المحامي'
        when 'مؤكد' then 'تم تأكيد الاستشارة'
        when 'قيد التنفيذ' then 'بدأت الاستشارة'
        when 'مكتمل' then 'اكتملت الاستشارة'
        when 'ملغي' then 'تم إلغاء الاستشارة'
        when 'مسترد' then 'تم استرداد المبلغ'
        when 'بانتظار الاسترداد' then 'طلب الاسترداد قيد المعالجة'
        else 'تم تحديث حالة الحجز'
      end,
      'تم تحديث حالة حجز الاستشارة.','booking',NEW.id,'booking');
    perform public.enqueue_user_notification(NEW.lawyer_id,'تحديث حجز طالب الاستشارة','تم تحديث حالة أحد الحجوزات في لوحة المحامي.','booking',NEW.id,'booking');
  end if;

  if NEW.manual_received_at is distinct from OLD.manual_received_at and NEW.manual_received_at is not null then
    perform public.enqueue_user_notification(NEW.user_id,'تم تسجيل الدفع اليدوي','تم تسجيل مبلغ الاستشارة المستلم يدوياً من المحامي.','payment',NEW.id,'booking');
  end if;
  return NEW;
end;
$$;

create or replace function public.notify_custom_request_events()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    perform public.enqueue_user_notification(NEW.user_id, 'تم إرسال طلب الاستشارة', 'تم إرسال طلب الاستشارة المخصص بنجاح.', 'booking');
    perform public.enqueue_user_notification(NEW.lawyer_id, 'طلب استشارة مخصص جديد', 'وصلك طلب استشارة مخصص جديد من طالب استشارة.', 'booking');
  elsif NEW.status is distinct from OLD.status then
    perform public.enqueue_user_notification(
      NEW.user_id,
      case NEW.status when 'مقبول' then 'تم قبول طلب الاستشارة' when 'مرفوض' then 'تم رفض طلب الاستشارة' when 'ملغي' then 'تم إلغاء طلب الاستشارة' when 'مكتمل' then 'اكتمل طلب الاستشارة' else 'تم تحديث طلب الاستشارة' end,
      case NEW.status when 'مقبول' then 'وافق المحامي على طلب الاستشارة.' when 'مرفوض' then 'اعتذر المحامي عن قبول طلب الاستشارة.' when 'ملغي' then 'تم إلغاء طلب الاستشارة.' when 'مكتمل' then 'تم إكمال طلب الاستشارة.' else 'تم تحديث حالة طلب الاستشارة.' end,
      'booking'
    );
    perform public.enqueue_user_notification(NEW.lawyer_id, 'تحديث طلب الاستشارة', 'تم تحديث حالة أحد طلبات الاستشارة المخصصة.', 'booking');
  end if;
  return NEW;
end;
$$;

create or replace function public.notify_payment_events()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_lawyer_id uuid;
begin
  select user_id, lawyer_id into v_user_id, v_lawyer_id
  from public.bookings where id = coalesce(NEW.booking_id, OLD.booking_id);

  if tg_op = 'INSERT' or NEW.status is distinct from OLD.status then
    perform public.enqueue_user_notification(
      v_user_id,
      case NEW.status
        when 'تم الدفع' then 'تم تأكيد الدفع'
        when 'فشل الدفع' then 'فشل الدفع'
        when 'قيد معالجة الدفع' then 'الدفع قيد المعالجة'
        when 'تم استرداد المبلغ' then 'تم استرداد المبلغ'
        else 'تحديث حالة الدفع'
      end,
      case NEW.status
        when 'تم الدفع' then 'تم تسجيل الدفع بنجاح لحجز الاستشارة.'
        when 'فشل الدفع' then 'تعذر تأكيد عملية الدفع. يرجى مراجعة تفاصيل الدفع.'
        when 'قيد معالجة الدفع' then 'عملية الدفع قيد المعالجة وسيتم تحديثك عند اكتمال التحقق.'
        when 'تم استرداد المبلغ' then 'تم تسجيل استرداد المبلغ.'
        else 'تم تحديث حالة الدفع المرتبط بحجزك.'
      end,
      'payment'
    );
    if NEW.status = 'تم الدفع' then
      perform public.enqueue_user_notification(v_lawyer_id, 'تم استلام الدفع', 'تم تأكيد دفع طالب الاستشارة المرتبط بأحد حجوزاتك.', 'payment');
    end if;
  end if;
  return NEW;
end;
$$;

create or replace function public.report_booking_no_show(p_booking_id uuid)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_profile_id uuid;
  v_booking public.bookings%rowtype;
  v_now timestamptz := now();
  v_reference_at timestamptz;
  v_reason text;
begin
  if v_actor is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  select id into v_profile_id from public.profiles where auth_id = v_actor limit 1;
  if v_profile_id is null then raise exception 'ملف المستخدم غير مكتمل'; end if;

  select * into v_booking from public.bookings where id = p_booking_id for update;
  if not found then raise exception 'الحجز غير موجود'; end if;

  if v_booking.lawyer_id = v_profile_id then
    if v_booking.status = 'مؤكد' then
      v_reference_at := v_booking.scheduled_at;
    elsif v_booking.status = 'قيد التنفيذ' and v_booking.started_at is not null then
      v_reference_at := v_booking.started_at;
    else
      raise exception 'لا يمكن تسجيل عدم حضور طالب الاستشارة في هذه الحالة';
    end if;
    if v_now < v_reference_at + interval '10 minutes' then
      raise exception 'يمكن تسجيل عدم حضور طالب الاستشارة بعد مرور 10 دقائق من الموعد أو بدء الاستشارة';
    end if;
    v_reason := 'عدم حضور طالب الاستشارة';
    update public.bookings
      set status = 'بانتظار مراجعة عدم الحضور', consultation_status = v_reason
      where id = p_booking_id
      returning * into v_booking;
    insert into public.no_show_review_requests (booking_id, reporter_id, reason, status)
      values (p_booking_id, v_profile_id, v_reason, 'pending')
      on conflict do nothing;

  elsif v_booking.user_id = v_profile_id then
    if v_booking.status <> 'مؤكد' or v_booking.started_at is not null then
      raise exception 'لا يمكن تسجيل عدم حضور المحامي بعد بدء الاستشارة';
    end if;
    if v_now < v_booking.scheduled_at + interval '10 minutes' then
      raise exception 'يمكن تسجيل عدم حضور المحامي بعد مرور 10 دقائق من الموعد';
    end if;
    v_reason := 'عدم حضور المحامي';
    update public.bookings
      set status = 'بانتظار مراجعة عدم الحضور', consultation_status = v_reason
      where id = p_booking_id
      returning * into v_booking;
    insert into public.no_show_review_requests (booking_id, reporter_id, reason, status)
      values (p_booking_id, v_profile_id, v_reason, 'pending')
      on conflict do nothing;
  else
    raise exception 'غير مصرح بهذا الإجراء';
  end if;

  return v_booking;
end;
$$;
