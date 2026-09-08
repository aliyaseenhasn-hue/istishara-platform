create or replace function public.ensure_client_refund_credit_for_booking()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_payment public.payments%rowtype; v_currency text:='IQD';
begin
  if new.status='بانتظار الاسترداد' and old.status is distinct from new.status then
    select * into v_payment from public.payments where booking_id=new.id and status='تم الدفع' order by created_at desc limit 1;
    if found then
      select coalesce(currency,'IQD') into v_currency from public.platform_financial_settings where id=true;
      insert into public.client_credits(user_id,booking_id,lawyer_id,amount,currency,transaction_type,status,reference_id)
      values(new.user_id,new.id,new.lawyer_id,v_payment.amount,v_currency,'استرداد قيمة استشارة','مستحق',v_payment.id)
      on conflict(booking_id,transaction_type) where booking_id is not null do nothing;
      perform public.enqueue_user_notification(new.user_id,'تم إنشاء طلب استرداد','تم تسجيل قيمة الاستشارة المستحقة للاسترداد. سيتم تحويلها إلى حساب الاستلام المرتبط بعد معالجة الإدارة.','client_refund_pending',new.id,'booking');
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists trg_ensure_client_refund_credit_for_booking on public.bookings;
create trigger trg_ensure_client_refund_credit_for_booking after update of status on public.bookings for each row execute function public.ensure_client_refund_credit_for_booking();

create or replace function public.reverse_financial_accounting_for_refund(p_payment_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare pf public.payment_financials%rowtype; v_pending numeric(18,2);
begin
  select * into pf from public.payment_financials where payment_id=p_payment_id for update;
  if not found or pf.status='refunded' then return; end if;
  if pf.status<>'pending' then raise exception 'لا يمكن تنفيذ الاسترداد التلقائي بعد تسوية مستحقات المحامي؛ يلزم إجراء مالي إداري منفصل'; end if;
  select pending_balance into v_pending from public.lawyer_wallets where lawyer_id=pf.lawyer_id for update;
  if v_pending is null then raise exception 'محفظة المحامي غير موجودة'; end if;
  if v_pending<pf.lawyer_net_amount then raise exception 'الرصيد المعلق للمحامي لا يغطي عكس هذه العملية'; end if;
  update public.lawyer_wallets set pending_balance=pending_balance-pf.lawyer_net_amount,lifetime_earned=greatest(0,lifetime_earned-pf.lawyer_net_amount),updated_at=now() where lawyer_id=pf.lawyer_id;
  update public.payment_financials set status='refunded',updated_at=now() where payment_id=p_payment_id;
  insert into public.financial_ledger(payment_id,booking_id,client_id,lawyer_id,entry_type,amount,currency,idempotency_key,metadata)
  values(pf.payment_id,pf.booking_id,pf.client_id,pf.lawyer_id,'refund',pf.gross_amount,pf.currency,'payment:'||pf.payment_id||':refund',jsonb_build_object('lawyer_pending_reversed',pf.lawyer_net_amount))
  on conflict(idempotency_key) do nothing;
end;
$$;

create or replace function public.sync_financial_payment_trigger()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.status='تم الدفع' and (tg_op='INSERT' or old.status is distinct from new.status) then perform public.ensure_financial_accounting_for_payment(new.id);
  elsif new.status='تم استرداد المبلغ' and old.status is distinct from new.status then perform public.reverse_financial_accounting_for_refund(new.id);
  end if;
  return new;
end;
$$;

create or replace function public.sync_booking_from_payment()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_booking public.bookings%rowtype; v_verifier uuid;
begin
  select * into v_booking from public.bookings where id=new.booking_id for update;
  if not found then raise exception 'الحجز غير موجود'; end if;
  if not v_booking.payment_required then raise exception 'لا يمكن إنشاء أو اعتماد دفعة لحجز مجاني تجريبي'; end if;
  select id into v_verifier from public.profiles where auth_id=auth.uid() limit 1;
  if new.status='تم الدفع' then
    if v_booking.status not in ('قيد معالجة الدفع','قيد انتظار الدفع','قيد مراجعة المحامي') then raise exception 'لا يمكن اعتماد الدفع في حالة الحجز الحالية'; end if;
    new.verified_by:=v_verifier; new.verified_at:=now();
    update public.bookings set status=case when lawyer_approved then 'مؤكد' else 'قيد مراجعة المحامي' end where id=new.booking_id;
  elsif new.status='فشل الدفع' then
    if v_booking.status in ('ملغي','مرفوض') then new.verified_by:=coalesce(v_verifier,new.verified_by); new.verified_at:=coalesce(new.verified_at,now());
    elsif v_booking.status in ('قيد معالجة الدفع','قيد انتظار الدفع') then new.verified_by:=v_verifier; new.verified_at:=now(); update public.bookings set status='قيد انتظار الدفع' where id=new.booking_id;
    else raise exception 'لا يمكن رفض الدفع في حالة الحجز الحالية'; end if;
  elsif new.status='تم استرداد المبلغ' then
    if v_booking.status<>'بانتظار الاسترداد' then raise exception 'يجب أن يكون الحجز بانتظار الاسترداد قبل تسجيل رد المبلغ'; end if;
    new.verified_by:=v_verifier; new.verified_at:=now(); update public.bookings set status='مسترد' where id=new.booking_id;
  end if;
  return new;
end;
$$;