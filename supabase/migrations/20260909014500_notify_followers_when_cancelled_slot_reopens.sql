create or replace function public.notify_lawyer_followers_on_slot()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
  v_when text;
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

  v_name := coalesce(v_name, 'المحامي');
  v_when := to_char(new.starts_at at time zone 'Asia/Baghdad', 'YYYY/MM/DD HH24:MI');

  for v_follower in
    select follower_id from public.lawyer_followers where lawyer_id = new.lawyer_id
  loop
    perform public.enqueue_user_notification(
      v_follower.follower_id,
      'موعد متاح لدى ' || v_name,
      'المحامي ' || v_name || ' لديه موعد استشارة متاح بتاريخ ' || v_when || '. يمكنك الحجز الآن.',
      'lawyer_availability',
      new.lawyer_id,
      'lawyer_profile'
    );
  end loop;

  return new;
end;
$$;
