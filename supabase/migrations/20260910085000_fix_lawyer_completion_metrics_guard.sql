-- Allow the booking completion trigger to update the lawyer's system-managed
-- completed_consultations counter without weakening protection against direct
-- lawyer edits to verification, rating, counters, or specialization fields.

create or replace function public.protect_lawyer_profile_sensitive_fields()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $$
declare
  v_owner boolean := false;
  v_requested_verification_status text;
  v_requested_rejection_reason text;
  v_resubmitting boolean := false;
  v_specialization_mode text := coalesce(current_setting('app.specialization_change_mode', true), '');
  v_internal_completed_update boolean :=
    coalesce(current_setting('app.internal_completed_consultation_update', true), '') = '1'
    and pg_trigger_depth() > 1;
begin
  if current_setting('app.allow_account_closure', true) = '1' then
    return new;
  end if;
  if auth.uid() is null then return new; end if;

  select exists(
    select 1 from public.profiles p
    where p.id=old.profile_id and p.auth_id=auth.uid()
  ) into v_owner;

  if v_owner and not public.is_admin() and public.get_my_role() <> 'moderator'::public.user_role then
    v_requested_verification_status := new.verification_status;
    v_requested_rejection_reason := new.rejection_reason;

    if v_requested_verification_status is distinct from old.verification_status
       or v_requested_rejection_reason is distinct from old.rejection_reason then
      raise exception 'لا يمكن للمحامي تعديل حالة التوثيق أو سبب الرفض مباشرة';
    end if;

    if new.id is distinct from old.id
       or new.profile_id is distinct from old.profile_id
       or new.verified is distinct from old.verified
       or new.rating is distinct from old.rating
       or new.review_count is distinct from old.review_count
       or (
         new.completed_consultations is distinct from old.completed_consultations
         and not (
           v_internal_completed_update
           and coalesce(new.completed_consultations, 0) = coalesce(old.completed_consultations, 0) + 1
         )
       )
       or (
         new.specialization is distinct from old.specialization
         and v_specialization_mode not in ('additional_direct', 'primary_review')
       )
       or new.created_at is distinct from old.created_at
       or new.full_name is distinct from old.full_name then
      raise exception 'لا يمكن للمحامي تعديل حقول التوثيق أو التقييم أو التخصص مباشرة';
    end if;

    v_resubmitting := old.verification_status='rejected' and (
      new.license_number is distinct from old.license_number
      or new.practice_license_class is distinct from old.practice_license_class
      or new.bio is distinct from old.bio
      or new.years_experience is distinct from old.years_experience
      or new.consultation_price is distinct from old.consultation_price
      or new.id_card_url is distinct from old.id_card_url
      or new.services is distinct from old.services
    );

    if v_resubmitting then
      new.verification_status := 'pending';
      new.rejection_reason := null;
      new.verified := false;
    end if;
  end if;

  if new.verified=true then
    new.verification_status := 'approved';
    new.rejection_reason := null;
  elsif old.verified=true and new.verified=false and public.is_admin() then
    if new.verification_status='approved' then new.verification_status := 'pending'; end if;
  end if;

  return new;
end;
$$;

create or replace function public.track_completed_consultation()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if old.status <> 'مكتمل' and new.status = 'مكتمل' then
    new.completed_at := coalesce(new.completed_at, now());

    -- The profile counter is system-managed. Mark only this nested update so the
    -- profile guard can permit exactly a +1 change while still rejecting direct edits.
    perform set_config('app.internal_completed_consultation_update', '1', true);
    update public.lawyer_profiles
    set completed_consultations = coalesce(completed_consultations, 0) + 1
    where profile_id = new.lawyer_id;
    perform set_config('app.internal_completed_consultation_update', '', true);
  end if;

  if new.status='ملغي' then
    new.cancelled_at := coalesce(new.cancelled_at, now());
  end if;
  return new;
end;
$$;
