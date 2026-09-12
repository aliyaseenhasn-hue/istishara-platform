create table if not exists public.client_payout_accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  provider_type text not null check (provider_type in ('zain_cash','qi_card','asia_hawala','bank_account')),
  account_holder_name text not null,
  account_number text not null,
  bank_name text,
  is_default boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, provider_type, account_number)
);
create unique index if not exists ux_client_payout_accounts_default on public.client_payout_accounts(user_id) where is_default=true;
alter table public.client_payout_accounts enable row level security;
drop policy if exists client_payout_accounts_select_own on public.client_payout_accounts;
create policy client_payout_accounts_select_own on public.client_payout_accounts for select to authenticated using (
  user_id=(select id from public.profiles where auth_id=(select auth.uid()) limit 1) or (select public.is_admin())
);
revoke insert,update,delete on public.client_payout_accounts from anon,authenticated;
grant select on public.client_payout_accounts to authenticated;

create table if not exists public.client_credit_settlements (
  id uuid primary key default gen_random_uuid(),
  credit_id uuid not null references public.client_credits(id) on delete restrict,
  user_id uuid not null references public.profiles(id) on delete restrict,
  amount numeric(14,2) not null check (amount>0),
  currency text not null default 'IQD',
  payout_account_id uuid references public.client_payout_accounts(id) on delete set null,
  provider_type text not null,
  account_holder_name text not null,
  account_number text not null,
  bank_name text,
  status text not null default 'pending' check (status in ('pending','paid','failed','cancelled')),
  provider_reference text,
  admin_note text,
  created_at timestamptz not null default now(),
  paid_at timestamptz,
  processed_by uuid references public.profiles(id) on delete set null,
  unique(credit_id)
);
alter table public.client_credit_settlements enable row level security;
drop policy if exists client_credit_settlements_select_own on public.client_credit_settlements;
create policy client_credit_settlements_select_own on public.client_credit_settlements for select to authenticated using (
  user_id=(select id from public.profiles where auth_id=(select auth.uid()) limit 1) or (select public.is_admin())
);
revoke insert,update,delete on public.client_credit_settlements from anon,authenticated;
grant select on public.client_credit_settlements to authenticated;

create or replace function public.upsert_client_payout_account(p_provider_type text,p_account_holder_name text,p_account_number text,p_bank_name text default null)
returns uuid language plpgsql security definer set search_path=public,pg_catalog as $$
declare v_user_id uuid; v_id uuid;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  if p_provider_type not in ('zain_cash','qi_card','asia_hawala','bank_account') then raise exception 'وسيلة الاستلام غير مدعومة'; end if;
  if nullif(trim(p_account_holder_name),'') is null then raise exception 'اسم صاحب الحساب مطلوب'; end if;
  if nullif(trim(p_account_number),'') is null then raise exception 'رقم الحساب أو المحفظة مطلوب'; end if;
  select id into v_user_id from public.profiles where auth_id=auth.uid() limit 1;
  if v_user_id is null then raise exception 'تعذر تحديد حساب المستخدم'; end if;
  update public.client_payout_accounts set is_default=false,updated_at=now() where user_id=v_user_id and is_default=true;
  insert into public.client_payout_accounts(user_id,provider_type,account_holder_name,account_number,bank_name,is_default)
  values(v_user_id,p_provider_type,trim(p_account_holder_name),trim(p_account_number),nullif(trim(p_bank_name),''),true)
  on conflict(user_id,provider_type,account_number) do update set account_holder_name=excluded.account_holder_name,bank_name=excluded.bank_name,is_default=true,updated_at=now()
  returning id into v_id;
  return v_id;
end; $$;
revoke all on function public.upsert_client_payout_account(text,text,text,text) from public,anon;
grant execute on function public.upsert_client_payout_account(text,text,text,text) to authenticated;

create or replace function public.admin_create_client_compensation(p_user_id uuid,p_amount numeric,p_reason text)
returns uuid language plpgsql security definer set search_path=public,pg_catalog as $$
declare v_credit_id uuid;
begin
  if not public.is_admin() then raise exception 'غير مصرح'; end if;
  if p_amount is null or p_amount<=0 then raise exception 'المبلغ يجب أن يكون أكبر من صفر'; end if;
  if not exists(select 1 from public.client_payout_accounts where user_id=p_user_id and is_default=true) then raise exception 'العميل لم يربط حساب استلام أموال بعد'; end if;
  insert into public.client_credits(user_id,amount,currency,transaction_type,status)
  values(p_user_id,p_amount,'IQD',coalesce(nullif(trim(p_reason),''),'تعويض إداري'),'pending') returning id into v_credit_id;
  perform public.enqueue_user_notification(p_user_id,'تم تسجيل مبلغ مستحق لك','تم تسجيل مبلغ '||trim(to_char(p_amount,'FM999999999999990'))||' د.ع لصالحك. سيجري تحويله إلى حساب الاستلام المرتبط بعد تنفيذ الإدارة للتحويل.','client_credit_pending',v_credit_id,'client_credit');
  return v_credit_id;
end; $$;
revoke all on function public.admin_create_client_compensation(uuid,numeric,text) from public,anon,authenticated;
grant execute on function public.admin_create_client_compensation(uuid,numeric,text) to authenticated;

create or replace function public.admin_prepare_client_credit_settlement(p_credit_id uuid)
returns uuid language plpgsql security definer set search_path=public,pg_catalog as $$
declare v_credit public.client_credits%rowtype; v_account public.client_payout_accounts%rowtype; v_settlement_id uuid;
begin
  if not public.is_admin() then raise exception 'غير مصرح'; end if;
  select * into v_credit from public.client_credits where id=p_credit_id for update;
  if not found then raise exception 'الرصيد غير موجود'; end if;
  if v_credit.status not in ('pending','بانتظار التحويل','قيد الانتظار') then raise exception 'هذا الرصيد لا يحتاج إلى تسوية'; end if;
  select * into v_account from public.client_payout_accounts where user_id=v_credit.user_id and is_default=true limit 1;
  if not found then raise exception 'العميل لم يحدد حساب استلام افتراضياً'; end if;
  insert into public.client_credit_settlements(credit_id,user_id,amount,currency,payout_account_id,provider_type,account_holder_name,account_number,bank_name,status)
  values(v_credit.id,v_credit.user_id,v_credit.amount,v_credit.currency,v_account.id,v_account.provider_type,v_account.account_holder_name,v_account.account_number,v_account.bank_name,'pending')
  on conflict(credit_id) do update set payout_account_id=excluded.payout_account_id,provider_type=excluded.provider_type,account_holder_name=excluded.account_holder_name,account_number=excluded.account_number,bank_name=excluded.bank_name
  returning id into v_settlement_id;
  update public.client_credits set status='بانتظار التحويل' where id=v_credit.id;
  return v_settlement_id;
end; $$;
revoke all on function public.admin_prepare_client_credit_settlement(uuid) from public,anon,authenticated;
grant execute on function public.admin_prepare_client_credit_settlement(uuid) to authenticated;

create or replace function public.admin_complete_client_credit_settlement(p_settlement_id uuid,p_provider_reference text,p_admin_note text default null)
returns void language plpgsql security definer set search_path=public,pg_catalog as $$
declare v_admin uuid; v_row public.client_credit_settlements%rowtype;
begin
  if not public.is_admin() then raise exception 'غير مصرح'; end if;
  if nullif(trim(p_provider_reference),'') is null then raise exception 'رقم مرجع التحويل مطلوب'; end if;
  select id into v_admin from public.profiles where auth_id=auth.uid() limit 1;
  select * into v_row from public.client_credit_settlements where id=p_settlement_id for update;
  if not found then raise exception 'عملية التسوية غير موجودة'; end if;
  if v_row.status<>'pending' then raise exception 'تمت معالجة هذه العملية مسبقاً'; end if;
  update public.client_credit_settlements set status='paid',provider_reference=trim(p_provider_reference),admin_note=nullif(trim(p_admin_note),''),paid_at=now(),processed_by=v_admin where id=p_settlement_id;
  update public.client_credits set status='settled',settled_at=now() where id=v_row.credit_id;
  perform public.enqueue_user_notification(v_row.user_id,'تم تحويل المبلغ إلى حسابك','تم تحويل '||trim(to_char(v_row.amount,'FM999999999999990'))||' د.ع إلى حساب الاستلام المرتبط. مرجع التحويل: '||trim(p_provider_reference),'client_credit_paid',v_row.credit_id,'client_credit');
end; $$;
revoke all on function public.admin_complete_client_credit_settlement(uuid,text,text) from public,anon,authenticated;
grant execute on function public.admin_complete_client_credit_settlement(uuid,text,text) to authenticated;

create or replace function public.admin_list_client_credit_operations()
returns table(credit_id uuid,user_id uuid,client_name text,amount numeric,currency text,transaction_type text,credit_status text,created_at timestamptz,settlement_id uuid,settlement_status text,provider_type text,account_holder_name text,account_number text,bank_name text,provider_reference text,paid_at timestamptz)
language sql security definer set search_path=public,pg_catalog as $$
  select c.id,c.user_id,coalesce(nullif(trim(p.full_name),''),'طالب الاستشارة'),c.amount,c.currency,c.transaction_type,c.status,c.created_at,s.id,s.status,coalesce(s.provider_type,a.provider_type),coalesce(s.account_holder_name,a.account_holder_name),coalesce(s.account_number,a.account_number),coalesce(s.bank_name,a.bank_name),s.provider_reference,s.paid_at
  from public.client_credits c join public.profiles p on p.id=c.user_id
  left join public.client_credit_settlements s on s.credit_id=c.id
  left join public.client_payout_accounts a on a.user_id=c.user_id and a.is_default=true
  where public.is_admin() order by c.created_at desc limit 100;
$$;
revoke all on function public.admin_list_client_credit_operations() from public,anon,authenticated;
grant execute on function public.admin_list_client_credit_operations() to authenticated;

create or replace function public.admin_search_clients(p_query text default '')
returns table(id uuid,full_name text,phone text)
language sql security definer set search_path=public,pg_catalog as $$
  select p.id,coalesce(nullif(trim(p.full_name),''),'طالب الاستشارة'),p.phone from public.profiles p
  where public.is_admin() and p.role::text='user' and (nullif(trim(p_query),'') is null or p.full_name ilike '%'||trim(p_query)||'%' or coalesce(p.phone,'') ilike '%'||trim(p_query)||'%')
  order by p.full_name nulls last limit 20;
$$;
revoke all on function public.admin_search_clients(text) from public,anon,authenticated;
grant execute on function public.admin_search_clients(text) to authenticated;
