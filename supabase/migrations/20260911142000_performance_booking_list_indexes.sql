create index if not exists idx_bookings_user_active_created_at
  on public.bookings (user_id, created_at desc)
  where archived_by_user_at is null;

create index if not exists idx_bookings_lawyer_active_created_at
  on public.bookings (lawyer_id, created_at desc)
  where archived_by_lawyer_at is null and deleted_by_lawyer_at is null;
