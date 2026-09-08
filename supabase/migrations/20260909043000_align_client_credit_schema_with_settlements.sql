alter table public.client_credits drop constraint if exists client_credits_status_chk;
alter table public.client_credits add constraint client_credits_status_chk check (status in ('مستحق','بانتظار تحصيل الغرامة','مستخدم','pending','بانتظار التحويل','قيد الانتظار','settled'));
alter table public.client_credits drop constraint if exists client_credits_booking_id_key;
create unique index if not exists client_credits_booking_type_unique on public.client_credits(booking_id,transaction_type) where booking_id is not null;

create or replace function public.admin_prepare_client_credit_settlement(p_credit_id uuid)
returns uuid language plpgsql security definer set search_path=public,pg_catalog as $$
declare v_credit public.client_credits%rowtype; v_account public.client_payout_accounts%rowtype; v_settlement_id uuid;
begin
  if not public.is_admin() then raise exception 'غير مصرح'; end if;
  select * into v_credit from public.client_credits where id=p_credit_id for update;
  if not found then raise exception 'الرصيد غير موجود'; end if;
  if v_credit.status not in ('pending','مستحق','بانتظار التحويل','قيد الانتظار') then raise exception 'هذا الرصيد لا يحتاج إلى تسوية'; end if;
  select * into v_account from public.client_payout_accounts where user_id=v_credit.user_id and is_default=true limit 1;
  if not found then raise exception 'العميل لم يحدد حساب استلام افتراضياً'; end if;
  if nullif(trim(coalesce(v_account.account_number,'')),'') is null or v_account.account_number='REMOVED' then raise exception 'حساب استلام العميل غير صالح'; end if;
  insert into public.client_credit_settlements(credit_id,user_id,amount,currency,payout_account_id,provider_type,account_holder_name,account_number,bank_name,status)
  values(v_credit.id,v_credit.user_id,v_credit.amount,v_credit.currency,v_account.id,v_account.provider_type,v_account.account_holder_name,v_account.account_number,v_account.bank_name,'pending')
  on conflict(credit_id) do update set payout_account_id=excluded.payout_account_id,provider_type=excluded.provider_type,account_holder_name=excluded.account_holder_name,account_number=excluded.account_number,bank_name=excluded.bank_name
  returning id into v_settlement_id;
  update public.client_credits set status='بانتظار التحويل' where id=v_credit.id;
  return v_settlement_id;
end;
$$;

create or replace function public.admin_complete_client_credit_settlement(p_settlement_id uuid,p_provider_reference text,p_admin_note text default null)
returns void language plpgsql security definer set search_path=public,pg_catalog as $$
declare v_admin uuid; v_row public.client_credit_settlements%rowtype; v_credit public.client_credits%rowtype; v_payment_id uuid;
begin
  if not public.is_admin() then raise exception 'غير مصرح'; end if;
  if nullif(trim(coalesce(p_provider_reference,'')),'') is null then raise exception 'رقم مرجع التحويل مطلوب'; end if;
  select id into v_admin from public.profiles where auth_id=auth.uid() limit 1;
  select * into v_row from public.client_credit_settlements where id=p_settlement_id for update;
  if not found then raise exception 'عملية التسوية غير موجودة'; end if;
  if v_row.status<>'pending' then raise exception 'تمت معالجة هذه العملية مسبقاً'; end if;
  select * into v_credit from public.client_credits where id=v_row.credit_id for update;
  if not found then raise exception 'الرصيد المرتبط بالتسوية غير موجود'; end if;
  update public.client_credit_settlements set status='paid',provider_reference=trim(p_provider_reference),admin_note=nullif(trim(coalesce(p_admin_note,'')),''),paid_at=now(),processed_by=v_admin where id=p_settlement_id;
  update public.client_credits set status='settled',settled_at=now() where id=v_row.credit_id;
  if v_credit.transaction_type='استرداد قيمة استشارة' and v_credit.booking_id is not null then
    select id into v_payment_id from public.payments where booking_id=v_credit.booking_id and status='تم الدفع' order by created_at desc limit 1 for update;
    if v_payment_id is not null then update public.payments set status='تم استرداد المبلغ' where id=v_payment_id;
    else update public.bookings set status='مسترد' where id=v_credit.booking_id and status='بانتظار الاسترداد'; end if;
  end if;
  perform public.enqueue_user_notification(v_row.user_id,case when v_credit.transaction_type='استرداد قيمة استشارة' then 'تم استرداد مبلغ الاستشارة' else 'تم تحويل المبلغ إلى حسابك' end,'تم تحويل '||trim(to_char(v_row.amount,'FM999999999999990'))||' د.ع إلى حساب الاستلام المرتبط. مرجع التحويل: '||trim(p_provider_reference),'client_credit_paid',v_row.credit_id,'client_credit');
end;
$$;