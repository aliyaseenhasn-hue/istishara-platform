alter table public.client_credits alter column booking_id drop not null;
alter table public.client_credits alter column lawyer_id drop not null;

create or replace function public.admin_create_client_compensation(
  p_user_id uuid,
  p_amount numeric,
  p_reason text
) returns uuid
language plpgsql
security definer
set search_path to 'public','pg_catalog'
as $$
declare
  v_credit_id uuid;
  v_reason text := nullif(trim(coalesce(p_reason,'')),'');
begin
  if not public.is_admin() then raise exception 'غير مصرح بهذه العملية'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'مبلغ التعويض يجب أن يكون أكبر من صفر'; end if;
  if v_reason is null then raise exception 'سبب التعويض مطلوب'; end if;
  if not exists(
    select 1 from public.profiles
    where id=p_user_id and role::text in ('user','client') and status='active'
  ) then raise exception 'حساب العميل غير موجود أو غير فعال'; end if;
  if not exists(
    select 1 from public.client_payout_accounts
    where user_id=p_user_id and is_default=true
      and nullif(trim(coalesce(account_number,'')),'') is not null
      and account_number <> 'REMOVED'
  ) then raise exception 'العميل لم يربط حساب استلام أموال صالحاً بعد'; end if;

  insert into public.client_credits(
    user_id,booking_id,lawyer_id,amount,currency,transaction_type,status
  ) values(
    p_user_id,null,null,p_amount,'IQD','تعويض إداري: '||v_reason,'pending'
  ) returning id into v_credit_id;

  perform public.enqueue_user_notification(
    p_user_id,
    'تم تسجيل تعويض لصالحك',
    'تم تسجيل تعويض بقيمة '||trim(to_char(p_amount,'FM999999999999990'))||' د.ع. السبب: '||v_reason||'. سيجري تحويله إلى حساب الاستلام المرتبط بعد تنفيذ الإدارة للتحويل.',
    'client_credit_pending',v_credit_id,'client_credit'
  );
  return v_credit_id;
end;
$$;

revoke all on function public.admin_create_client_compensation(uuid,numeric,text) from public, anon;
grant execute on function public.admin_create_client_compensation(uuid,numeric,text) to authenticated;
