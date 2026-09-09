-- Final release hardening: reduce exposed DML surface and address safe database advisor findings.

-- Public projection tables are read-only to app roles; maintenance is performed by owner/security-definer triggers.
revoke insert, update, delete, truncate, references, trigger on table public.public_lawyer_directory from anon, authenticated;
revoke insert, update, delete, truncate, references, trigger on table public.public_reviews from anon, authenticated;

-- Cover foreign keys used by deletes/joins and cancellation/financial workflows.
create index if not exists idx_account_status_audit_changed_by on public.account_status_audit(changed_by);
create index if not exists idx_account_status_audit_user_id on public.account_status_audit(user_id);
create index if not exists idx_bookings_cancellation_request_id on public.bookings(cancellation_request_id);
create index if not exists idx_bookings_cancelled_by_profile_id on public.bookings(cancelled_by_profile_id);
create index if not exists idx_client_cancellation_compensations_booking_id on public.client_cancellation_compensations(booking_id);
create index if not exists idx_client_cancellation_compensations_client_id on public.client_cancellation_compensations(client_id);
create index if not exists idx_client_cancellation_compensations_lawyer_id on public.client_cancellation_compensations(lawyer_id);
create index if not exists idx_client_credit_settlements_payout_account_id on public.client_credit_settlements(payout_account_id);
create index if not exists idx_client_credit_settlements_processed_by on public.client_credit_settlements(processed_by);
create index if not exists idx_client_credit_settlements_user_id on public.client_credit_settlements(user_id);
create index if not exists idx_manual_payment_settings_updated_by on public.manual_payment_settings(updated_by);

-- Keep one unique index enforcing one review per booking.
drop index if exists public.reviews_one_per_booking_idx;

-- Avoid re-evaluating auth.uid() per row while preserving existing RLS semantics.
drop policy if exists account_status_audit_read on public.account_status_audit;
create policy account_status_audit_read
on public.account_status_audit
for select to authenticated
using (
  user_id in (select p.id from public.profiles p where p.auth_id = (select auth.uid()))
  or public.is_admin()
);

drop policy if exists client_cancellation_compensations_select_participants on public.client_cancellation_compensations;
create policy client_cancellation_compensations_select_participants
on public.client_cancellation_compensations
for select to authenticated
using (
  public.is_admin()
  or exists (
    select 1 from public.profiles p
    where p.auth_id = (select auth.uid())
      and p.id = any(array[client_id, lawyer_id])
  )
);

drop policy if exists followers_select_own on public.lawyer_followers;
create policy followers_select_own
on public.lawyer_followers
for select to authenticated
using (
  follower_id = (
    select p.id from public.profiles p
    where p.auth_id = (select auth.uid())
    limit 1
  )
);

drop policy if exists followers_delete_own on public.lawyer_followers;
create policy followers_delete_own
on public.lawyer_followers
for delete to authenticated
using (
  follower_id = (
    select p.id from public.profiles p
    where p.auth_id = (select auth.uid())
    limit 1
  )
);

drop policy if exists profiles_insert_auth on public.profiles;
create policy profiles_insert_auth
on public.profiles
for insert to authenticated
with check (
  (select auth.uid()) = auth_id
  and role = any(array['user'::public.user_role,'lawyer'::public.user_role])
  and coalesce(is_verified,false) = false
  and status = 'active'::public.account_status
  and telegram_user_id is null
  and not exists (
    select 1 from public.closed_auth_accounts c
    where c.auth_id = (select auth.uid())
  )
);

drop policy if exists reviews_participant_or_admin_read_auth on public.reviews;
create policy reviews_participant_or_admin_read_auth
on public.reviews
for select to authenticated
using (
  user_id in (select p.id from public.profiles p where p.auth_id = (select auth.uid()))
  or lawyer_id in (select p.id from public.profiles p where p.auth_id = (select auth.uid()))
  or public.is_admin()
);
