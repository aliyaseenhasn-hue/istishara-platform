revoke all on function public.reverse_financial_accounting_for_refund(uuid) from public, anon, authenticated;
revoke all on function public.settle_oldest_lawyer_penalties_for_completed_booking(uuid) from public, anon, authenticated;

revoke all on function public.close_pending_manual_payments_for_terminal_booking() from public, anon, authenticated;
revoke all on function public.ensure_client_refund_credit_for_booking() from public, anon, authenticated;
revoke all on function public.finalize_lawyer_financials_after_completed_booking() from public, anon, authenticated;
revoke all on function public.guard_lawyer_availability_slot() from public, anon, authenticated;
revoke all on function public.notify_lawyer_followers_on_slot() from public, anon, authenticated;
revoke all on function public.protect_lawyer_profile_sensitive_fields() from public, anon, authenticated;
revoke all on function public.reconcile_pending_cancellation_request_for_booking() from public, anon, authenticated;
revoke all on function public.sync_cancellation_request_from_penalty() from public, anon, authenticated;

revoke all on function public.get_booking_participant_identity(uuid) from public, anon;
grant execute on function public.get_booking_participant_identity(uuid) to authenticated;
