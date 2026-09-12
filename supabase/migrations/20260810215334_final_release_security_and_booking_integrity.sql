-- Final release hardening: restrict exposed RLS policies to authenticated users.
alter policy "conversations_insert" on public.conversations to authenticated;
alter policy "conversations_select" on public.conversations to authenticated;
alter policy "conversations_update" on public.conversations to authenticated;
alter policy "messages_insert" on public.messages to authenticated;
alter policy "messages_select" on public.messages to authenticated;
alter policy "messages_update" on public.messages to authenticated;
alter policy "notifications_delete" on public.notifications to authenticated;
alter policy "notifications_insert" on public.notifications to authenticated;
alter policy "notifications_select" on public.notifications to authenticated;
alter policy "notifications_update" on public.notifications to authenticated;
alter policy "specialization_requests_delete" on public.specialization_change_requests to authenticated;
alter policy "specialization_requests_insert" on public.specialization_change_requests to authenticated;
alter policy "specialization_requests_select" on public.specialization_change_requests to authenticated;
alter policy "specialization_requests_update" on public.specialization_change_requests to authenticated;
alter policy "avatars_insert" on storage.objects to authenticated;
alter policy "avatars_select" on storage.objects to authenticated;
alter policy "avatars_update" on storage.objects to authenticated;
alter policy "lawyer_documents_insert" on storage.objects to authenticated;
alter policy "lawyer_documents_update" on storage.objects to authenticated;
alter policy "receipts_insert" on storage.objects to authenticated;
alter policy "receipts_update" on storage.objects to authenticated;
alter policy "عرض الإيصالات" on storage.objects to authenticated;
alter policy "عرض وثائق المحامي" on storage.objects to authenticated;
revoke execute on function public.archive_booking_for_lawyer(uuid) from anon;
revoke execute on function public.get_booking_contact_info(uuid) from anon;
revoke execute on function public.report_booking_no_show(uuid) from anon;
revoke execute on function public.review_booking(uuid,boolean) from anon;
revoke execute on function public.update_own_profile_contact(text,text,text,text) from anon;
revoke execute on function public.get_public_lawyer(uuid) from anon;
revoke execute on function public.get_public_lawyers() from authenticated;
grant execute on function public.get_public_lawyer(uuid) to anon, authenticated;
grant execute on function public.get_public_lawyers() to anon, authenticated;
revoke execute on function public.notify_booking_events() from anon, authenticated;
revoke execute on function public.notify_custom_request_events() from anon, authenticated;
revoke execute on function public.notify_lawyer_profile_events() from anon, authenticated;
revoke execute on function public.notify_message_event() from anon, authenticated;
revoke execute on function public.notify_payment_events() from anon, authenticated;
revoke execute on function public.notify_review_event() from anon, authenticated;
revoke execute on function public.notify_specialization_request_events() from anon, authenticated;
revoke execute on function public.get_my_role() from anon;
revoke execute on function public.get_profile_auth_id(uuid) from anon;
revoke execute on function public.is_admin() from anon;
create unique index if not exists bookings_active_lawyer_scheduled_at_uidx on public.bookings (lawyer_id, scheduled_at) where status not in ('ملغي','مسترد');
do $$
begin
  if not exists (select 1 from pg_constraint where conname='bookings_in_progress_requires_started_at') then
    alter table public.bookings add constraint bookings_in_progress_requires_started_at check (status <> 'قيد التنفيذ' or started_at is not null);
  end if;
  if not exists (select 1 from pg_constraint where conname='bookings_completed_requires_timestamps') then
    alter table public.bookings add constraint bookings_completed_requires_timestamps check (status <> 'مكتمل' or (started_at is not null and completed_at is not null));
  end if;
  if not exists (select 1 from pg_constraint where conname='bookings_cancelled_requires_timestamp') then
    alter table public.bookings add constraint bookings_cancelled_requires_timestamp check (status <> 'ملغي' or cancelled_at is not null);
  end if;
end $$;
