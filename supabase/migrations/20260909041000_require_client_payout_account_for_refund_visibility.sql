create or replace function public.get_booking_cancellation_summary(p_booking_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_me uuid;
  v_b public.bookings%rowtype;
  v_req jsonb;
  v_credits jsonb;
  v_actor_name text;
  v_has_payout boolean:=false;
  v_payout_provider text;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  select id into v_me from public.profiles where auth_id=auth.uid() limit 1;
  select * into v_b from public.bookings where id=p_booking_id;
  if not found or ((v_me<>v_b.user_id and v_me<>v_b.lawyer_id) and not public.is_admin()) then raise exception 'غير مصرح'; end if;

  if v_b.cancelled_by_profile_id is not null then
    select coalesce(nullif(trim(p.full_name),''),case when v_b.cancellation_actor_role='lawyer' then 'المحامي' when v_b.cancellation_actor_role='client' then 'طالب الاستشارة' else 'الإدارة' end)
    into v_actor_name from public.profiles p where p.id=v_b.cancelled_by_profile_id;
  end if;

  select to_jsonb(x) into v_req
  from (
    select cr.id,cr.status,cr.reason,cr.decision,cr.penalty_rate,cr.penalty_amount,cr.currency,cr.requested_at,cr.reviewed_at
    from public.cancellation_requests cr
    where cr.booking_id=p_booking_id
    order by cr.requested_at desc limit 1
  ) x;

  if v_me=v_b.user_id or public.is_admin() then
    select exists(
      select 1 from public.client_payout_accounts a
      where a.user_id=v_b.user_id and a.is_default=true
        and nullif(trim(coalesce(a.account_number,'')),'') is not null
        and a.account_number<>'REMOVED'
    ) into v_has_payout;

    select a.provider_type into v_payout_provider
    from public.client_payout_accounts a
    where a.user_id=v_b.user_id and a.is_default=true and a.account_number<>'REMOVED'
    limit 1;

    select coalesce(jsonb_agg(jsonb_build_object(
      'id',c.id,'amount',c.amount,'currency',c.currency,'transaction_type',c.transaction_type,'status',c.status,
      'created_at',c.created_at,'settled_at',c.settled_at,'settlement_status',s.status,
      'provider_type',s.provider_type,'provider_reference',s.provider_reference,'paid_at',s.paid_at
    ) order by c.created_at),'[]'::jsonb)
    into v_credits
    from public.client_credits c
    left join public.client_credit_settlements s on s.credit_id=c.id
    where c.booking_id=p_booking_id;
  else
    v_credits:='[]'::jsonb;
  end if;

  return jsonb_build_object(
    'booking_status',v_b.status,
    'cancelled_at',v_b.cancelled_at,
    'cancelled_by_profile_id',v_b.cancelled_by_profile_id,
    'cancelled_by_name',v_actor_name,
    'cancellation_actor_role',v_b.cancellation_actor_role,
    'cancellation_reason',v_b.cancellation_reason,
    'cancellation_source',v_b.cancellation_source,
    'cancellation_request',v_req,
    'credits',v_credits,
    'has_payout_account',v_has_payout,
    'payout_provider',v_payout_provider
  );
end $$;

create or replace function public.ensure_client_refund_credit_for_booking()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
  v_payment public.payments%rowtype;
  v_currency text:='IQD';
  v_has_account boolean:=false;
begin
  if new.status='بانتظار الاسترداد' and old.status is distinct from new.status then
    select * into v_payment
    from public.payments
    where booking_id=new.id and status='تم الدفع'
    order by created_at desc limit 1;
    if found then
      select coalesce(currency,'IQD') into v_currency from public.platform_financial_settings where id=true;
      insert into public.client_credits(user_id,booking_id,lawyer_id,amount,currency,transaction_type,status,reference_id)
      values(new.user_id,new.id,new.lawyer_id,v_payment.amount,v_currency,'استرداد قيمة استشارة','مستحق',v_payment.id)
      on conflict (booking_id,transaction_type) where booking_id is not null do nothing;

      select exists(
        select 1 from public.client_payout_accounts a
        where a.user_id=new.user_id and a.is_default=true and a.account_number<>'REMOVED'
          and nullif(trim(coalesce(a.account_number,'')),'') is not null
      ) into v_has_account;

      perform public.enqueue_user_notification(
        new.user_id,
        case when v_has_account then 'تم إنشاء طلب استرداد' else 'أضف حساب استلام لإكمال الاسترداد' end,
        case when v_has_account then
          'تم تسجيل كامل قيمة الاستشارة للاسترداد. ستقوم الإدارة بتحويلها إلى حساب الاستلام المرتبط.'
        else
          'تم تسجيل كامل قيمة الاستشارة للاسترداد، لكن لا يوجد حساب استلام مرتبط. افتح تفاصيل الاستشارة ثم أضف حساب استلام حتى تتمكن الإدارة من تحويل المبلغ.'
        end,
        case when v_has_account then 'client_refund_pending' else 'client_refund_account_required' end,
        new.id,'booking'
      );
    end if;
  end if;
  return new;
end $$;
