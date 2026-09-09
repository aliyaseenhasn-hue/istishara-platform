drop policy if exists reviews_public_read_auth on public.reviews;
create policy reviews_participant_or_admin_read_auth
on public.reviews
for select
to authenticated
using (
  user_id in (select p.id from public.profiles p where p.auth_id = auth.uid())
  or lawyer_id in (select p.id from public.profiles p where p.auth_id = auth.uid())
  or public.is_admin()
);

-- Public rating/comment display remains available through public.public_reviews,
-- which intentionally omits booking_id and user_id.
