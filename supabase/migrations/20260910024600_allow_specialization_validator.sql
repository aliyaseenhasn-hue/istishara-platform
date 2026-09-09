-- The lawyer-profile validation trigger runs under the authenticated caller.
-- Allow it to evaluate the fixed specialization allow-list during initial profile
-- creation and trusted specialization updates.
grant execute on function public.is_allowed_lawyer_specialization(text) to authenticated;
