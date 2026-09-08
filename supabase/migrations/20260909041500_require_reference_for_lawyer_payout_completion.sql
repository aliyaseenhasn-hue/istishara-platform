create or replace function public.admin_complete_payout(
  p_payout_id uuid,
  p_status text,
  p_provider_reference text default null,
  p_rejection_reason text default null
)
returns void language plpgsql security definer set search_path=public as $$
declare v_admin uuid; v_request record; v_wallet record;
begin
  select id into v_admin from public.profiles where auth_id=auth.uid() and role='admin';
  if v_admin is null then raise exception 'غير مصرح: هذه العملية للإدارة فقط'; end if;
  if p_status not in ('paid','rejected') then raise exception 'حالة غير صالحة'; end if;
  if p_status='paid' and nullif(trim(coalesce(p_provider_reference,'')),'') is null then raise exception 'رقم مرجع التحويل إلزامي قبل تسجيل السحب كمدفوع'; end if;
  if p_status='rejected' and nullif(trim(coalesce(p_rejection_reason,'')),'') is null then raise exception 'سبب رفض طلب السحب إلزامي'; end if;
  select * into v_request from public.lawyer_payout_requests where id=p_payout_id for update;
  if not found then raise exception 'طلب السحب غير موجود'; end if;
  if v_request.status not in ('pending_review','approved') then raise exception using message='لا يمكن معالجة طلب بهذه الحالة: '||v_request.status; end if;
  select * into v_wallet from public.lawyer_wallets where lawyer_id=v_request.lawyer_id for update;
  if not found then raise exception 'محفظة المحامي غير موجودة'; end if;
  if v_wallet.pending_balance<v_request.amount then raise exception 'الرصيد المعلق لا يغطي طلب السحب'; end if;
  if p_status='paid' then
    update public.lawyer_wallets set pending_balance=pending_balance-v_request.amount,lifetime_paid_out=lifetime_paid_out+v_request.amount,updated_at=now() where lawyer_id=v_request.lawyer_id;
    update public.lawyer_payout_requests set status='paid',provider_reference=trim(p_provider_reference),processed_at=now(),completed_at=now(),approved_at=coalesce(approved_at,now()) where id=p_payout_id;
  else
    update public.lawyer_wallets set available_balance=available_balance+v_request.amount,pending_balance=pending_balance-v_request.amount,updated_at=now() where lawyer_id=v_request.lawyer_id;
    update public.lawyer_payout_requests set status='rejected',rejection_reason=trim(p_rejection_reason),processed_at=now(),rejected_at=now() where id=p_payout_id;
  end if;
end;
$$;