-- Preserve compatible direct inserts for custom consultation requests while
-- enforcing the same core invariants as create_custom_consultation_request().

create or replace function public.protect_custom_consultation_insert()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  if (select auth.uid()) is null then
    return new;
  end if;

  perform public.require_active_actor();

  if not public.is_profile_owned_by_actor(new.user_id) then
    raise exception 'لا يمكن إنشاء طلب استشارة باسم مستخدم آخر';
  end if;

  if not exists (
    select 1
    from public.profiles p
    join public.lawyer_profiles lp on lp.profile_id=p.id
    where p.id=new.lawyer_id
      and p.role='lawyer'::public.user_role
      and p.status='active'::public.account_status
      and lp.verified=true
      and lp.availability=true
  ) then
    raise exception 'المحامي غير متاح حالياً';
  end if;

  if new.consultation_type not in ('نصية','صوتية','فيديو') then
    raise exception 'نوع الاستشارة غير صالح';
  end if;

  if nullif(trim(coalesce(new.subject,'')),'') is null
     or nullif(trim(coalesce(new.description,'')),'') is null then
    raise exception 'موضوع الاستشارة ووصفها مطلوبان';
  end if;

  new.subject := trim(new.subject);
  new.description := trim(new.description);
  new.status := 'جديد';
  new.created_at := now();
  new.updated_at := now();
  return new;
end;
$$;

revoke all on function public.protect_custom_consultation_insert() from public, anon, authenticated;

drop trigger if exists protect_custom_consultation_insert on public.custom_consultation_requests;
create trigger protect_custom_consultation_insert
before insert on public.custom_consultation_requests
for each row execute function public.protect_custom_consultation_insert();

drop policy if exists custom_requests_insert_own on public.custom_consultation_requests;
create policy custom_requests_insert_own
on public.custom_consultation_requests
for insert to authenticated
with check (
  public.is_profile_owned_by_actor(user_id)
  and status='جديد'
  and consultation_type in ('نصية','صوتية','فيديو')
  and exists (
    select 1
    from public.profiles p
    join public.lawyer_profiles lp on lp.profile_id=p.id
    where p.id=lawyer_id
      and p.role='lawyer'::public.user_role
      and p.status='active'::public.account_status
      and lp.verified=true
      and lp.availability=true
  )
);