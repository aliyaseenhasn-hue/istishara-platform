drop policy if exists reviews_insert_completed_booking on public.reviews;
create policy reviews_insert_completed_booking
on public.reviews
for insert
to authenticated
with check (
  user_id in (
    select p.id from public.profiles p where p.auth_id = (select auth.uid())
  )
  and exists (
    select 1
    from public.bookings b
    where b.id = reviews.booking_id
      and b.user_id = reviews.user_id
      and b.lawyer_id = reviews.lawyer_id
      and b.status = 'مكتمل'
      and (b.consultation_status is null or b.consultation_status = 'انتهت')
      and (
        not coalesce(b.payment_required, true)
        or exists (
          select 1 from public.payments pay
          where pay.booking_id = b.id
            and pay.status = 'تم الدفع'
        )
      )
  )
);

create unique index if not exists reviews_one_per_booking_idx
  on public.reviews(booking_id);
