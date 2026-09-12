-- Lock consultation and package prices to the agreed launch range: 20,000–50,000 IQD.

update public.platform_financial_settings
set consultation_min_price = 20000,
    consultation_max_price = 50000,
    updated_at = now()
where id = true;

alter table public.platform_financial_settings
  drop constraint if exists platform_financial_settings_consultation_price_range_check;
alter table public.platform_financial_settings
  drop constraint if exists platform_financial_settings_consultation_price_launch_bounds_check;
alter table public.platform_financial_settings
  add constraint platform_financial_settings_consultation_price_launch_bounds_check
  check (consultation_min_price = 20000 and consultation_max_price = 50000);

create or replace function public.get_consultation_pricing_config()
returns table(min_price numeric, max_price numeric, price_options numeric[])
language sql
stable
security definer
set search_path = public
as $$
  select
    20000::numeric as min_price,
    50000::numeric as max_price,
    coalesce(
      (
        select array_agg(x order by x)
        from (
          select distinct value as x
          from unnest(coalesce(s.consultation_price_options, array[]::numeric[])) as u(value)
          where value between 20000 and 50000
        ) q
      ),
      array[20000,25000,30000,40000,50000]::numeric[]
    ) as price_options
  from public.platform_financial_settings s
  where s.id = true;
$$;

revoke all on function public.get_consultation_pricing_config() from public, anon;
grant execute on function public.get_consultation_pricing_config() to authenticated;

create or replace function public.validate_lawyer_profile_pricing()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_min constant numeric := 20000;
  v_max constant numeric := 50000;
  v_item jsonb;
  v_price numeric;
begin
  if new.consultation_price is not null
     and (new.consultation_price < v_min or new.consultation_price > v_max) then
    raise exception 'سعر الاستشارة يجب أن يكون بين 20,000 و50,000 د.ع';
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
          raise exception 'سعر كل باقة يجب أن يكون بين 20,000 و50,000 د.ع';
        end if;
      end if;
    end loop;
  end if;

  return new;
end;
$$;

create or replace function public.validate_availability_slot_price()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_min constant numeric := 20000;
  v_max constant numeric := 50000;
begin
  if new.price is not null and (new.price < v_min or new.price > v_max) then
    raise exception 'سعر الموعد يجب أن يكون بين 20,000 و50,000 د.ع';
  end if;
  return new;
end;
$$;
