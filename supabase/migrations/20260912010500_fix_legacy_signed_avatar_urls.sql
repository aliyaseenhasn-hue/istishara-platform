-- Convert legacy temporary avatar signed URLs to permanent public URLs.
-- The avatars bucket is public; keeping expiring signed URLs in profiles.avatar_url
-- makes otherwise valid profile images disappear after the token expires.
update public.profiles p
set avatar_url = 'https://iidxqrnrazkyfgzelzhb.supabase.co/storage/v1/object/public/avatars/' ||
                 split_part(split_part(p.avatar_url, '/storage/v1/object/sign/avatars/', 2), '?', 1),
    updated_at = now()
where p.avatar_url like '%/storage/v1/object/sign/avatars/%'
  and exists (
    select 1
    from storage.objects o
    where o.bucket_id = 'avatars'
      and o.name = split_part(split_part(p.avatar_url, '/storage/v1/object/sign/avatars/', 2), '?', 1)
  );
