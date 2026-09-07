-- Prevent authenticated users from creating their own profile with privileged
-- values. Service-role/server flows bypass RLS and remain unaffected.
-- Self-registration may choose only the supported public roles: user/lawyer.

alter policy "profiles_insert_auth"
on public.profiles
with check (
  (select auth.uid()) = auth_id
  and role = any (array['user'::public.user_role, 'lawyer'::public.user_role])
  and coalesce(is_verified, false) = false
  and coalesce(status, 'active'::public.account_status) = 'active'::public.account_status
  and telegram_user_id is null
);
