-- Fix two notification issues:
-- 1) one browser/device must belong to the currently signed-in account only;
-- 2) actions performed by a user should stay in the in-app notification center
--    without generating a background OS/PWA push back to the same actor.

-- Track who caused a notification. The value is populated automatically from
-- auth.uid() for authenticated app actions; system/service-role work remains null.
alter table public.notifications
  add column if not exists actor_profile_id uuid references public.profiles(id) on delete set null;

create index if not exists notifications_actor_profile_id_idx
  on public.notifications(actor_profile_id);

create or replace function public.set_notification_actor_profile_id()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_profile_id uuid;
begin
  if new.actor_profile_id is null and auth.uid() is not null then
    select p.id
      into v_actor_profile_id
    from public.profiles p
    where p.auth_id = auth.uid()
    limit 1;

    if v_actor_profile_id is not null then
      new.actor_profile_id := v_actor_profile_id;
    end if;
  end if;

  return new;
end;
$$;

revoke all on function public.set_notification_actor_profile_id() from public, anon, authenticated;

drop trigger if exists trg_set_notification_actor_profile_id on public.notifications;
create trigger trg_set_notification_actor_profile_id
before insert on public.notifications
for each row execute function public.set_notification_actor_profile_id();

-- PWA subscriptions previously stored auth.users.id while notifications target
-- profiles.id. Align them with the rest of the notification system.
alter table public.pwa_push_subscriptions
  drop constraint if exists pwa_push_subscriptions_user_id_fkey;

update public.pwa_push_subscriptions s
set user_id = p.id
from public.profiles p
where p.auth_id = s.user_id
  and s.user_id is distinct from p.id;

alter table public.pwa_push_subscriptions
  add constraint pwa_push_subscriptions_user_id_fkey
  foreign key (user_id) references public.profiles(id) on delete cascade;

alter table public.pwa_push_subscriptions
  add column if not exists device_key text;

-- Keep only one owner for an identical browser endpoint before enforcing it.
with ranked as (
  select id,
         row_number() over (
           partition by endpoint
           order by updated_at desc nulls last,
                    last_seen_at desc nulls last,
                    created_at desc nulls last,
                    id desc
         ) as rn
  from public.pwa_push_subscriptions
)
delete from public.pwa_push_subscriptions s
using ranked r
where s.id = r.id and r.rn > 1;

create unique index if not exists pwa_push_subscriptions_endpoint_uidx
  on public.pwa_push_subscriptions(endpoint);

create unique index if not exists pwa_push_subscriptions_device_key_uidx
  on public.pwa_push_subscriptions(device_key)
  where device_key is not null;

-- RLS ownership must now resolve auth.uid() -> profiles.id.
drop policy if exists "Users manage own PWA push subscriptions" on public.pwa_push_subscriptions;
create policy "Users manage own PWA push subscriptions"
on public.pwa_push_subscriptions
for all
to authenticated
using (
  user_id = (
    select p.id from public.profiles p
    where p.auth_id = (select auth.uid())
    limit 1
  )
)
with check (
  user_id = (
    select p.id from public.profiles p
    where p.auth_id = (select auth.uid())
    limit 1
  )
);

-- Trusted registration RPC: a browser endpoint/device key is atomically moved
-- to the current signed-in profile, preventing cross-account deliveries.
create or replace function public.register_current_pwa_push_subscription(
  p_endpoint text,
  p_p256dh text,
  p_auth text,
  p_user_agent text default null,
  p_device_key text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile_id uuid;
  v_endpoint text := nullif(trim(coalesce(p_endpoint, '')), '');
  v_p256dh text := nullif(trim(coalesce(p_p256dh, '')), '');
  v_auth text := nullif(trim(coalesce(p_auth, '')), '');
  v_device_key text := nullif(trim(coalesce(p_device_key, '')), '');
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  if v_endpoint is null or v_p256dh is null or v_auth is null then
    raise exception 'بيانات اشتراك الإشعارات غير مكتملة';
  end if;

  select p.id into v_profile_id
  from public.profiles p
  where p.auth_id = auth.uid()
  limit 1;

  if v_profile_id is null then raise exception 'ملف المستخدم غير موجود'; end if;

  -- Remove stale ownership for the exact browser endpoint.
  delete from public.pwa_push_subscriptions
  where endpoint = v_endpoint;

  -- A stable browser device key also removes an older endpoint that may have
  -- survived a service-worker upgrade on the same device.
  if v_device_key is not null then
    delete from public.pwa_push_subscriptions
    where device_key = v_device_key;
  end if;

  insert into public.pwa_push_subscriptions(
    user_id, endpoint, p256dh, auth, user_agent, device_key,
    created_at, updated_at, last_seen_at
  ) values (
    v_profile_id, v_endpoint, v_p256dh, v_auth,
    nullif(trim(coalesce(p_user_agent, '')), ''), v_device_key,
    now(), now(), now()
  );
end;
$$;

revoke all on function public.register_current_pwa_push_subscription(text,text,text,text,text)
  from public, anon;
grant execute on function public.register_current_pwa_push_subscription(text,text,text,text,text)
  to authenticated;

create or replace function public.unregister_current_pwa_push_subscription(
  p_endpoint text default null,
  p_device_key text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile_id uuid;
  v_endpoint text := nullif(trim(coalesce(p_endpoint, '')), '');
  v_device_key text := nullif(trim(coalesce(p_device_key, '')), '');
begin
  if auth.uid() is null then return; end if;

  select p.id into v_profile_id
  from public.profiles p
  where p.auth_id = auth.uid()
  limit 1;

  if v_profile_id is null then return; end if;

  delete from public.pwa_push_subscriptions
  where user_id = v_profile_id
    and (
      (v_endpoint is not null and endpoint = v_endpoint)
      or (v_device_key is not null and device_key = v_device_key)
    );
end;
$$;

revoke all on function public.unregister_current_pwa_push_subscription(text,text)
  from public, anon;
grant execute on function public.unregister_current_pwa_push_subscription(text,text)
  to authenticated;

-- Native FCM token registration gets the same account-transfer behavior.
create or replace function public.register_current_push_device_token(
  p_token text,
  p_platform text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile_id uuid;
  v_token text := nullif(trim(coalesce(p_token, '')), '');
  v_platform text := nullif(trim(coalesce(p_platform, '')), '');
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  if v_token is null or v_platform is null then raise exception 'بيانات الجهاز غير مكتملة'; end if;

  select p.id into v_profile_id
  from public.profiles p
  where p.auth_id = auth.uid()
  limit 1;

  if v_profile_id is null then raise exception 'ملف المستخدم غير موجود'; end if;

  insert into public.push_device_tokens(user_id, token, platform, is_active, last_seen_at)
  values(v_profile_id, v_token, v_platform, true, now())
  on conflict (token) do update
  set user_id = excluded.user_id,
      platform = excluded.platform,
      is_active = true,
      last_seen_at = now(),
      updated_at = now();
end;
$$;

revoke all on function public.register_current_push_device_token(text,text)
  from public, anon;
grant execute on function public.register_current_push_device_token(text,text)
  to authenticated;

create or replace function public.unregister_current_push_device_token(p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile_id uuid;
  v_token text := nullif(trim(coalesce(p_token, '')), '');
begin
  if auth.uid() is null or v_token is null then return; end if;

  select p.id into v_profile_id
  from public.profiles p
  where p.auth_id = auth.uid()
  limit 1;

  if v_profile_id is null then return; end if;

  update public.push_device_tokens
  set is_active = false,
      last_seen_at = now(),
      updated_at = now()
  where user_id = v_profile_id
    and token = v_token;
end;
$$;

revoke all on function public.unregister_current_push_device_token(text)
  from public, anon;
grant execute on function public.unregister_current_push_device_token(text)
  to authenticated;
