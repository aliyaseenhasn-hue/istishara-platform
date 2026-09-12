-- Production integrity: one review per completed consultation booking.
-- Existing production data was checked for duplicate booking_id values before applying this index.
create unique index if not exists reviews_one_per_booking_uidx on public.reviews (booking_id);
comment on index public.reviews_one_per_booking_uidx is 'Prevents duplicate client reviews for the same completed consultation booking.';
