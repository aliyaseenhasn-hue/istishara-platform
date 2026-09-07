-- Fix legacy RLS policies that compared profile IDs directly with auth.uid().
-- profiles.id and auth.users.id are not guaranteed to be identical (notably for
-- Telegram-created/migrated accounts). Keep the existing access model, but use
-- the canonical profile ownership helper everywhere these profile IDs are used.

alter policy "cancellation requests participant read"
on public.cancellation_requests
using (
  public.is_profile_owned_by_actor(client_id)
  or public.is_profile_owned_by_actor(lawyer_id)
  or public.is_admin()
);

alter policy "cancellation requests lawyer create"
on public.cancellation_requests
with check (public.is_profile_owned_by_actor(lawyer_id));

alter policy "lawyer payout attempts own read"
on public.lawyer_payout_attempts
using (
  exists (
    select 1
    from public.lawyer_payout_requests lpr
    where lpr.id = lawyer_payout_attempts.payout_id
      and public.is_profile_owned_by_actor(lpr.lawyer_id)
  )
);

alter policy "lawyer penalties participant read"
on public.lawyer_penalties
using (
  public.is_profile_owned_by_actor(client_id)
  or public.is_profile_owned_by_actor(lawyer_id)
  or public.is_admin()
);

alter policy "penalty settlements participant read"
on public.lawyer_penalty_settlements
using (
  public.is_profile_owned_by_actor(client_id)
  or public.is_profile_owned_by_actor(lawyer_id)
  or public.is_admin()
);
