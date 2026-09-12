revoke all on function public.record_manual_payment(uuid,numeric) from public, anon, authenticated;
comment on function public.record_manual_payment(uuid,numeric) is 'Legacy cash-at-lawyer payment path disabled. All paid bookings must use platform receipt review.';
