create table if not exists public.lawyer_followers (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  lawyer_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, lawyer_id),
  constraint lawyer_followers_not_self check (follower_id <> lawyer_id)
);

alter table public.lawyer_followers enable row level security;

create policy "followers_select_own" on public.lawyer_followers
for select to authenticated
using (follower_id = (select id from public.profiles where auth_id = auth.uid() limit 1));

create policy "followers_insert_own" on public.lawyer_followers
for insert to authenticated
with check (
  follower_id = (select id from public.profiles where auth_id = auth.uid() limit 1)
  and exists (
    select 1 from public.lawyer_profiles lp
    where lp.profile_id = lawyer_id and lp.verified = true
  )
);

create policy "followers_delete_own" on public.lawyer_followers
for delete to authenticated
using (follower_id = (select id from public.profiles where auth_id = auth.uid() limit 1));

create index if not exists lawyer_followers_lawyer_idx on public.lawyer_followers(lawyer_id);

create or replace function public.notify_lawyer_followers_on_slot()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
  v_follower record;
begin
  if new.is_available is distinct from true or new.starts_at <= now() then
    return new;
  end if;

  if tg_op = 'UPDATE'
     and old.is_available is true
     and old.starts_at is not distinct from new.starts_at
     and old.ends_at is not distinct from new.ends_at then
    return new;
  end if;

  select coalesce(nullif(trim(full_name), ''), 'المحامي') into v_name
  from public.profiles
  where id = new.lawyer_id;

  for v_follower in
    select follower_id from public.lawyer_followers where lawyer_id = new.lawyer_id
  loop
    perform public.enqueue_user_notification(
      v_follower.follower_id,
      'موعد جديد لدى ' || v_name,
      'قام المحامي ' || v_name || ' بإضافة موعد حجز استشارة جديد. يمكنك الحجز الآن.',
      'lawyer_availability',
      new.lawyer_id,
      'lawyer_profile'
    );
  end loop;

  return new;
end;
$$;

drop trigger if exists trg_notify_lawyer_followers_on_slot on public.lawyer_availability_slots;
create trigger trg_notify_lawyer_followers_on_slot
after insert or update of starts_at, ends_at, is_available on public.lawyer_availability_slots
for each row execute function public.notify_lawyer_followers_on_slot();

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'bookings'
  ) then
    alter publication supabase_realtime add table public.bookings;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'lawyer_availability_slots'
  ) then
    alter publication supabase_realtime add table public.lawyer_availability_slots;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'lawyer_followers'
  ) then
    alter publication supabase_realtime add table public.lawyer_followers;
  end if;
end $$;
