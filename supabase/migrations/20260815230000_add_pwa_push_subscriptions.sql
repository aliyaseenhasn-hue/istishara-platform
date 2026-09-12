create table if not exists public.pwa_push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  endpoint text not null,
  p256dh text not null,
  auth text not null,
  user_agent text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  unique (user_id, endpoint)
);

alter table public.pwa_push_subscriptions enable row level security;

drop policy if exists "Users manage own PWA push subscriptions" on public.pwa_push_subscriptions;
create policy "Users manage own PWA push subscriptions"
on public.pwa_push_subscriptions
for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create index if not exists pwa_push_subscriptions_user_id_idx
  on public.pwa_push_subscriptions(user_id);

create or replace function public.touch_pwa_push_subscription()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  new.last_seen_at = now();
  return new;
end;
$$;

drop trigger if exists trg_touch_pwa_push_subscription on public.pwa_push_subscriptions;
create trigger trg_touch_pwa_push_subscription
before update on public.pwa_push_subscriptions
for each row execute function public.touch_pwa_push_subscription();
