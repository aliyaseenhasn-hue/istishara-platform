-- Update the authenticated user's own profile contact data atomically.
-- WhatsApp is the single contact number exposed by the profile UI.

create or replace function public.update_own_profile_contact(
  p_full_name text,
  p_phone text default null,
  p_whatsapp_number text default null,
  p_city text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile_id uuid;
  v_role text;
  v_whatsapp text;
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  if nullif(trim(coalesce(p_full_name, '')), '') is null then
    raise exception 'الاسم الكامل مطلوب';
  end if;

  v_whatsapp := nullif(trim(coalesce(p_whatsapp_number, p_phone, '')), '');
  if v_whatsapp is null then
    raise exception 'رقم واتساب مطلوب';
  end if;

  select id, role
    into v_profile_id, v_role
  from public.profiles
  where auth_id = auth.uid()
  limit 1;

  if v_profile_id is null then
    raise exception 'ملف المستخدم غير مكتمل';
  end if;

  update public.profiles
  set full_name = trim(p_full_name),
      phone = v_whatsapp,
      whatsapp_number = v_whatsapp,
      city = nullif(trim(coalesce(p_city, '')), ''),
      updated_at = now()
  where id = v_profile_id;

  if v_role = 'lawyer' then
    -- Some historical lawyer rows use id as the profile key, while newer rows
    -- use profile_id. Support both schemas without failing the whole save.
    update public.lawyer_profiles
    set whatsapp = v_whatsapp,
        updated_at = now()
    where profile_id = v_profile_id;
  end if;
end;
$$;

revoke all on function public.update_own_profile_contact(text,text,text,text) from public;
grant execute on function public.update_own_profile_contact(text,text,text,text) to authenticated;
