create or replace function public.update_own_lawyer_wallet_number(p_wallet_number text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_wallet text := nullif(trim(coalesce(p_wallet_number, '')), '');
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  if not exists (
    select 1 from public.profiles
    where auth_id = auth.uid() and role = 'lawyer'
  ) then
    raise exception 'هذا الإجراء متاح للمحامين فقط';
  end if;

  if v_wallet is null then
    raise exception 'رقم المحفظة مطلوب';
  end if;

  if length(v_wallet) < 5 or length(v_wallet) > 32 then
    raise exception 'رقم المحفظة غير صالح';
  end if;

  update public.profiles
  set wallet_number = v_wallet
  where auth_id = auth.uid() and role = 'lawyer';

  if not found then
    raise exception 'تعذر تحديث رقم المحفظة';
  end if;
end;
$$;

revoke all on function public.update_own_lawyer_wallet_number(text) from public;
grant execute on function public.update_own_lawyer_wallet_number(text) to authenticated;
