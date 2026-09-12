-- معرض القرارات والإنجازات الخاصة بالمحامي
create table if not exists public.lawyer_achievements (
  id uuid primary key default gen_random_uuid(),
  lawyer_id uuid not null references public.profiles(id) on delete cascade,
  image_url text not null,
  image_path text not null,
  title text,
  description text,
  created_at timestamptz not null default now()
);

create index if not exists lawyer_achievements_lawyer_id_idx on public.lawyer_achievements(lawyer_id);

alter table public.lawyer_achievements enable row level security;

create policy "public can view lawyer achievements"
on public.lawyer_achievements for select
using (true);

create policy "lawyer can insert own achievements"
on public.lawyer_achievements for insert
with check (lawyer_id = auth.uid() or exists (
  select 1 from public.profiles p where p.id = lawyer_id and p.auth_id = auth.uid()
));

create policy "lawyer can update own achievements"
on public.lawyer_achievements for update
using (lawyer_id = auth.uid() or exists (
  select 1 from public.profiles p where p.id = lawyer_id and p.auth_id = auth.uid()
));

create policy "lawyer can delete own achievements"
on public.lawyer_achievements for delete
using (lawyer_id = auth.uid() or exists (
  select 1 from public.profiles p where p.id = lawyer_id and p.auth_id = auth.uid()
));

insert into storage.buckets (id, name, public)
values ('lawyer_achievements', 'lawyer_achievements', true)
on conflict (id) do nothing;

create policy "public can view achievement images"
on storage.objects for select
using (bucket_id = 'lawyer_achievements');

create policy "lawyer can upload achievement images"
on storage.objects for insert
to authenticated
with check (bucket_id = 'lawyer_achievements' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "lawyer can update achievement images"
on storage.objects for update
to authenticated
using (bucket_id = 'lawyer_achievements' and (storage.foldername(name))[1] = auth.uid()::text)
with check (bucket_id = 'lawyer_achievements' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "lawyer can delete achievement images"
on storage.objects for delete
to authenticated
using (bucket_id = 'lawyer_achievements' and (storage.foldername(name))[1] = auth.uid()::text);
