-- The first PWA trigger was intentionally added without embedding a secret in source.
-- Reuse the already-configured internal authorization header from the native push
-- trigger so the PWA webhook is authenticated without exposing the service key.

do $body$
declare
  native_def text;
  auth_headers text;
begin
  select pg_get_triggerdef(t.oid)
    into native_def
  from pg_trigger t
  where t.tgrelid = 'public.notifications'::regclass
    and t.tgname = 'send-native-push-on-notification'
    and not t.tgisinternal;

  if native_def is null then
    raise exception 'Existing native push trigger was not found; refusing to create an unauthenticated PWA trigger';
  end if;

  auth_headers := (regexp_match(
    native_def,
    $re$http_request\('[^']+',\s*'POST',\s*'([^']+)'$re$
  ))[1];

  if auth_headers is null or auth_headers = '' then
    raise exception 'Could not recover the existing internal webhook authorization headers';
  end if;

  execute 'drop trigger if exists "send-pwa-push-on-notification" on public.notifications';

  execute format(
    'create trigger "send-pwa-push-on-notification" after insert on public.notifications for each row execute function supabase_functions.http_request(%L, %L, %L, %L, %L)',
    'https://iidxqrnrazkyfgzelzhb.supabase.co/functions/v1/send-pwa-push',
    'POST',
    auth_headers,
    '{}',
    '10000'
  );
end
$body$;
