-- صلاحية المحامي: معلومة مهنية داخلية لا تدخل ضمن بيانات المحامي العامة.
alter table public.lawyer_profiles
  add column if not exists practice_license_class text;

alter table public.lawyer_profiles
  drop constraint if exists lawyer_profiles_practice_license_class_check;

alter table public.lawyer_profiles
  add constraint lawyer_profiles_practice_license_class_check
  check (
    practice_license_class is null
    or practice_license_class in ('أ', 'ب', 'ج', 'مطلقة')
  );

comment on column public.lawyer_profiles.practice_license_class is
  'تصنيف صلاحية ممارسة المحامي: أ، ب، ج، أو مطلقة. معلومة إدارية داخلية ولا تظهر في واجهات العميل.';
