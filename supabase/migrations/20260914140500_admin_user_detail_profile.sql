-- Protected unified admin profile for consultation requesters and lawyers.
-- Exposes operational data only and intentionally omits auth/telegram internals.

create or replace function public.admin_get_user_detail(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $$
declare
  v_target public.profiles%rowtype;
  v_lawyer jsonb := null;
  v_wallet jsonb := null;
  v_booking_summary jsonb;
  v_payment_summary jsonb;
  v_recent_bookings jsonb := '[]'::jsonb;
  v_recent_payments jsonb := '[]'::jsonb;
  v_recent_payouts jsonb := '[]'::jsonb;
begin
  if not exists (
    select 1
    from public.profiles me
    where me.auth_id = auth.uid()
      and me.role = 'admin'
      and me.status = 'active'
  ) then
    raise exception 'غير مصرح';
  end if;

  select * into v_target
  from public.profiles
  where id = p_user_id;

  if not found then
    raise exception 'المستخدم غير موجود';
  end if;

  if v_target.role = 'lawyer' then
    select jsonb_build_object(
      'license_number', lp.license_number,
      'practice_license_class', lp.practice_license_class,
      'bio', lp.bio,
      'years_experience', lp.years_experience,
      'consultation_price', lp.consultation_price,
      'rating', lp.rating,
      'review_count', lp.review_count,
      'verified', lp.verified,
      'availability', lp.availability,
      'verification_status', lp.verification_status,
      'rejection_reason', lp.rejection_reason,
      'primary_specialization', lp.primary_specialization,
      'specialization', coalesce(to_jsonb(lp.specialization), '[]'::jsonb),
      'completed_consultations', lp.completed_consultations
    ) into v_lawyer
    from public.lawyer_profiles lp
    where lp.profile_id = v_target.id
    limit 1;

    select jsonb_build_object(
      'available_balance', coalesce(lw.available_balance, 0),
      'pending_balance', coalesce(lw.pending_balance, 0),
      'lifetime_earned', coalesce(lw.lifetime_earned, 0),
      'lifetime_paid_out', coalesce(lw.lifetime_paid_out, 0),
      'currency', coalesce(lw.currency, 'IQD'),
      'updated_at', lw.updated_at
    ) into v_wallet
    from public.lawyer_wallets lw
    where lw.lawyer_id = v_target.id
    limit 1;
  end if;

  select jsonb_build_object(
    'total', count(*),
    'completed', count(*) filter (where b.completed_at is not null),
    'cancelled', count(*) filter (where b.cancelled_at is not null),
    'active', count(*) filter (
      where b.completed_at is null
        and b.cancelled_at is null
        and b.status not in ('ملغي', 'مرفوض')
    )
  ) into v_booking_summary
  from public.bookings b
  where (v_target.role = 'lawyer' and b.lawyer_id = v_target.id)
     or (v_target.role <> 'lawyer' and b.user_id = v_target.id);

  select jsonb_build_object(
    'paid_total', coalesce(sum(pay.amount) filter (where pay.status = 'تم الدفع'), 0),
    'paid_count', count(*) filter (where pay.status = 'تم الدفع'),
    'pending_count', count(*) filter (where pay.status in ('قيد معالجة الدفع', 'بانتظار الدفع')),
    'total_count', count(*)
  ) into v_payment_summary
  from public.payments pay
  join public.bookings b on b.id = pay.booking_id
  where (v_target.role = 'lawyer' and b.lawyer_id = v_target.id)
     or (v_target.role <> 'lawyer' and b.user_id = v_target.id);

  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc), '[]'::jsonb)
  into v_recent_bookings
  from (
    select
      b.id,
      b.status,
      b.scheduled_at,
      b.price,
      b.consultation_type,
      b.consultation_mode,
      b.created_at,
      case
        when v_target.role = 'lawyer' then coalesce(client.full_name, 'طالب استشارة')
        else coalesce(lawyer.full_name, 'محامٍ')
      end as other_party_name
    from public.bookings b
    left join public.profiles client on client.id = b.user_id
    left join public.profiles lawyer on lawyer.id = b.lawyer_id
    where (v_target.role = 'lawyer' and b.lawyer_id = v_target.id)
       or (v_target.role <> 'lawyer' and b.user_id = v_target.id)
    order by b.created_at desc
    limit 10
  ) x;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc), '[]'::jsonb)
  into v_recent_payments
  from (
    select
      pay.id,
      pay.booking_id,
      pay.amount,
      pay.payment_method,
      pay.status,
      pay.is_manual,
      pay.created_at,
      pay.verified_at
    from public.payments pay
    join public.bookings b on b.id = pay.booking_id
    where (v_target.role = 'lawyer' and b.lawyer_id = v_target.id)
       or (v_target.role <> 'lawyer' and b.user_id = v_target.id)
    order by pay.created_at desc
    limit 10
  ) x;

  if v_target.role = 'lawyer' then
    select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc), '[]'::jsonb)
    into v_recent_payouts
    from (
      select
        pr.id,
        pr.amount,
        pr.currency,
        pr.status,
        pr.wallet_type,
        pr.wallet_number,
        pr.wallet_holder_name,
        pr.created_at,
        pr.completed_at,
        pr.rejection_reason
      from public.lawyer_payout_requests pr
      where pr.lawyer_id = v_target.id
      order by pr.created_at desc
      limit 10
    ) x;
  end if;

  return jsonb_build_object(
    'profile', jsonb_build_object(
      'id', v_target.id,
      'full_name', v_target.full_name,
      'phone', v_target.phone,
      'email', v_target.email,
      'whatsapp_number', v_target.whatsapp_number,
      'avatar_url', v_target.avatar_url,
      'city', v_target.city,
      'role', v_target.role::text,
      'status', v_target.status::text,
      'is_verified', v_target.is_verified,
      'onboarding_completed', v_target.onboarding_completed,
      'created_at', v_target.created_at,
      'updated_at', v_target.updated_at,
      'wallet_type', v_target.wallet_type,
      'wallet_number', v_target.wallet_number,
      'wallet_holder_name', v_target.wallet_holder_name
    ),
    'lawyer', v_lawyer,
    'lawyer_wallet', v_wallet,
    'booking_summary', coalesce(v_booking_summary, '{}'::jsonb),
    'payment_summary', coalesce(v_payment_summary, '{}'::jsonb),
    'recent_bookings', v_recent_bookings,
    'recent_payments', v_recent_payments,
    'recent_payouts', v_recent_payouts
  );
end;
$$;

revoke all on function public.admin_get_user_detail(uuid) from public;
revoke all on function public.admin_get_user_detail(uuid) from anon;
grant execute on function public.admin_get_user_detail(uuid) to authenticated;
