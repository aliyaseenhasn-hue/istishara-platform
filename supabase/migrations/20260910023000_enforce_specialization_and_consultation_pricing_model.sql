-- Production rules for the launch model:
-- 1 primary specialization + up to 2 additional specializations.
-- Consultation prices are bounded by platform financial settings.

alter table public.platform_financial_settings
  add column if not exists consultation_min_price numeric not null default 20000,
  add column if not exists consultation_max_price numeric not null default 50000,
  add column if not exists consultation_price_options numeric[] not null default array[20000,25000,30000,40000,50000]::numeric[];

update public.platform_financial_settings
set consultation_min_price = 20000,
    consultation_max_price = 50000,
    consultation_price_options = array[20000,25000,30000,40000,50000]::numeric[],
    updated_at = now()
where id = true;

alter table public.platform_financial_settings
  drop constraint if exists platform_financial_settings_consultation_price_range_check;
alter table public.platform_financial_settings
  add constraint platform_financial_settings_consultation_price_range_check
  check (consultation_min_price > 0 and consultation_max_price >= consultation_min_price);

create or replace function public.get_consultation_pricing_config()
returns table(min_price numeric, max_price numeric, price_options numeric[])
language sql
stable
security definer
set search_path = public
as $$
  select consultation_min_price, consultation_max_price, consultation_price_options
  from public.platform_financial_settings
  where id = true;
$$;
revoke all on function public.get_consultation_pricing_config() from public, anon;
grant execute on function public.get_consultation_pricing_config() to authenticated;

-- Normalize existing data before enforcing the new limits.
update public.lawyer_profiles
set specialization = case
  when specialization is null then null
  else (array_remove(specialization, 'استشارات قانونية'))[1:3]
end,
updated_at = now();

update public.specialization_change_requests
set requested_specializations = (array_remove(requested_specializations, 'استشارات قانونية'))[1:3]
where requested_specializations is not null;

update public.lawyer_profiles lp
set consultation_price = least(50000::numeric, greatest(20000::numeric, lp.consultation_price))
where lp.consultation_price is not null
  and (lp.consultation_price < 20000 or lp.consultation_price > 50000);

update public.lawyer_availability_slots s
set price = least(50000::numeric, greatest(20000::numeric, s.price))
where s.price is not null
  and (s.price < 20000 or s.price > 50000);

update public.lawyer_profiles lp
set services = coalesce((
  select jsonb_agg(
    case
      when jsonb_typeof(item) <> 'object' then item
      else jsonb_set(
        item,
        '{price}',
        to_jsonb(
          least(
            50000::numeric,
            greatest(
              20000::numeric,
              case
                when coalesce(item->>'price','') ~ '^[0-9]+([.][0-9]+)?$'
                  then (item->>'price')::numeric
                else 20000::numeric
              end
            )
          )
        ),
        true
      )
    end
    order by ord
  )
  from jsonb_array_elements(coalesce(lp.services, '[]'::jsonb)) with ordinality as e(item, ord)
), '[]'::jsonb)
where lp.services is not null;

-- The first array element is the primary specialization.
alter table public.lawyer_profiles
  add column if not exists primary_specialization text
  generated always as (specialization[1]) stored;

create or replace function public.validate_lawyer_specializations()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_count integer;
  v_distinct_count integer;
begin
  if new.specialization is null then return new; end if;

  v_count := coalesce(cardinality(new.specialization), 0);
  if v_count < 1 or v_count > 3 then
    raise exception 'يجب اختيار تخصص رئيسي واحد ويمكن إضافة تخصصين فقط';
  end if;

  if array_position(new.specialization, 'استشارات قانونية') is not null
     or array_position(new.specialization, 'عام') is not null
     or array_position(new.specialization, 'تخصص عام') is not null then
    raise exception 'لا يوجد تخصص عام للمحامي؛ اختر تخصصاً قانونياً محدداً';
  end if;

  select count(distinct trim(x)) into v_distinct_count
  from unnest(new.specialization) as u(x)
  where nullif(trim(x), '') is not null;

  if v_distinct_count <> v_count then
    raise exception 'لا يمكن تكرار التخصص نفسه';
  end if;

  if exists (select 1 from unnest(new.specialization) as u(x) where nullif(trim(x), '') is null) then
    raise exception 'التخصص لا يمكن أن يكون فارغاً';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validate_lawyer_specializations on public.lawyer_profiles;
create trigger trg_validate_lawyer_specializations
before insert or update of specialization on public.lawyer_profiles
for each row execute function public.validate_lawyer_specializations();

create or replace function public.validate_lawyer_profile_pricing()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_min numeric := 20000;
  v_max numeric := 50000;
  v_item jsonb;
  v_price numeric;
begin
  select consultation_min_price, consultation_max_price
    into v_min, v_max
  from public.platform_financial_settings
  where id = true;

  v_min := coalesce(v_min, 20000);
  v_max := coalesce(v_max, 50000);

  if new.consultation_price is not null
     and (new.consultation_price < v_min or new.consultation_price > v_max) then
    raise exception 'سعر الاستشارة يجب أن يكون بين % و % د.ع', v_min, v_max;
  end if;

  if new.services is not null and jsonb_typeof(new.services) = 'array' then
    for v_item in select value from jsonb_array_elements(new.services)
    loop
      if jsonb_typeof(v_item) = 'object' and v_item ? 'price' then
        begin
          v_price := (v_item->>'price')::numeric;
        exception when others then
          raise exception 'سعر إحدى الباقات غير صالح';
        end;
        if v_price < v_min or v_price > v_max then
          raise exception 'سعر كل باقة يجب أن يكون بين % و % د.ع', v_min, v_max;
        end if;
      end if;
    end loop;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validate_lawyer_profile_pricing on public.lawyer_profiles;
create trigger trg_validate_lawyer_profile_pricing
before insert or update of consultation_price, services on public.lawyer_profiles
for each row execute function public.validate_lawyer_profile_pricing();

create or replace function public.validate_availability_slot_price()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_min numeric := 20000;
  v_max numeric := 50000;
begin
  select consultation_min_price, consultation_max_price
    into v_min, v_max
  from public.platform_financial_settings
  where id = true;

  v_min := coalesce(v_min, 20000);
  v_max := coalesce(v_max, 50000);

  if new.price is not null and (new.price < v_min or new.price > v_max) then
    raise exception 'سعر الموعد يجب أن يكون بين % و % د.ع', v_min, v_max;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_validate_availability_slot_price on public.lawyer_availability_slots;
create trigger trg_validate_availability_slot_price
before insert or update of price on public.lawyer_availability_slots
for each row execute function public.validate_availability_slot_price();

-- The request order is meaningful: [1] primary, [2..3] additional.
create or replace function public.request_specialization_change(
  p_requested_specializations text[],
  p_union_id_card_url text
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_lawyer_id uuid;
  v_request_id uuid;
  v_requested text[];
  v_count integer;
  v_distinct_count integer;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;

  select p.id into v_lawyer_id
  from public.profiles p
  where p.auth_id = auth.uid()
    and p.role = 'lawyer'
    and p.status = 'active'
  limit 1;

  if v_lawyer_id is null then
    raise exception 'هذا الإجراء متاح للمحامي ذي الحساب الفعال فقط';
  end if;

  select array_agg(trim(x) order by ord)
    into v_requested
  from unnest(p_requested_specializations) with ordinality as u(x, ord)
  where nullif(trim(x), '') is not null;

  v_count := coalesce(cardinality(v_requested), 0);
  if v_count < 1 or v_count > 3 then
    raise exception 'اختر تخصصاً رئيسياً واحداً ويمكن إضافة تخصصين فقط';
  end if;

  if array_position(v_requested, 'استشارات قانونية') is not null
     or array_position(v_requested, 'عام') is not null
     or array_position(v_requested, 'تخصص عام') is not null then
    raise exception 'لا يمكن اختيار تخصص عام للمحامي';
  end if;

  select count(distinct x) into v_distinct_count from unnest(v_requested) as u(x);
  if v_distinct_count <> v_count then raise exception 'لا يمكن تكرار التخصص نفسه'; end if;

  if exists (
    select 1 from public.specialization_change_requests
    where lawyer_id = v_lawyer_id and status = 'pending'
  ) then
    raise exception 'لديك طلب تغيير تخصص قيد المراجعة بالفعل';
  end if;

  if nullif(trim(coalesce(p_union_id_card_url, '')), '') is null then
    raise exception 'هوية النقابة مطلوبة لمراجعة تغيير التخصص';
  end if;

  insert into public.specialization_change_requests(
    lawyer_id, requested_specializations, union_id_card_url, status
  ) values (
    v_lawyer_id, v_requested, trim(p_union_id_card_url), 'pending'
  ) returning id into v_request_id;

  return v_request_id;
end;
$$;

revoke all on function public.request_specialization_change(text[],text) from public, anon;
grant execute on function public.request_specialization_change(text[],text) to authenticated;
