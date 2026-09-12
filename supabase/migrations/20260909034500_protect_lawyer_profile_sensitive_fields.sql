create or replace function public.protect_lawyer_profile_sensitive_fields()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_owner boolean := false;
begin
  if auth.uid() is null then
    return new;
  end if;

  select exists(
    select 1 from public.profiles p
    where p.id = old.profile_id and p.auth_id = auth.uid()
  ) into v_owner;

  if v_owner and not public.is_admin() and public.get_my_role() <> 'moderator'::public.user_role then
    if new.id is distinct from old.id
       or new.profile_id is distinct from old.profile_id
       or new.verified is distinct from old.verified
       or new.rating is distinct from old.rating
       or new.review_count is distinct from old.review_count
       or new.completed_consultations is distinct from old.completed_consultations
       or new.specialization is distinct from old.specialization
       or new.created_at is distinct from old.created_at
       or new.full_name is distinct from old.full_name then
      raise exception 'لا يمكن للمحامي تعديل حقول التوثيق أو التقييم أو التخصص مباشرة';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists protect_lawyer_profile_sensitive_fields on public.lawyer_profiles;
create trigger protect_lawyer_profile_sensitive_fields
before update on public.lawyer_profiles
for each row
execute function public.protect_lawyer_profile_sensitive_fields();