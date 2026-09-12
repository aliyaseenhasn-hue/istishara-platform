-- Admin no-show financial settlement.
-- Lawyer absence => full client refund.
-- Client absence => configurable percentage retained as lawyer compensation and the rest refunded.

alter table public.platform_financial_settings
  add column if not exists client_no_show_penalty_rate numeric(6,2) not null default 20;

alter table public.platform_financial_settings
  drop constraint if exists platform_financial_settings_client_no_show_penalty_rate_check;
alter table public.platform_financial_settings
  add constraint platform_financial_settings_client_no_show_penalty_rate_check
  check (client_no_show_penalty_rate > 0 and client_no_show_penalty_rate < 100);

alter table public.no_show_review_requests
  add column if not exists paid_amount numeric(18,2),
  add column if not exists penalty_rate numeric(6,2),
  add column if not exists penalty_amount numeric(18,2) not null default 0,
  add column if not exists refund_amount numeric(18,2) not null default 0,
  add column if not exists currency text,
  add column if not exists financial_status text not null default 'not_started',
  add column if not exists client_credit_id uuid references public.client_credits(id) on delete set null,
  add column if not exists settlement_id uuid references public.client_credit_settlements(id) on delete set null,
  add column if not exists refund_reference text,
  add column if not exists refunded_at timestamptz;

alter table public.no_show_review_requests
  drop constraint if exists no_show_review_requests_penalty_rate_check;
alter table public.no_show_review_requests
  add constraint no_show_review_requests_penalty_rate_check
  check (penalty_rate is null or (penalty_rate >= 0 and penalty_rate < 100));

alter table public.no_show_review_requests
  drop constraint if exists no_show_review_requests_financial_amounts_check;
alter table public.no_show_review_requests
  add constraint no_show_review_requests_financial_amounts_check
  check (coalesce(penalty_amount,0) >= 0 and coalesce(refund_amount,0) >= 0 and (paid_amount is null or paid_amount >= 0));

alter table public.financial_ledger drop constraint if exists financial_ledger_entry_type_check;
alter table public.financial_ledger add constraint financial_ledger_entry_type_check check (
  entry_type = any(array[
    'payment_gross','platform_commission','lawyer_earning','lawyer_earning_settlement',
    'lawyer_penalty','client_credit','refund','payout','lawyer_cancellation_compensation',
    'client_no_show_compensation'
  ]::text[])
);

create or replace function public.ensure_client_refund_credit_for_booking()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_payment public.payments%rowtype;
  v_currency text:='IQD';
  v_has_account boolean:=false;
begin
  if new.status='بانتظار الاسترداد' and old.status is distinct from new.status then
    if new.cancellation_source in ('client_cancellation_request','no_show_lawyer','no_show_client') then
      return new;
    end if;

    select * into v_payment
    from public.payments
    where booking_id=new.id and status='تم الدفع'
    order by created_at desc limit 1;
    if found then
      select coalesce(currency,'IQD') into v_currency from public.platform_financial_settings where id=true;
      insert into public.client_credits(user_id,booking_id,lawyer_id,amount,currency,transaction_type,status,reference_id)
      values(new.user_id,new.id,new.lawyer_id,v_payment.amount,v_currency,'استرداد قيمة استشارة','مستحق',v_payment.id)
      on conflict (booking_id,transaction_type) where booking_id is not null do nothing;

      select exists(
        select 1 from public.client_payout_accounts a
        where a.user_id=new.user_id and a.is_default=true and a.account_number<>'REMOVED'
          and nullif(trim(coalesce(a.account_number,'')),'') is not null
      ) into v_has_account;

      perform public.enqueue_user_notification(
        new.user_id,
        case when v_has_account then 'تم إنشاء طلب استرداد' else 'أضف حساب استلام لإكمال الاسترداد' end,
        case when v_has_account then
          'تم تسجيل قيمة الاستشارة للاسترداد بعد اكتمال القرار. ستقوم الإدارة بتحويلها إلى حساب الاستلام المرتبط.'
        else
          'تم تسجيل قيمة الاستشارة للاسترداد، لكن لا يوجد حساب استلام مرتبط. أضف حساب استلام لإكمال التحويل.'
        end,
        case when v_has_account then 'client_refund_pending' else 'client_refund_account_required' end,
        new.id,'booking'
      );
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.admin_review_no_show_request_financial(
  p_request_id uuid,
  p_decision text,
  p_note text default null,
  p_penalty_rate numeric default null
)
returns void
language plpgsql
security definer
set search_path to 'public','pg_catalog'
as $$
declare
  v_admin uuid;
  v_request public.no_show_review_requests%rowtype;
  v_booking public.bookings%rowtype;
  v_payment public.payments%rowtype;
  v_has_paid boolean:=false;
  v_pending_manual boolean:=false;
  v_restore_status text;
  v_restore_consultation text;
  v_paid numeric(18,2):=0;
  v_penalty_rate numeric(6,2):=0;
  v_penalty numeric(18,2):=0;
  v_refund numeric(18,2):=0;
  v_currency text:='IQD';
  v_credit_id uuid;
  v_settlement_id uuid;
  v_has_account boolean:=false;
  v_ledger_inserted uuid;
begin
  select id into v_admin from public.profiles where auth_id=auth.uid() and role='admin' limit 1;
  if v_admin is null then raise exception 'غير مصرح'; end if;
  if p_decision not in ('approved','rejected') then raise exception 'قرار غير صالح'; end if;

  select * into v_request from public.no_show_review_requests where id=p_request_id for update;
  if not found then raise exception 'الطلب غير موجود'; end if;
  if v_request.status<>'pending' then raise exception 'تمت مراجعة الطلب مسبقاً'; end if;

  select * into v_booking from public.bookings where id=v_request.booking_id for update;
  if not found then raise exception 'الحجز المرتبط بالطلب غير موجود'; end if;
  if v_booking.status<>'بانتظار مراجعة عدم الحضور' then raise exception 'الحجز لم يعد بانتظار مراجعة عدم الحضور'; end if;

  if p_decision='rejected' then
    v_restore_status:=coalesce(nullif(v_request.previous_booking_status,''),'مؤكد');
    v_restore_consultation:=coalesce(
      nullif(v_request.previous_consultation_status,''),
      case when v_restore_status='قيد التنفيذ' then 'قيد التنفيذ' else 'لم تبدأ' end
    );

    update public.no_show_review_requests
    set status='rejected',reviewed_by=v_admin,review_note=nullif(trim(coalesce(p_note,'')),''),reviewed_at=now(),
        financial_status='not_applicable'
    where id=p_request_id;

    update public.bookings set status=v_restore_status,consultation_status=v_restore_consultation where id=v_booking.id;
    perform public.enqueue_user_notification(
      v_request.reporter_id,'تم رفض بلاغ عدم الحضور',
      'راجعت الإدارة البلاغ وتم رفضه، وأُعيدت الاستشارة إلى حالتها السابقة.',
      'no_show_rejected',v_booking.id,'booking'
    );
    return;
  end if;

  select * into v_payment
  from public.payments
  where booking_id=v_booking.id and status='تم الدفع'
  order by coalesce(verified_at,created_at) desc, created_at desc
  limit 1;
  v_has_paid := found;

  select exists(
    select 1 from public.payments
    where booking_id=v_booking.id and status='قيد معالجة الدفع'
      and coalesce(is_manual,false)
      and nullif(trim(coalesce(receipt_url,'')),'') is not null
  ) into v_pending_manual;

  if v_pending_manual and not v_has_paid then
    raise exception 'يجب حسم إثبات الدفع أولاً قبل اعتماد بلاغ عدم الحضور';
  end if;

  if v_request.reason='عدم حضور طالب الاستشارة' and v_booking.payment_required and not v_has_paid then
    raise exception 'لا يمكن تطبيق استقطاع عدم الحضور قبل تأكيد دفع قيمة الاستشارة';
  end if;

  select coalesce(currency,'IQD') into v_currency from public.platform_financial_settings where id=true;

  if v_has_paid then
    v_paid:=round(coalesce(v_payment.amount,0)::numeric,2);
  end if;

  if v_request.reason='عدم حضور المحامي' then
    v_penalty_rate:=0;
    v_penalty:=0;
    v_refund:=v_paid;
  elsif v_request.reason='عدم حضور طالب الاستشارة' then
    select coalesce(client_no_show_penalty_rate,20)
      into v_penalty_rate
    from public.platform_financial_settings where id=true;
    v_penalty_rate:=coalesce(p_penalty_rate,v_penalty_rate,20);
    if v_penalty_rate<=0 or v_penalty_rate>=100 then
      raise exception 'نسبة استقطاع عدم حضور طالب الاستشارة يجب أن تكون أكبر من 0 وأقل من 100';
    end if;
    v_penalty:=round(v_paid*v_penalty_rate/100,2);
    v_refund:=greatest(v_paid-v_penalty,0);
  else
    raise exception 'نوع بلاغ عدم الحضور غير معروف';
  end if;

  if v_has_paid then
    perform public.reverse_financial_accounting_for_refund(v_payment.id);
  end if;

  if v_request.reason='عدم حضور طالب الاستشارة' and v_penalty>0 then
    insert into public.financial_ledger(
      payment_id,booking_id,client_id,lawyer_id,entry_type,amount,currency,reference_id,idempotency_key,metadata
    ) values(
      v_payment.id,v_booking.id,v_booking.user_id,v_booking.lawyer_id,
      'client_no_show_compensation',v_penalty,v_currency,p_request_id,
      'no_show:'||p_request_id||':lawyer_compensation',
      jsonb_build_object('penalty_rate',v_penalty_rate,'reason','client_no_show')
    ) on conflict(idempotency_key) do nothing returning id into v_ledger_inserted;

    if v_ledger_inserted is not null then
      insert into public.lawyer_wallets(lawyer_id,available_balance,pending_balance,lifetime_earned,currency,updated_at)
      values(v_booking.lawyer_id,v_penalty,0,v_penalty,v_currency,now())
      on conflict(lawyer_id) do update set
        available_balance=public.lawyer_wallets.available_balance+excluded.available_balance,
        lifetime_earned=public.lawyer_wallets.lifetime_earned+excluded.lifetime_earned,
        updated_at=now();
    end if;
  end if;

  if v_refund>0 then
    insert into public.client_credits(
      user_id,booking_id,lawyer_id,amount,currency,transaction_type,status,reference_id
    ) values(
      v_booking.user_id,v_booking.id,v_booking.lawyer_id,v_refund,v_currency,
      case when v_request.reason='عدم حضور المحامي'
           then 'استرداد قيمة استشارة'
           else 'استرداد جزئي لعدم حضور طالب الاستشارة' end,
      'مستحق',case when v_has_paid then v_payment.id else null end
    ) on conflict (booking_id,transaction_type) where booking_id is not null
    do update set amount=excluded.amount,currency=excluded.currency,status='مستحق',reference_id=excluded.reference_id
    returning id into v_credit_id;

    select exists(
      select 1 from public.client_payout_accounts a
      where a.user_id=v_booking.user_id and a.is_default=true and a.account_number<>'REMOVED'
        and nullif(trim(coalesce(a.account_number,'')),'') is not null
    ) into v_has_account;

    if v_has_account then
      v_settlement_id:=public.admin_prepare_client_credit_settlement(v_credit_id);
    end if;
  end if;

  update public.bookings
  set status=case when v_refund>0 then 'بانتظار الاسترداد' else 'ملغي' end,
      consultation_status=case when v_request.reason='عدم حضور المحامي'
        then 'عدم حضور المحامي - تمت الموافقة'
        else 'عدم حضور طالب الاستشارة - تمت الموافقة' end,
      cancelled_at=coalesce(cancelled_at,now()),
      cancellation_reason=case when v_request.reason='عدم حضور المحامي' then 'عدم حضور المحامي' else 'عدم حضور طالب الاستشارة' end,
      cancelled_by_profile_id=case when v_request.reason='عدم حضور المحامي' then v_booking.lawyer_id else v_booking.user_id end,
      cancellation_actor_role=case when v_request.reason='عدم حضور المحامي' then 'lawyer' else 'client' end,
      cancellation_source=case when v_request.reason='عدم حضور المحامي' then 'no_show_lawyer' else 'no_show_client' end
  where id=v_booking.id;

  update public.no_show_review_requests
  set status='approved',reviewed_by=v_admin,review_note=nullif(trim(coalesce(p_note,'')),''),reviewed_at=now(),
      paid_amount=v_paid,penalty_rate=v_penalty_rate,penalty_amount=v_penalty,refund_amount=v_refund,
      currency=v_currency,client_credit_id=v_credit_id,settlement_id=v_settlement_id,
      financial_status=case
        when v_refund<=0 then 'no_refund_due'
        when v_settlement_id is not null then 'ready_to_refund'
        else 'awaiting_payout_account'
      end
  where id=p_request_id;

  if v_request.reason='عدم حضور المحامي' then
    perform public.enqueue_user_notification(
      v_booking.user_id,'تم اعتماد عدم حضور المحامي',
      case when v_refund>0 then 'تم اعتماد البلاغ. قيمة الاستشارة كاملة ('||trim(to_char(v_refund,'FM999999999999990'))||' د.ع) بانتظار التحويل إليك.'
           else 'تم اعتماد البلاغ وإلغاء الاستشارة، ولا يوجد مبلغ مدفوع يحتاج إلى استرداد.' end,
      'no_show_refund_pending',v_booking.id,'booking'
    );
    perform public.enqueue_user_notification(
      v_booking.lawyer_id,'تم اعتماد بلاغ عدم الحضور',
      'اعتمدت الإدارة بلاغ عدم الحضور المقدم ضدك لهذه الاستشارة.',
      'no_show_approved',v_booking.id,'booking'
    );
  else
    perform public.enqueue_user_notification(
      v_booking.user_id,'تم اعتماد عدم حضور طالب الاستشارة',
      'تم استقطاع '||trim(to_char(v_penalty_rate,'FM990D00'))||'% ('||trim(to_char(v_penalty,'FM999999999999990'))||' د.ع) وإعادة الباقي '||trim(to_char(v_refund,'FM999999999999990'))||' د.ع وفق قرار الإدارة.',
      'no_show_partial_refund',v_booking.id,'booking'
    );
    perform public.enqueue_user_notification(
      v_booking.lawyer_id,'تم اعتماد عدم حضور طالب الاستشارة',
      'تم اعتماد البلاغ وإضافة تعويض عدم الحضور بقيمة '||trim(to_char(v_penalty,'FM999999999999990'))||' د.ع إلى رصيدك.',
      'no_show_approved',v_booking.id,'booking'
    );
  end if;
end;
$$;

create or replace function public.admin_review_no_show_request(
  p_request_id uuid,p_decision text,p_note text default null
)
returns void
language plpgsql
security definer
set search_path to 'public','pg_catalog'
as $$
begin
  perform public.admin_review_no_show_request_financial(p_request_id,p_decision,p_note,null);
end;
$$;

create or replace function public.admin_complete_no_show_refund(
  p_request_id uuid,
  p_provider_reference text,
  p_admin_note text default null
)
returns void
language plpgsql
security definer
set search_path to 'public','pg_catalog'
as $$
declare
  v_request public.no_show_review_requests%rowtype;
  v_settlement_id uuid;
begin
  if not public.is_admin() then raise exception 'غير مصرح'; end if;
  if nullif(trim(coalesce(p_provider_reference,'')),'') is null then raise exception 'رقم مرجع التحويل مطلوب'; end if;

  select * into v_request from public.no_show_review_requests where id=p_request_id for update;
  if not found then raise exception 'البلاغ غير موجود'; end if;
  if v_request.status<>'approved' then raise exception 'يجب اعتماد البلاغ أولاً'; end if;
  if coalesce(v_request.refund_amount,0)<=0 or v_request.client_credit_id is null then raise exception 'لا يوجد مبلغ استرداد مستحق لهذا البلاغ'; end if;
  if v_request.financial_status='refunded' or v_request.refunded_at is not null then raise exception 'تم تسجيل تحويل هذا الاسترداد مسبقاً'; end if;

  v_settlement_id:=v_request.settlement_id;
  if v_settlement_id is null then
    v_settlement_id:=public.admin_prepare_client_credit_settlement(v_request.client_credit_id);
  end if;

  perform public.admin_complete_client_credit_settlement(v_settlement_id,p_provider_reference,p_admin_note);

  if v_request.reason='عدم حضور طالب الاستشارة' then
    update public.bookings
    set status='مسترد'
    where id=v_request.booking_id and status='بانتظار الاسترداد';
  end if;

  update public.no_show_review_requests
  set settlement_id=v_settlement_id,financial_status='refunded',
      refund_reference=trim(p_provider_reference),refunded_at=now()
  where id=p_request_id;
end;
$$;

create or replace function public.admin_list_no_show_reviews_financial()
returns table(
  id uuid,booking_id uuid,reporter_id uuid,reason text,evidence_url text,status text,
  created_at timestamptz,review_note text,reviewed_at timestamptz,
  booking_status text,consultation_status text,scheduled_at timestamptz,booking_price numeric,
  payment_required boolean,client_name text,lawyer_name text,payment_id uuid,payment_status text,
  paid_amount numeric,currency text,transaction_number text,penalty_rate numeric,penalty_amount numeric,
  refund_amount numeric,financial_status text,client_credit_id uuid,settlement_id uuid,
  settlement_status text,provider_type text,account_holder_name text,account_number text,bank_name text,
  refund_reference text,refunded_at timestamptz,default_penalty_rate numeric
)
language sql
security definer
set search_path to 'public','pg_catalog'
as $$
  select
    n.id,n.booking_id,n.reporter_id,n.reason,n.evidence_url,n.status,n.created_at,n.review_note,n.reviewed_at,
    b.status,b.consultation_status,b.scheduled_at,b.price,b.payment_required,
    coalesce(nullif(trim(cp.full_name),''),'طالب الاستشارة'),
    coalesce(nullif(trim(lp.full_name),''),'المحامي'),
    pay.id,pay.status,
    coalesce(n.paid_amount,pay.amount,0),
    coalesce(n.currency,fs.currency,'IQD'),pay.transaction_number,
    n.penalty_rate,n.penalty_amount,n.refund_amount,n.financial_status,n.client_credit_id,
    coalesce(n.settlement_id,s.id),s.status,
    coalesce(s.provider_type,a.provider_type),coalesce(s.account_holder_name,a.account_holder_name),
    coalesce(s.account_number,a.account_number),coalesce(s.bank_name,a.bank_name),
    n.refund_reference,n.refunded_at,coalesce(fs.client_no_show_penalty_rate,20)
  from public.no_show_review_requests n
  join public.bookings b on b.id=n.booking_id
  left join public.profiles cp on cp.id=b.user_id
  left join public.profiles lp on lp.id=b.lawyer_id
  left join lateral (
    select p.id,p.status,p.amount,p.transaction_number
    from public.payments p
    where p.booking_id=b.id
    order by (p.status='تم الدفع') desc,coalesce(p.verified_at,p.created_at) desc,p.created_at desc
    limit 1
  ) pay on true
  left join public.client_credits c on c.id=n.client_credit_id
  left join public.client_credit_settlements s on s.credit_id=c.id
  left join public.client_payout_accounts a on a.user_id=b.user_id and a.is_default=true
  left join public.platform_financial_settings fs on fs.id=true
  where public.is_admin()
  order by (n.status='pending') desc,n.created_at desc;
$$;

revoke all on function public.admin_review_no_show_request_financial(uuid,text,text,numeric) from public,anon;
revoke all on function public.admin_complete_no_show_refund(uuid,text,text) from public,anon;
revoke all on function public.admin_list_no_show_reviews_financial() from public,anon;
grant execute on function public.admin_review_no_show_request_financial(uuid,text,text,numeric) to authenticated;
grant execute on function public.admin_complete_no_show_refund(uuid,text,text) to authenticated;
grant execute on function public.admin_list_no_show_reviews_financial() to authenticated;
