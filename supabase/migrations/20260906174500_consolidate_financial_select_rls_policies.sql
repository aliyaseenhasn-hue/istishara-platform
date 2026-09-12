drop policy if exists "financial_ledger_admin" on public.financial_ledger;
drop policy if exists "financial_ledger_client_select" on public.financial_ledger;
drop policy if exists "financial_ledger_lawyer_select" on public.financial_ledger;
create policy "financial_ledger_participant_select" on public.financial_ledger
for select to authenticated
using (
  exists (select 1 from public.profiles where profiles.auth_id = (select auth.uid()) and profiles.role = 'admin'::user_role)
  or client_id = (select profiles.id from public.profiles where profiles.auth_id = (select auth.uid()))
  or lawyer_id = (select profiles.id from public.profiles where profiles.auth_id = (select auth.uid()))
);

drop policy if exists "payment_financials_admin" on public.payment_financials;
drop policy if exists "payment_financials_client_select" on public.payment_financials;
drop policy if exists "payment_financials_lawyer_select" on public.payment_financials;
create policy "payment_financials_participant_select" on public.payment_financials
for select to authenticated
using (
  exists (select 1 from public.profiles where profiles.auth_id = (select auth.uid()) and profiles.role = 'admin'::user_role)
  or client_id = (select profiles.id from public.profiles where profiles.auth_id = (select auth.uid()))
  or lawyer_id = (select profiles.id from public.profiles where profiles.auth_id = (select auth.uid()))
);
