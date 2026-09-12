create or replace function public.normalize_iraqi_phone_for_identity(p_phone text)
returns text
language plpgsql
immutable
set search_path = public
as $$
declare
  v text := regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g');
begin
  if v = '' then return null; end if;
  if v like '00%' then v := substr(v, 3); end if;
  if v like '0%' then v := '964' || substr(v, 2); end if;
  if v not like '964%' then v := '964' || v; end if;
  return v;
end;
$$;

create or replace function public.resolve_telegram_login_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile_id uuid;
begin
  if new.mode = 'login' and new.telegram_user_id is not null then
    select p.id
      into v_profile_id
    from public.profiles p
    where p.telegram_user_id = new.telegram_user_id
      and public.normalize_iraqi_phone_for_identity(p.phone) = public.normalize_iraqi_phone_for_identity(new.phone)
    limit 1;

    if v_profile_id is not null then
      new.verified_profile_id := v_profile_id;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_resolve_telegram_login_profile on public.telegram_login_requests;
create trigger trg_resolve_telegram_login_profile
before insert or update of telegram_user_id, verified_profile_id, status
on public.telegram_login_requests
for each row
execute function public.resolve_telegram_login_profile();

update public.telegram_login_requests r
set verified_profile_id = p.id
from public.profiles p
where r.mode = 'login'
  and r.telegram_user_id is not null
  and r.session_claimed_at is null
  and r.status in ('waiting', 'code_sent', 'telegram_verified')
  and p.telegram_user_id = r.telegram_user_id
  and public.normalize_iraqi_phone_for_identity(p.phone) = public.normalize_iraqi_phone_for_identity(r.phone)
  and r.verified_profile_id is distinct from p.id;

revoke all on function public.resolve_telegram_login_profile() from public, anon, authenticated;
revoke all on function public.normalize_iraqi_phone_for_identity(text) from public, anon;
grant execute on function public.normalize_iraqi_phone_for_identity(text) to authenticated;
