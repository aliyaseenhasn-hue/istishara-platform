alter table public.public_lawyer_directory add column if not exists lawyer_profile_id uuid;

update public.public_lawyer_directory d
set lawyer_profile_id = lp.id
from public.lawyer_profiles lp
where lp.profile_id = d.profile_id
  and d.lawyer_profile_id is distinct from lp.id;

create unique index if not exists public_lawyer_directory_lawyer_profile_id_uidx
  on public.public_lawyer_directory(lawyer_profile_id)
  where lawyer_profile_id is not null;

create or replace function public.sync_public_lawyer_directory()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_profile_id uuid;
  v_lawyer_profile_id uuid;
begin
  if TG_TABLE_NAME = 'profiles' then
    v_profile_id := NEW.id;
  else
    v_profile_id := (to_jsonb(NEW)->>'profile_id')::uuid;
  end if;

  select lp.id into v_lawyer_profile_id
  from public.lawyer_profiles lp
  where lp.profile_id = v_profile_id
  limit 1;

  insert into public.public_lawyer_directory(
    profile_id,lawyer_profile_id,full_name,avatar_url,city,is_verified,bio,years_experience,
    consultation_price,rating,review_count,availability,specialization,services,updated_at
  )
  select p.id,v_lawyer_profile_id,p.full_name,p.avatar_url,p.city,coalesce(lp.verified,false),lp.bio,
    lp.years_experience,lp.consultation_price,coalesce(lp.rating,0),coalesce(lp.review_count,0),
    coalesce(lp.availability,true),lp.specialization,coalesce(lp.services,'[]'::jsonb),now()
  from public.profiles p
  left join public.lawyer_profiles lp on lp.profile_id=p.id
  where p.id=v_profile_id and p.role='lawyer' and coalesce(lp.verified,false)=true
  on conflict (profile_id) do update set
    lawyer_profile_id=excluded.lawyer_profile_id,
    full_name=excluded.full_name,avatar_url=excluded.avatar_url,city=excluded.city,
    is_verified=excluded.is_verified,bio=excluded.bio,years_experience=excluded.years_experience,
    consultation_price=excluded.consultation_price,rating=excluded.rating,
    review_count=excluded.review_count,availability=excluded.availability,
    specialization=excluded.specialization,services=excluded.services,updated_at=now();

  if not exists (
    select 1 from public.profiles p
    left join public.lawyer_profiles lp on lp.profile_id=p.id
    where p.id=v_profile_id and p.role='lawyer' and coalesce(lp.verified,false)=true
  ) then
    delete from public.public_lawyer_directory where profile_id=v_profile_id;
  end if;

  return NEW;
end;
$function$;

create or replace function public.get_public_lawyer(p_profile_id uuid)
returns table(
  id uuid, profile_id uuid, full_name text, avatar_url text, bio text,
  specialization text[], years_experience integer, consultation_price numeric,
  rating numeric, review_count integer, verified boolean, availability boolean, services jsonb
)
language sql
stable
security invoker
set search_path = public
as $$
  select d.lawyer_profile_id, d.profile_id, d.full_name, d.avatar_url, d.bio,
         d.specialization, d.years_experience, d.consultation_price, d.rating,
         d.review_count, d.is_verified, d.availability, d.services
  from public.public_lawyer_directory d
  where d.profile_id = p_profile_id and d.is_verified is true;
$$;

create or replace function public.get_public_lawyers(p_limit integer default 20, p_offset integer default 0)
returns table(
  id uuid, profile_id uuid, full_name text, avatar_url text, bio text,
  specialization text[], years_experience integer, consultation_price numeric,
  rating numeric, review_count integer, verified boolean, availability boolean, services jsonb
)
language sql
stable
security invoker
set search_path = public
as $$
  select d.lawyer_profile_id, d.profile_id, d.full_name, d.avatar_url, d.bio,
         d.specialization, d.years_experience, d.consultation_price, d.rating,
         d.review_count, d.is_verified, d.availability, d.services
  from public.public_lawyer_directory d
  where d.is_verified is true
  order by d.lawyer_profile_id
  limit least(greatest(coalesce(p_limit,20),1),100)
  offset greatest(coalesce(p_offset,0),0);
$$;
