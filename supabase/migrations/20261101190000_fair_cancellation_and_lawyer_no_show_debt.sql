-- Fair cancellation rules, lawyer no-show debt and hardening (2026-11-01)
-- ---------------------------------------------------------------------------
-- 1) Client cancellation is decided automatically by time, no admin review:
--      >= client_free_cancellation_hours (24h) before the appointment -> full refund
--      later -> client_late_cancellation_penalty_rate (20%) goes to the lawyer
--    Bookings with an unverified manual receipt still go to admin review.
-- 2) An approved lawyer no-show now creates a DEBT on the lawyer
--    (lawyer_no_show_penalty_rate, 20% of the lawyer price). It is collected
--    from the lawyer's next completed consultation and then paid to the client
--    as compensation (same mechanism as lawyer cancellation penalties).
--    Reaching lawyer_no_show_suspend_after approved no-shows within 90 days
--    hides the lawyer (availability=false) and notifies him and the admins.
-- 3) A lawyer cannot withdraw the part of his balance that covers open debts.
-- 4) Penalties are computed on the lawyer price, not on the platform fee.
-- 5) WhatsApp is optional for booking (in-app chat is the primary channel),
--    while unavailable/suspended lawyers can no longer be booked.
-- 6) A payment confirmed after its booking was cancelled is refunded in full
--    instead of failing (late gateway callbacks).
-- 7) The push webhook authorization headers move from trigger definitions to
--    Supabase Vault (the two triggers are replaced in place under the same names).
-- Each function patch must match exactly once or the migration aborts.
-- ---------------------------------------------------------------------------

-- Settings --------------------------------------------------------------------
alter table public.platform_financial_settings
  add column if not exists client_free_cancellation_hours integer not null default 24,
  add column if not exists client_late_cancellation_penalty_rate numeric(5,2) not null default 20,
  add column if not exists lawyer_no_show_penalty_rate numeric(5,2) not null default 20,
  add column if not exists lawyer_no_show_suspend_after integer not null default 2;

do $$
begin
  if not exists (select 1 from pg_constraint where conname='platform_financial_settings_cancellation_rules_check') then
    alter table public.platform_financial_settings add constraint platform_financial_settings_cancellation_rules_check
      check (client_free_cancellation_hours between 0 and 720
         and client_late_cancellation_penalty_rate between 0 and 100
         and lawyer_no_show_penalty_rate between 0 and 100
         and lawyer_no_show_suspend_after >= 1);
  end if;
end $$;

-- Penalty base: the lawyer price when the client paid a platform service fee.
create or replace function public.booking_penalty_base(p_booking_id uuid, p_paid numeric)
returns numeric
language sql
stable
security definer
set search_path to 'public', 'pg_catalog'
as $function$
  select case
    when b.fee_model_snapshot='client_service_fee' and b.lawyer_price is not null
      then least(coalesce(p_paid,0), b.lawyer_price)
    else coalesce(p_paid,0)
  end
  from public.bookings b where b.id=p_booking_id;
$function$;
revoke all on function public.booking_penalty_base(uuid, numeric) from public, anon, authenticated;

create or replace function pg_temp.istishara_patch_fn(p_fn regprocedure, p_old text, p_new text)
returns void
language plpgsql
as $function$
declare
  v_def text := pg_get_functiondef(p_fn);
  v_count integer;
begin
  v_count := (length(v_def) - length(replace(v_def, p_old, ''))) / greatest(length(p_old), 1);
  if v_count <> 1 then
    raise exception 'patch for % expected exactly 1 match, found %: %', p_fn, v_count, left(p_old, 120);
  end if;
  execute replace(v_def, p_old, p_new);
end;
$function$;

-- 1+4) finalize_client_cancellation_financials: use the request's rate and the
--      lawyer-price base (previously a fixed 1% of the full payment).
select pg_temp.istishara_patch_fn(
  'public.finalize_client_cancellation_financials(uuid)'::regprocedure,
  '    v_penalty:=round(v_payment.amount * 0.01,2);',
  '    v_penalty:=round(public.booking_penalty_base(v_booking.id, v_payment.amount) * coalesce(nullif(v_req.penalty_rate,0),1) / 100,2);'
);
select pg_temp.istishara_patch_fn(
  'public.finalize_client_cancellation_financials(uuid)'::regprocedure,
  'v_booking.lawyer_id,v_payment.amount,1,v_penalty,',
  'v_booking.lawyer_id,v_payment.amount,coalesce(nullif(v_req.penalty_rate,0),1),v_penalty,'
);
select pg_temp.istishara_patch_fn(
  'public.finalize_client_cancellation_financials(uuid)'::regprocedure,
  E'jsonb_build_object(\'penalty_rate\',1,',
  E'jsonb_build_object(\'penalty_rate\',coalesce(nullif(v_req.penalty_rate,0),1),'
);
select pg_temp.istishara_patch_fn(
  'public.finalize_client_cancellation_financials(uuid)'::regprocedure,
  E'set penalty_rate=case when decision=\'الموافقة مع غرامة\' then 1 else 0 end,',
  E'set penalty_rate=case when decision=\'الموافقة مع غرامة\' then coalesce(nullif(penalty_rate,0),1) else 0 end,'
);

-- 1) request_client_booking_cancellation: decide automatically by time.
create or replace function public.request_client_booking_cancellation(p_booking_id uuid, p_reason text)
returns public.bookings
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_profile uuid;
  v_booking public.bookings%rowtype;
  v_paid boolean;
  v_pending_manual boolean;
  v_new_status text;
  v_request public.cancellation_requests%rowtype;
  v_admin record;
  s public.platform_financial_settings%rowtype;
  v_hours numeric;
  v_late boolean;
  v_rate numeric := 0;
  v_refund numeric := 0;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  if nullif(trim(coalesce(p_reason,'')),'') is null then raise exception 'سبب الإلغاء إلزامي'; end if;
  select id into v_profile from public.profiles where auth_id=auth.uid() limit 1;
  select * into v_booking from public.bookings where id=p_booking_id for update;
  if not found then raise exception 'الحجز غير موجود'; end if;
  if v_booking.user_id<>v_profile then raise exception 'غير مصرح بهذا الإجراء'; end if;
  if v_booking.status not in ('قيد انتظار الدفع','قيد معالجة الدفع','قيد مراجعة المحامي','بانتظار التأكيد','مؤكد') then raise exception 'لا يمكن إلغاء الحجز في حالته الحالية'; end if;
  if v_booking.scheduled_at is not null and v_booking.scheduled_at<=now() then raise exception 'لا يمكن إلغاء موعد بدأ أو انتهى'; end if;
  if exists(select 1 from public.cancellation_requests where booking_id=p_booking_id and requester_role='client' and status='بانتظار مراجعة الإدارة') then
    raise exception 'طلب الإلغاء قيد مراجعة الإدارة بالفعل';
  end if;

  select exists(select 1 from public.payments p where p.booking_id=v_booking.id and p.status='تم الدفع') into v_paid;
  select exists(select 1 from public.payments p where p.booking_id=v_booking.id and p.status='قيد معالجة الدفع' and coalesce(p.is_manual,false) and nullif(trim(coalesce(p.receipt_url,'')),'') is not null) into v_pending_manual;
  v_new_status:=case when v_paid or v_pending_manual then 'بانتظار الاسترداد' else 'ملغي' end;

  select * into s from public.platform_financial_settings where id=true;
  v_hours := extract(epoch from (v_booking.scheduled_at - now()))/3600;
  v_late := v_hours < coalesce(s.client_free_cancellation_hours,24);
  if v_paid and v_late then
    v_rate := coalesce(s.client_late_cancellation_penalty_rate,20);
  end if;

  -- The decision is stored before the booking changes so booking
  -- notifications already see the final (non-pending) decision.
  insert into public.cancellation_requests(booking_id,lawyer_id,client_id,reason,requester_role,status,decision,penalty_rate,reviewed_at)
  values(
    v_booking.id,v_booking.lawyer_id,v_booking.user_id,trim(p_reason),'client',
    case when v_pending_manual and not v_paid then 'بانتظار مراجعة الإدارة'
         when v_rate>0 then 'تمت الموافقة مع غرامة' else 'تمت الموافقة' end,
    case when v_pending_manual and not v_paid then null
         when v_rate>0 then 'الموافقة مع غرامة' else 'الموافقة بدون غرامة' end,
    v_rate,
    case when v_pending_manual and not v_paid then null else now() end
  )
  returning * into v_request;

  update public.bookings
  set status=v_new_status,
      cancelled_at=coalesce(cancelled_at,now()),
      cancellation_reason=trim(p_reason),
      cancelled_by_profile_id=v_profile,
      cancellation_actor_role='client',
      cancellation_source='client_cancellation_request',
      cancellation_request_id=v_request.id
  where id=v_booking.id
  returning * into v_booking;

  if v_pending_manual and not v_paid then
    -- A receipt is still being verified: keep the manual review path.
    perform public.enqueue_user_notification(
      v_booking.lawyer_id,'ألغى العميل الحجز',
      'ألغى طالب الاستشارة الحجز. السبب: '||trim(p_reason)||'.',
      'booking_cancelled_by_client',v_booking.id,'booking'
    );
    perform public.enqueue_user_notification(
      v_booking.user_id,'طلب الإلغاء قيد مراجعة الإدارة',
      'تم إلغاء الموعد. إيصال الدفع ما زال قيد التحقق، وستحدد الإدارة الاسترداد بعد مطابقته.',
      'client_cancellation_pending_review',v_booking.id,'booking'
    );
    for v_admin in select id from public.profiles where role::text in ('admin','super_admin') loop
      perform public.enqueue_user_notification(
        v_admin.id,'طلب إلغاء من العميل يحتاج مراجعة',
        'ألغى طالب الاستشارة حجزاً لديه إيصال دفع قيد التحقق.',
        'client_cancellation_admin_review',v_request.id,'cancellation_request'
      );
    end loop;
    return v_booking;
  end if;

  perform public.finalize_client_cancellation_financials(v_booking.id);
  select * into v_request from public.cancellation_requests where id=v_request.id;
  select coalesce(sum(amount),0) into v_refund from public.client_credits
  where booking_id=v_booking.id and transaction_type='استرداد قيمة استشارة';

  perform public.enqueue_user_notification(
    v_booking.user_id,'تم إلغاء الحجز',
    case
      when not v_paid then 'تم إلغاء الموعد، ولا توجد دفعة مؤكدة لاستردادها.'
      when coalesce(v_request.penalty_amount,0)>0 then
        'ألغيت قبل الموعد بأقل من '||coalesce(s.client_free_cancellation_hours,24)||' ساعة، فاستُقطع '||trim(to_char(v_rate,'FM990'))||'% ('||trim(to_char(v_request.penalty_amount,'FM999999999990'))||' د.ع) لصالح المحامي. سيُعاد إليك '||trim(to_char(v_refund,'FM999999999990'))||' د.ع.'
      else 'تم الإلغاء في الوقت المسموح، وسيُعاد إليك كامل المبلغ ('||trim(to_char(v_refund,'FM999999999990'))||' د.ع).'
    end,
    'client_cancellation_reviewed',v_booking.id,'booking'
  );
  perform public.enqueue_user_notification(
    v_booking.lawyer_id,'ألغى العميل الحجز',
    'ألغى طالب الاستشارة الحجز. السبب: '||trim(p_reason)||'.'||
    case when coalesce(v_request.penalty_amount,0)>0
      then ' أُضيف إلى رصيدك تعويض الإلغاء المتأخر: '||trim(to_char(v_request.penalty_amount,'FM999999999990'))||' د.ع.'
      else '' end,
    'booking_cancelled_by_client',v_booking.id,'booking'
  );
  return v_booking;
end
$function$;

-- Booking notifications: remaining admin-review path is only for unverified receipts.
select pg_temp.istishara_patch_fn(
  'public.notify_booking_events()'::regprocedure,
  E'\'تم إلغاء الموعد، لكن مبلغ الاسترداد النهائي لم يُحدد بعد. ستراجع الإدارة سبب الإلغاء لتحديد استرداد 100% أو 99% مع غرامة 1% للمحامي.\'',
  E'\'تم إلغاء الموعد، وستراجع الإدارة إيصال الدفع لتحديد مبلغ الاسترداد.\''
);
select pg_temp.istishara_patch_fn(
  'public.notify_booking_events()'::regprocedure,
  E'\'ألغى العميل الموعد، وستراجع الإدارة السبب لتحديد ما إذا كانت غرامة 1% ستسجل لصالحك.\'',
  E'\'ألغى العميل الموعد، وما زال إيصال الدفع قيد تحقق الإدارة.\''
);

-- 2+4) admin_review_no_show_request_financial: lawyer debt + penalty base.
select pg_temp.istishara_patch_fn(
  'public.admin_review_no_show_request_financial(uuid,text,text,numeric)'::regprocedure,
  '  v_ledger_inserted uuid;',
  E'  v_ledger_inserted uuid;\n  v_lawyer_rate numeric(6,2):=0;\n  v_lawyer_penalty numeric(18,2):=0;\n  v_lawyer_penalty_id uuid;\n  v_penalty_request_id uuid;\n  v_suspend_after integer:=2;\n  v_strikes integer:=0;\n  v_admin_row record;'
);
select pg_temp.istishara_patch_fn(
  'public.admin_review_no_show_request_financial(uuid,text,text,numeric)'::regprocedure,
  '    v_penalty:=round(v_paid*v_penalty_rate/100,2);',
  '    v_penalty:=round(public.booking_penalty_base(v_booking.id,v_paid)*v_penalty_rate/100,2);'
);
select pg_temp.istishara_patch_fn(
  'public.admin_review_no_show_request_financial(uuid,text,text,numeric)'::regprocedure,
  E'  update public.bookings\n  set status=case when v_refund>0 then \'بانتظار الاسترداد\' else \'ملغي\' end,',
  E'  -- Lawyer no-show: record a debt collected from his next consultation and\n  -- paid to the client as compensation once collected.\n  if v_request.reason=\'عدم حضور المحامي\' and v_booking.payment_required then\n    select coalesce(lawyer_no_show_penalty_rate,20),coalesce(lawyer_no_show_suspend_after,2)\n      into v_lawyer_rate,v_suspend_after\n    from public.platform_financial_settings where id=true;\n    v_lawyer_penalty:=round(coalesce(v_booking.lawyer_price,v_booking.price,0)*v_lawyer_rate/100,2);\n    if v_lawyer_penalty>0 then\n      -- Recorded like an approved lawyer cancellation with penalty, so it reuses\n      -- the existing debt collection and client compensation flow.\n      insert into public.cancellation_requests(booking_id,lawyer_id,client_id,reason,requester_role,status,decision,penalty_rate,penalty_amount,reviewed_at,reviewed_by,currency)\n      values(v_booking.id,v_booking.lawyer_id,v_booking.user_id,\'غياب المحامي عن الاستشارة\',\'lawyer\',\'بانتظار تحصيل الغرامة\',\'الموافقة مع غرامة\',v_lawyer_rate,v_lawyer_penalty,now(),v_admin,v_currency)\n      returning id into v_penalty_request_id;\n      insert into public.lawyer_penalties(cancellation_request_id,booking_id,lawyer_id,client_id,amount,remaining_amount,currency)\n      values(v_penalty_request_id,v_booking.id,v_booking.lawyer_id,v_booking.user_id,v_lawyer_penalty,v_lawyer_penalty,v_currency)\n      returning id into v_lawyer_penalty_id;\n      if v_lawyer_penalty_id is not null then\n        insert into public.client_credits(user_id,booking_id,lawyer_id,amount,currency,transaction_type,status,reference_id)\n        values(v_booking.user_id,v_booking.id,v_booking.lawyer_id,v_lawyer_penalty,v_currency,\'تعويض غياب المحامي\',\'بانتظار تحصيل الغرامة\',v_lawyer_penalty_id)\n        on conflict (booking_id,transaction_type) where booking_id is not null do nothing;\n        perform public.enqueue_user_notification(\n          v_booking.lawyer_id,\'مبلغ مطلوب منك بسبب الغياب\',\n          \'سُجّل عليك مبلغ \'||trim(to_char(v_lawyer_penalty,\'FM999999999990\'))||\' د.ع (\'||trim(to_char(v_lawyer_rate,\'FM990\'))||\'% من سعر الاستشارة) بسبب الغياب، ويُستقطع من استشارتك القادمة لصالح العميل.\',\n          \'lawyer_no_show_penalty\',v_booking.id,\'booking\'\n        );\n      end if;\n    end if;\n\n    select count(*) into v_strikes\n    from public.no_show_review_requests n\n    join public.bookings b2 on b2.id=n.booking_id\n    where b2.lawyer_id=v_booking.lawyer_id\n      and n.reason=\'عدم حضور المحامي\'\n      and (n.status=\'approved\' or n.id=p_request_id)\n      and coalesce(n.reviewed_at,now()) > now()-interval \'90 days\';\n    if v_strikes>=v_suspend_after then\n      update public.lawyer_profiles set availability=false where profile_id=v_booking.lawyer_id and availability;\n      if found then\n        perform public.enqueue_user_notification(\n          v_booking.lawyer_id,\'تم إخفاء ملفك مؤقتاً\',\n          \'تكرر الغياب عن الاستشارات خلال آخر 90 يوماً، فأُخفي ملفك من البحث. تواصل مع الإدارة لإعادة التفعيل.\',\n          \'lawyer_suspended_no_show\',v_booking.id,\'booking\'\n        );\n        for v_admin_row in select id from public.profiles where role::text in (\'admin\',\'super_admin\') loop\n          perform public.enqueue_user_notification(\n            v_admin_row.id,\'إخفاء محامٍ بسبب تكرار الغياب\',\n            \'تم إخفاء محامٍ تلقائياً بعد \'||v_strikes||\' حالات غياب معتمدة خلال 90 يوماً.\',\n            \'lawyer_suspended_no_show\',v_booking.id,\'booking\'\n          );\n        end loop;\n      end if;\n    end if;\n  end if;\n\n  update public.bookings\n  set status=case when v_refund>0 then \'بانتظار الاسترداد\' else \'ملغي\' end,'
);

-- 2) Collected no-show debts release the client's compensation too.
select pg_temp.istishara_patch_fn(
  'public.settle_oldest_lawyer_penalties_for_completed_booking(uuid)'::regprocedure,
  E'        and transaction_type = \'تعويض إلغاء حجز من المحامي\';',
  E'        and transaction_type in (\'تعويض إلغاء حجز من المحامي\',\'تعويض غياب المحامي\');'
);

-- 3) Payouts cannot spend the part of the balance that covers open debts.
select pg_temp.istishara_patch_fn(
  'public.request_lawyer_payout(numeric)'::regprocedure,
  '  v_scheduled_date date;',
  E'  v_scheduled_date date;\n  v_debt numeric(18,2):=0;'
);
select pg_temp.istishara_patch_fn(
  'public.request_lawyer_payout(numeric)'::regprocedure,
  E'  if v_wallet.available_balance<p_amount then raise exception \'الرصيد المتاح غير كافٍ\'; end if;',
  E'  if v_wallet.available_balance<p_amount then raise exception \'الرصيد المتاح غير كافٍ\'; end if;\n  select coalesce(sum(remaining_amount),0) into v_debt from public.lawyer_penalties where lawyer_id=v_lawyer and remaining_amount>0;\n  if v_debt>0 and v_wallet.available_balance-v_debt<p_amount then\n    raise exception using message=\'عليك مبلغ مطلوب \'||trim(to_char(v_debt,\'FM999999999990\'))||\' د.ع؛ الحد الأقصى المتاح للسحب الآن \'||trim(to_char(greatest(0,v_wallet.available_balance-v_debt),\'FM999999999990\'))||\' د.ع\';\n  end if;'
);

-- 5) WhatsApp optional; unavailable lawyers cannot be booked.
select pg_temp.istishara_patch_fn(
  'public.create_booking(uuid,timestamp with time zone,text,text,text,text,text,uuid,text)'::regprocedure,
  E'  if v_whatsapp is null then raise exception \'يجب إضافة رقم واتساب في الملف الشخصي قبل طلب الاستشارة\'; end if;\n',
  ''
);
select pg_temp.istishara_patch_fn(
  'public.create_booking(uuid,timestamp with time zone,text,text,text,text,text,uuid,text)'::regprocedure,
  E'  if v_mode=\'عن بعد\' and v_lawyer_whatsapp is null then raise exception \'لا يمكن طلب استشارة عن بعد قبل أن يضيف المحامي رقم واتساب للتواصل\'; end if;',
  E'  if not exists(select 1 from public.lawyer_profiles lp where lp.profile_id=p_lawyer_id and lp.verified=true and lp.availability=true) then\n    raise exception \'المحامي غير متاح لاستقبال الحجوزات حالياً\';\n  end if;'
);
select pg_temp.istishara_patch_fn(
  'public.submit_custom_appointment_request(uuid,text,text,text,text,text,jsonb)'::regprocedure,
  E'  if v_whatsapp is null then raise exception \'أضف رقم واتساب في الملف الشخصي أولاً\'; end if;\n',
  ''
);
select pg_temp.istishara_patch_fn(
  'public.submit_custom_appointment_request(uuid,text,text,text,text,text,jsonb)'::regprocedure,
  E'  if v_mode=\'عن بعد\' and v_lawyer_whatsapp is null then raise exception \'المحامي لم يضف رقم التواصل بعد\'; end if;\n',
  ''
);

-- 6) Late payment on a cancelled booking -> full refund instead of an error.
select pg_temp.istishara_patch_fn(
  'public.sync_booking_from_payment()'::regprocedure,
  E'    if v_booking.status not in (\'قيد معالجة الدفع\',\'قيد انتظار الدفع\',\'قيد مراجعة المحامي\') then\n      raise exception \'لا يمكن اعتماد الدفع في حالة الحجز الحالية\';',
  E'    if v_booking.status=\'ملغي\' then\n      -- Payment confirmed after the booking was cancelled (for example a late\n      -- gateway callback): keep the money traceable and refund it in full.\n      update public.bookings set status=\'بانتظار الاسترداد\' where id=new.booking_id;\n      select coalesce(currency,\'IQD\') into v_currency from public.platform_financial_settings where id=true;\n      insert into public.client_credits(user_id,booking_id,lawyer_id,amount,currency,transaction_type,status,reference_id)\n      values(v_booking.user_id,v_booking.id,v_booking.lawyer_id,new.amount,v_currency,\'استرداد قيمة استشارة\',\'مستحق\',new.id)\n      on conflict (booking_id,transaction_type) where booking_id is not null do nothing;\n      return new;\n    end if;\n\n    if v_booking.status not in (\'قيد معالجة الدفع\',\'قيد انتظار الدفع\',\'قيد مراجعة المحامي\') then\n      raise exception \'لا يمكن اعتماد الدفع في حالة الحجز الحالية\';'
);

-- 7) Push webhook headers -> Vault ------------------------------------------
do $vault$
declare
  v_def text;
  v_headers text;
begin
  if not exists (select 1 from vault.secrets where name='notification_push_headers') then
    select pg_get_triggerdef(t.oid) into v_def
    from pg_trigger t
    where t.tgrelid='public.notifications'::regclass
      and t.tgname='send-native-push-on-notification'
      and not t.tgisinternal;
    if v_def is null then
      raise exception 'Native push trigger not found and no Vault secret exists; refusing to continue';
    end if;
    v_headers := (regexp_match(v_def, $re$http_request\('[^']+',\s*'POST',\s*'([^']+)'$re$))[1];
    if v_headers is null or v_headers='' then
      raise exception 'Could not recover the push webhook headers';
    end if;
    perform v_headers::jsonb;
    perform vault.create_secret(v_headers,'notification_push_headers','Authorization headers for push notification edge functions');
  end if;
end
$vault$;

create or replace function public.dispatch_notification_push()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $function$
declare
  v_headers jsonb;
  v_payload jsonb;
begin
  select decrypted_secret::jsonb into v_headers
  from vault.decrypted_secrets where name='notification_push_headers' limit 1;
  if v_headers is null then
    return new;
  end if;

  -- Same payload shape as Supabase database webhooks.
  v_payload := jsonb_build_object(
    'old_record', null,
    'record', to_jsonb(new),
    'type', tg_op,
    'table', tg_table_name,
    'schema', tg_table_schema
  );

  -- tg_argv[0] is the edge function URL.
  perform net.http_post(
    url := tg_argv[0],
    body := v_payload,
    params := '{}'::jsonb,
    headers := v_headers,
    timeout_milliseconds := 10000
  );
  return new;
end;
$function$;
revoke all on function public.dispatch_notification_push() from public, anon, authenticated;

-- Replace the two webhook triggers in place: same names, no secret inside.
create or replace trigger "send-native-push-on-notification"
  after insert on public.notifications
  for each row execute function public.dispatch_notification_push('https://iidxqrnrazkyfgzelzhb.supabase.co/functions/v1/send-native-push');
create or replace trigger "send-pwa-push-on-notification"
  after insert on public.notifications
  for each row execute function public.dispatch_notification_push('https://iidxqrnrazkyfgzelzhb.supabase.co/functions/v1/send-pwa-push');
