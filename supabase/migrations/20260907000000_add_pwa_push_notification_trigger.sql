-- Send every newly-created in-app notification to the PWA Web Push Edge Function.
-- The Edge Function is intentionally public at the HTTP layer and performs its own
-- server-side Supabase access through withSupabase({ auth: 'secret' }).

create trigger "send-pwa-push-on-notification"
after insert on public.notifications
for each row
execute function supabase_functions.http_request(
  'https://iidxqrnrazkyfgzelzhb.supabase.co/functions/v1/send-pwa-push',
  'POST',
  '{"Content-Type":"application/json"}',
  '{}',
  '10000'
);
