-- Prevent a lawyer applicant from self-verifying during the initial lawyer_profiles INSERT.
-- Existing UPDATE protections remain unchanged; this adds an INSERT guard and tightens RLS.

create or replace function public.protect_lawyer_profile_insert()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  -- Trusted internal/server operations without an end-user JWT keep their existing behavior.
  if (select auth.uid()) is null then
    return new;
  end if;

  -- Administrators/moderators may create records as part of controlled review/operations.
  if public.is_admin() or public.get_my_role() = 'moderator'::public.user_role then
    return new;
  end if;

  if not public.is_profile_owned_by_actor(new.profile_id) then
    raise exception 'لا يمكن إنشاء ملف محامٍ لحساب آخر';
  end if;

  if public.get_my_role() <> 'lawyer'::public.user_role then
    raise exception 'يجب التسجيل كمحامٍ قبل إنشاء الملف المهني';
  end if;

  -- Server-controlled trust/reputation fields must start from safe values.
  if coalesce(new.verified, false) is true
     or coalesce(new.verification_status, 'pending') <> 'pending'
     or new.rejection_reason is not null
     or coalesce(new.rating, 0) <> 0
     or coalesce(new.review_count, 0) <> 0
     or coalesce(new.completed_consultations, 0) <> 0 then
    raise exception 'لا يمكن تعيين حقول التوثيق أو التقييم عند إنشاء ملف المحامي';
  end if;

  new.verified := false;
  new.verification_status := 'pending';
  new.rejection_reason := null;
  new.rating := 0;
  new.review_count := 0;
  new.completed_consultations := 0;
  return new;
end;
$$;

revoke all on function public.protect_lawyer_profile_insert() from public, anon, authenticated;

drop trigger if exists protect_lawyer_profile_insert on public.lawyer_profiles;
create trigger protect_lawyer_profile_insert
before insert on public.lawyer_profiles
for each row execute function public.protect_lawyer_profile_insert();

drop policy if exists lawyer_profiles_insert_auth on public.lawyer_profiles;
create policy lawyer_profiles_insert_auth
on public.lawyer_profiles
for insert to authenticated
with check (
  (
    public.is_profile_owned_by_actor(profile_id)
    and public.get_my_role() = 'lawyer'::public.user_role
    and coalesce(verified,false) = false
    and verification_status = 'pending'
    and rejection_reason is null
    and coalesce(rating,0) = 0
    and coalesce(review_count,0) = 0
    and coalesce(completed_consultations,0) = 0
  )
  or public.get_my_role() = any(array['admin'::public.user_role,'moderator'::public.user_role])
);