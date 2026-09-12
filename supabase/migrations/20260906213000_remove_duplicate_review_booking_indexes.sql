-- Remove redundant review booking indexes after the one-review-per-booking constraint.
-- Keep reviews_one_per_booking_uidx as the canonical unique index.
drop index if exists public.ux_reviews_booking_id;
drop index if exists public.idx_reviews_booking_id;
