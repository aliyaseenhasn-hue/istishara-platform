-- Fix sync trigger: it is attached to both profiles and lawyer_profiles.
-- profiles has id but no profile_id, so NEW.profile_id must not be referenced
-- directly when the trigger fires for profiles.

create or replace function public.sync_public_lawyer_directory()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid;
begin
  if TG_TABLE_NAME = 'profiles' then
    v_profile_id := NEW.id;
  else
    v_profile_id := (to_jsonb(NEW)->>'profile_id')::uuid;
  end if;

  insert into public.public_lawyer_directory(
    profile_id, full_name, avatar_url, city, is_verified, bio,
    years_experience, consultation_price, rating, review_count,
    availability, specialization, services, updated_at
  )
  select
    p.id, p.full_name, p.avatar_url, p.city, coalesce(lp.verified, false),
    lp.bio, lp.years_experience, lp.consultation_price, coalesce(lp.rating, 0),
    coalesce(lp.review_count, 0), coalesce(lp.availability, true),
    lp.specialization, coalesce(lp.services, '[]'::jsonb), now()
  from public.profiles p
  left join public.lawyer_profiles lp on lp.profile_id = p.id
  where p.id = v_profile_id
    and p.role = 'lawyer'
    and coalesce(lp.verified, false) = true
  on conflict (profile_id) do update set
    full_name = excluded.full_name,
    avatar_url = excluded.avatar_url,
    city = excluded.city,
    is_verified = excluded.is_verified,
    bio = excluded.bio,
    years_experience = excluded.years_experience,
    consultation_price = excluded.consultation_price,
    rating = excluded.rating,
    review_count = excluded.review_count,
    availability = excluded.availability,
    specialization = excluded.specialization,
    services = excluded.services,
    updated_at = now();

  if not exists (
    select 1
    from public.profiles p
    left join public.lawyer_profiles lp on lp.profile_id = p.id
    where p.id = v_profile_id
      and p.role = 'lawyer'
      and coalesce(lp.verified, false) = true
  ) then
    delete from public.public_lawyer_directory
    where profile_id = v_profile_id;
  end if;

  return NEW;
end;
$$;
