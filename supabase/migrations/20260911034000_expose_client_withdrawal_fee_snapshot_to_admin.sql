drop function if exists public.admin_list_client_wallet_withdrawals();
create function public.admin_list_client_wallet_withdrawals()
returns table(
  request_id uuid,user_id uuid,client_name text,amount numeric,transfer_fee numeric,net_amount numeric,currency text,
  status text,provider_type text,account_holder_name text,account_number text,bank_name text,fee_mode text,
  financial_policy_version integer,processing_min_business_days integer,processing_max_business_days integer,
  processing_deadline_at timestamptz,requested_at timestamptz,provider_reference text,rejection_reason text,admin_note text
)
language sql
security definer
set search_path=public,pg_catalog
as $$
  select w.id,w.user_id,coalesce(nullif(trim(p.full_name),''),'طالب الاستشارة'),w.amount,w.transfer_fee,w.net_amount,w.currency,
         w.status,w.provider_type,w.account_holder_name,w.account_number,w.bank_name,w.fee_mode,w.financial_policy_version,
         w.processing_min_business_days,w.processing_max_business_days,w.processing_deadline_at,w.requested_at,w.provider_reference,w.rejection_reason,w.admin_note
  from public.client_wallet_withdrawal_requests w
  join public.profiles p on p.id=w.user_id
  where public.is_admin()
  order by case when w.status in ('pending_review','processing') then 0 else 1 end,w.requested_at desc
  limit 100;
$$;
revoke all on function public.admin_list_client_wallet_withdrawals() from public,anon,authenticated;
grant execute on function public.admin_list_client_wallet_withdrawals() to authenticated;
