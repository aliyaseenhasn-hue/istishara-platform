-- Security: these functions are trigger-only helpers and must not be callable through PostgREST/RPC.
REVOKE EXECUTE ON FUNCTION public.guard_booking_time_conflict() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.guard_custom_appointment_slot_holds() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.snapshot_financial_policy_on_booking() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.snapshot_financial_policy_on_custom_request() FROM PUBLIC, anon, authenticated;

-- Performance: add covering indexes for every currently unindexed foreign key reported by the database advisor.
CREATE INDEX IF NOT EXISTS idx_client_wallet_withdrawals_payout_account_id
  ON public.client_wallet_withdrawal_requests (payout_account_id);
CREATE INDEX IF NOT EXISTS idx_client_wallet_withdrawals_processed_by
  ON public.client_wallet_withdrawal_requests (processed_by);
CREATE INDEX IF NOT EXISTS idx_lawyer_specialization_history_changed_by
  ON public.lawyer_specialization_history (changed_by);
CREATE INDEX IF NOT EXISTS idx_lawyer_specialization_history_source_request_id
  ON public.lawyer_specialization_history (source_request_id);
CREATE INDEX IF NOT EXISTS idx_no_show_review_requests_client_credit_id
  ON public.no_show_review_requests (client_credit_id);
CREATE INDEX IF NOT EXISTS idx_no_show_review_requests_settlement_id
  ON public.no_show_review_requests (settlement_id);
CREATE INDEX IF NOT EXISTS idx_platform_financial_policy_versions_created_by
  ON public.platform_financial_policy_versions (created_by);
