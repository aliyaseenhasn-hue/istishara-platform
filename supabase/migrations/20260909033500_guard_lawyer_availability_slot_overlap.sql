create or replace function public.guard_lawyer_availability_slot()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.starts_at <= now() then
    raise exception 'يجب أن يكون موعد التوفر في المستقبل';
  end if;
  if new.ends_at <= new.starts_at then
    raise exception 'وقت نهاية الموعد يجب أن يكون بعد وقت البداية';
  end if;
  if exists (
    select 1
    from public.lawyer_availability_slots s
    where s.lawyer_id = new.lawyer_id
      and s.id is distinct from new.id
      and tstzrange(s.starts_at, s.ends_at, '[)') && tstzrange(new.starts_at, new.ends_at, '[)')
  ) then
    raise exception 'يوجد موعد آخر متداخل مع هذا الوقت';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_lawyer_availability_slot on public.lawyer_availability_slots;
create trigger trg_guard_lawyer_availability_slot
before insert or update of lawyer_id, starts_at, ends_at
on public.lawyer_availability_slots
for each row
execute function public.guard_lawyer_availability_slot();