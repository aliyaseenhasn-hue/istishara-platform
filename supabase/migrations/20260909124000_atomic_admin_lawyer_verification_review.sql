create or replace function public.admin_review_lawyer_verification(
  p_profile_id uuid,
  p_approved boolean,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_lawyer public.lawyer_profiles%rowtype;
  v_reason text;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'غير مصرح: هذه العملية للإدارة فقط';
  end if;

  select * into v_lawyer
  from public.lawyer_profiles
  where profile_id = p_profile_id
  for update;

  if not found then
    raise exception 'ملف المحامي غير موجود';
  end if;

  if v_lawyer.verification_status <> 'pending' then
    raise exception 'طلب التوثيق لم يعد بانتظار المراجعة';
  end if;

  if p_approved then
    if nullif(trim(coalesce(v_lawyer.id_card_url, '')), '') is null then
      raise exception 'لا يمكن توثيق المحامي قبل رفع وثيقة تحقق';
    end if;

    update public.lawyer_profiles
    set verified = true,
        verification_status = 'approved',
        rejection_reason = null
    where profile_id = p_profile_id;

    perform public.enqueue_user_notification(
      p_profile_id,
      'تم توثيق حسابك بنجاح',
      'تمت الموافقة على ملفك المهني، ويمكنك الآن استقبال الاستشارات وإدارة ملفك.',
      'lawyer_verification_approved',
      p_profile_id,
      'lawyer_profile'
    );
  else
    v_reason := nullif(trim(coalesce(p_reason, '')), '');
    if v_reason is null then
      raise exception 'سبب إعادة الطلب للتعديل إلزامي';
    end if;

    update public.lawyer_profiles
    set verified = false,
        verification_status = 'rejected',
        rejection_reason = v_reason
    where profile_id = p_profile_id;

    perform public.enqueue_user_notification(
      p_profile_id,
      'يحتاج طلب التوثيق إلى تعديل',
      'سبب المراجعة: ' || v_reason || '. عدّل بياناتك ثم أعد إرسال الطلب.',
      'lawyer_verification_rejected',
      p_profile_id,
      'lawyer_profile'
    );
  end if;
end;
$$;

revoke all on function public.admin_review_lawyer_verification(uuid,boolean,text) from public, anon;
grant execute on function public.admin_review_lawyer_verification(uuid,boolean,text) to authenticated;
