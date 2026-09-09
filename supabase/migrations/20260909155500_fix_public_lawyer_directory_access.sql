-- Restore the public lawyer directory after account-status hardening.
-- The public RPCs need to inspect profiles.status/role internally, but callers
-- must not receive direct SELECT access to public.profiles.

create or replace function public.get_public_lawyers(
  p_limit integer default 20,
  p_offset integer default 0
)
returns table(
  id uuid,
  profile_id uuid,
  full_name text,
  avatar_url text,
  bio text,
  specialization text[],
  years_experience integer,
  consultation_price numeric,
  rating numeric,
  review_count integer,
  verified boolean,
  availability boolean,
  services jsonb
)
language sql
stable
security definer
set search_path=public
as $$
  select d.lawyer_profile_id, d.profile_id, d.full_name, d.avatar_url, d.bio,
         d.specialization, d.years_experience, d.consultation_price, d.rating,
         d.review_count, d.is_verified, d.availability, d.services
  from public.public_lawyer_directory d
  join public.profiles p on p.id=d.profile_id
  where d.is_verified is true
    and p.status='active'::public.account_status
    and p.role='lawyer'::public.user_role
  order by d.lawyer_profile_id
  limit least(greatest(coalesce(p_limit,20),1),100)
  offset greatest(coalesce(p_offset,0),0);
$$;

create or replace function public.get_public_lawyer(p_profile_id uuid)
returns table(
  id uuid,
  profile_id uuid,
  full_name text,
  avatar_url text,
  bio text,
  specialization text[],
  years_experience integer,
  consultation_price numeric,
  rating numeric,
  review_count integer,
  verified boolean,
  availability boolean,
  services jsonb
)
language sql
stable
security definer
set search_path=public
as $$
  select d.lawyer_profile_id, d.profile_id, d.full_name, d.avatar_url, d.bio,
         d.specialization, d.years_experience, d.consultation_price, d.rating,
         d.review_count, d.is_verified, d.availability, d.services
  from public.public_lawyer_directory d
  join public.profiles p on p.id=d.profile_id
  where d.profile_id=p_profile_id
    and d.is_verified is true
    and p.status='active'::public.account_status
    and p.role='lawyer'::public.user_role;
$$;

revoke all on function public.get_public_lawyers(integer,integer) from public;
revoke all on function public.get_public_lawyer(uuid) from public;
grant execute on function public.get_public_lawyers(integer,integer) to anon,authenticated;
grant execute on function public.get_public_lawyer(uuid) to anon,authenticated;