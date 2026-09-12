-- طلبات إلغاء المحامين + الغرامات + تعويضات العملاء + سجل التدقيق.
-- الحساب المالي النهائي يتم داخل PostgreSQL باستخدام numeric، ولا يعتمد على Flutter.

create table if not exists public.cancellation_requests (
  id uuid primary key default gen_random_uuid(), booking_id uuid not null references public.bookings(id) on delete restrict,
  lawyer_id uuid not null references public.profiles(id) on delete restrict, client_id uuid not null references public.profiles(id) on delete restrict,
  reason text not null, status text not null default 'بانتظار مراجعة الإدارة', requested_at timestamptz not null default now(), reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id) on delete restrict, decision text, penalty_rate numeric(7,4), penalty_amount numeric(18,2), currency text not null default 'IQD',
  check(length(trim(reason))>0), check(status in ('بانتظار مراجعة الإدارة','تم رفض الطلب','تمت الموافقة','تمت الموافقة مع غرامة','بانتظار تحصيل الغرامة','تم تحصيل الغرامة')),
  check(penalty_rate is null or (penalty_rate between 0 and 100)), check(penalty_amount is null or penalty_amount>=0)
);
create unique index if not exists cancellation_requests_pending_uniq on public.cancellation_requests(booking_id) where status='بانتظار مراجعة الإدارة';
create unique index if not exists cancellation_requests_final_uniq on public.cancellation_requests(booking_id) where status in ('تمت الموافقة','تمت الموافقة مع غرامة','بانتظار تحصيل الغرامة','تم تحصيل الغرامة');

create table if not exists public.lawyer_penalties (
  id uuid primary key default gen_random_uuid(), cancellation_request_id uuid not null unique references public.cancellation_requests(id) on delete restrict,
  booking_id uuid not null references public.bookings(id) on delete restrict, lawyer_id uuid not null references public.profiles(id) on delete restrict,
  client_id uuid not null references public.profiles(id) on delete restrict, amount numeric(18,2) not null check(amount>0), remaining_amount numeric(18,2) not null check(remaining_amount>=0),
  currency text not null default 'IQD', status text not null default 'بنتظار التحصيل', created_at timestamptz not null default now(), settled_at timestamptz,
  check(status in ('بنتظار التحصيل','تسوية جزئية','تم التحصيل'))
);
create table if not exists public.client_credits (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete restrict,
  booking_id uuid not null unique references public.bookings(id) on delete restrict, lawyer_id uuid not null references public.profiles(id) on delete restrict,
  amount numeric(18,2) not null check(amount>0), currency text not null default 'IQD', transaction_type text not null default 'تعويض إلغاء حجز من المحامي',
  status text not null default 'بانتظار تحصيل الغرامة', created_at timestamptz not null default now(), settled_at timestamptz, reference_id uuid,
  check(status in ('بانتظار تحصيل الغرامة','مستحق','مستخدم'))
);
create table if not exists public.lawyer_penalty_settlements (
  id uuid primary key default gen_random_uuid(), penalty_id uuid not null references public.lawyer_penalties(id) on delete restrict,
  payment_id uuid not null references public.payments(id) on delete restrict, lawyer_id uuid not null references public.profiles(id) on delete restrict,
  client_id uuid not null references public.profiles(id) on delete restrict, booking_id uuid not null references public.bookings(id) on delete restrict,
  amount numeric(18,2) not null check(amount>0), currency text not null default 'IQD', created_at timestamptz not null default now(), unique(penalty_id,payment_id)
);
create table if not exists public.financial_audit_log (
  id uuid primary key default gen_random_uuid(), actor_id uuid references public.profiles(id) on delete restrict, actor_role text,
  booking_id uuid references public.bookings(id) on delete restrict, lawyer_id uuid references public.profiles(id) on delete restrict, client_id uuid references public.profiles(id) on delete restrict,
  event_type text not null, decision text, penalty_rate numeric(7,4), amount numeric(18,2), currency text, previous_status text, new_status text, reference_id uuid, created_at timestamptz not null default now()
);
alter table public.cancellation_requests enable row level security; alter table public.lawyer_penalties enable row level security; alter table public.client_credits enable row level security; alter table public.lawyer_penalty_settlements enable row level security; alter table public.financial_audit_log enable row level security;
revoke all on public.cancellation_requests, public.lawyer_penalties, public.lawyer_penalty_settlements, public.financial_audit_log from anon,authenticated;
revoke insert,update,delete on public.client_credits from anon,authenticated; grant select on public.client_credits to authenticated;
drop policy if exists client_credits_select_own on public.client_credits;
create policy client_credits_select_own on public.client_credits for select to authenticated using(user_id=(select id from public.profiles where auth_id=auth.uid() limit 1));

create or replace function public.request_booking_cancellation(p_booking_id uuid,p_reason text) returns public.cancellation_requests language plpgsql security definer set search_path=public as $$
declare v_lawyer uuid; v_booking public.bookings%rowtype; v_req public.cancellation_requests;
begin
 if auth.uid() is null or p_reason is null or length(trim(p_reason))=0 then raise exception 'سبب الإلغاء إلزامي'; end if;
 select id into v_lawyer from public.profiles where auth_id=auth.uid() and role::text='lawyer' limit 1; if v_lawyer is null then raise exception 'غير مصرح بهذا الإجراء'; end if;
 select * into v_booking from public.bookings where id=p_booking_id for update; if not found then raise exception 'الحجز غير موجود'; end if;
 if v_booking.lawyer_id<>v_lawyer then raise exception 'لا يمكنك طلب إلغاء حجز لا يخصك'; end if;
 if v_booking.status in ('ملغي','مسترد','مكتمل','قيد التنفيذ') or v_booking.scheduled_at<=now() then raise exception 'لا يمكن طلب إلغاء هذا الحجز في حالته الحالية'; end if;
 if exists(select 1 from public.cancellation_requests where booking_id=p_booking_id and status='بانتظار مراجعة الإدارة') then raise exception 'يوجد بالفعل طلب إلغاء قيد المراجعة لهذا الحجز'; end if;
 insert into public.cancellation_requests(booking_id,lawyer_id,client_id,reason) values(p_booking_id,v_lawyer,v_booking.user_id,trim(p_reason)) returning * into v_req;
 perform public.enqueue_user_notification(v_lawyer,'تم إرسال طلب إلغاء الحجز','تم إرسال طلب إلغاء الحجز إلى الإدارة للمراجعة.','cancellation_request_submitted',v_req.id,'cancellation_request');
 perform public.enqueue_user_notification(v_booking.user_id,'طلب إلغاء قيد المراجعة','قدّم المحامي طلباً لإلغاء حجزك، والطلب الآن بانتظار مراجعة الإدارة.','cancellation_request_submitted',v_req.id,'cancellation_request');
 return v_req;
end; $$;
revoke execute on function public.request_booking_cancellation(uuid,text) from public,anon; grant execute on function public.request_booking_cancellation(uuid,text) to authenticated;

create or replace function public.get_my_cancellation_requests() returns setof public.cancellation_requests language sql security definer set search_path=public as $$ select cr.* from public.cancellation_requests cr join public.profiles p on p.id=cr.lawyer_id where p.auth_id=auth.uid() order by requested_at desc $$;
revoke execute on function public.get_my_cancellation_requests() from public,anon; grant execute on function public.get_my_cancellation_requests() to authenticated;

create or replace function public.get_admin_cancellation_requests() returns table(id uuid,booking_id uuid,lawyer_id uuid,client_id uuid,lawyer_name text,client_name text,consultation_type text,consultation_mode text,description text,scheduled_at timestamptz,price numeric,reason text,requested_at timestamptz,status text,reviewed_at timestamptz,reviewed_by uuid,decision text,penalty_rate numeric,penalty_amount numeric,currency text) language plpgsql security definer set search_path=public as $$ begin if not public.is_admin() then raise exception 'غير مصرح: هذه العملية للإدارة فقط'; end if; return query select cr.id,cr.booking_id,cr.lawyer_id,cr.client_id,coalesce(lp.full_name,p.full_name,'المحامي'),coalesce(cp.full_name,'طالب الاستشارة'),b.consultation_type,b.consultation_mode,b.description,b.scheduled_at,b.price,cr.reason,cr.requested_at,cr.status,cr.reviewed_at,cr.reviewed_by,cr.decision,cr.penalty_rate,cr.penalty_amount,cr.currency from public.cancellation_requests cr join public.bookings b on b.id=cr.booking_id left join public.lawyer_profiles lp on lp.profile_id=cr.lawyer_id left join public.profiles p on p.id=cr.lawyer_id left join public.profiles cp on cp.id=cr.client_id order by case when cr.status='بانتظار مراجعة الإدارة' then 0 else 1 end,cr.requested_at desc; end; $$;
revoke execute on function public.get_admin_cancellation_requests() from public,anon; grant execute on function public.get_admin_cancellation_requests() to authenticated;

create or replace function public.review_booking_cancellation(p_request_id uuid,p_decision text,p_penalty_rate numeric default null) returns public.cancellation_requests language plpgsql security definer set search_path=public as $$
declare v_admin uuid; v_req public.cancellation_requests; v_booking public.bookings%rowtype; v_old text; v_amount numeric(18,2); v_penalty uuid;
begin
 if auth.uid() is null or not public.is_admin() then raise exception 'غير مصرح: هذه العملية للإدارة فقط'; end if; select id into v_admin from public.profiles where auth_id=auth.uid() limit 1;
 select * into v_req from public.cancellation_requests where id=p_request_id for update; if not found or v_req.status<>'بانتظار مراجعة الإدارة' then raise exception 'تمت معالجة طلب الإلغاء مسبقاً'; end if;
 select * into v_booking from public.bookings where id=v_req.booking_id for update; if not found then raise exception 'الحجز غير موجود'; end if; if v_booking.status in ('ملغي','مسترد','مكتمل','قيد التنفيذ') then raise exception 'الحجز لم يعد مؤهلاً لاتخاذ قرار إلغاء'; end if; v_old:=v_booking.status;
 if p_decision='رفض الإلغاء' then update public.cancellation_requests set status='تم رفض الطلب',reviewed_at=now(),reviewed_by=v_admin,decision=p_decision where id=v_req.id returning * into v_req;
 elsif p_decision='الموافقة بدون غرامة' then update public.bookings set status='ملغي',cancelled_at=now() where id=v_booking.id; update public.cancellation_requests set status='تمت الموافقة',reviewed_at=now(),reviewed_by=v_admin,decision=p_decision,penalty_rate=0,penalty_amount=0 where id=v_req.id returning * into v_req;
 elsif p_decision='الموافقة مع غرامة' then if p_penalty_rate is null or p_penalty_rate<=0 or p_penalty_rate>100 then raise exception 'نسبة الغرامة يجب أن تكون أكبر من صفر ولا تتجاوز 100%%'; end if; v_amount:=round(coalesce(v_booking.price,0)::numeric*p_penalty_rate/100,2); if v_amount<=0 then raise exception 'قيمة الغرامة المحسوبة غير صالحة'; end if; update public.bookings set status='ملغي',cancelled_at=now() where id=v_booking.id; update public.cancellation_requests set status='بانتظار تحصيل الغرامة',reviewed_at=now(),reviewed_by=v_admin,decision=p_decision,penalty_rate=p_penalty_rate,penalty_amount=v_amount where id=v_req.id returning * into v_req; insert into public.lawyer_penalties(cancellation_request_id,booking_id,lawyer_id,client_id,amount,remaining_amount,currency) values(v_req.id,v_req.booking_id,v_req.lawyer_id,v_req.client_id,v_amount,v_amount,v_req.currency) returning id into v_penalty; insert into public.client_credits(user_id,booking_id,lawyer_id,amount,currency,transaction_type,status,reference_id) values(v_req.client_id,v_req.booking_id,v_req.lawyer_id,v_amount,v_req.currency,'تعويض إلغاء حجز من المحامي','بانتظار تحصيل الغرامة',v_penalty);
 else raise exception 'نوع القرار غير صالح'; end if;
 insert into public.financial_audit_log(actor_id,actor_role,booking_id,lawyer_id,client_id,event_type,decision,penalty_rate,amount,currency,previous_status,new_status,reference_id) values(v_admin,'admin',v_req.booking_id,v_req.lawyer_id,v_req.client_id,'قرار إلغاء حجز',p_decision,coalesce(p_penalty_rate,0),coalesce(v_req.penalty_amount,0),v_req.currency,v_old,case when p_decision='رفض الإلغاء' then v_old else 'ملغي' end,v_req.id);
 perform public.enqueue_user_notification(v_req.lawyer_id,case when p_decision='رفض الإلغاء' then 'تم رفض طلب إلغاء الحجز' when p_decision='الموافقة مع غرامة' then 'تم اعتماد إلغاء الحجز مع غرامة' else 'تمت الموافقة على إلغاء الحجز' end,case when p_decision='رفض الإلغاء' then 'تم رفض طلب إلغاء الحجز من الإدارة، ويبقى الحجز على حالته الحالية.' when p_decision='الموافقة مع غرامة' then 'تم تسجيل غرامة مالية ستُحصّل من أول استشارة مدفوعة مستقبلاً.' else 'وافقت الإدارة على طلب إلغاء الحجز بدون غرامة.' end,'cancellation_decision',v_req.id,'cancellation_request');
 if p_decision<>'رفض الإلغاء' then perform public.enqueue_user_notification(v_req.client_id,'تم اعتماد إلغاء الحجز','تم اعتماد إلغاء الحجز من الإدارة.'||case when p_decision='الموافقة مع غرامة' then ' تم إنشاء تعويض لصالحك وسيصبح مستحقاً بعد تحصيل الغرامة.' else '' end,'booking_cancelled_by_lawyer',v_req.id,'cancellation_request'); end if;
 return v_req;
exception when unique_violation then raise exception 'تم تنفيذ هذا القرار مسبقاً أو تم إنشاء الغرامة/التعويض لهذا الحجز بالفعل'; end; $$;
revoke execute on function public.review_booking_cancellation(uuid,text,numeric) from public,anon; grant execute on function public.review_booking_cancellation(uuid,text,numeric) to authenticated;

create or replace function public.settle_oldest_lawyer_penalties_for_payment(p_payment_id uuid) returns numeric language plpgsql security definer set search_path=public as $$
declare v_payment public.payments%rowtype; v_booking public.bookings%rowtype; v_penalty public.lawyer_penalties%rowtype; v_remaining numeric(18,2); v_take numeric(18,2); v_total numeric(18,2):=0; v_settlement uuid;
begin select * into v_payment from public.payments where id=p_payment_id for update; if not found or v_payment.status<>'تم الدفع' then return 0; end if; select * into v_booking from public.bookings where id=v_payment.booking_id for update; if not found or v_booking.scheduled_at<now() then return 0; end if; v_remaining:=greatest(0,coalesce(v_payment.amount,0)); while v_remaining>0 loop select * into v_penalty from public.lawyer_penalties where lawyer_id=v_booking.lawyer_id and remaining_amount>0 order by created_at asc limit 1 for update; exit when not found; v_take:=least(v_remaining,v_penalty.remaining_amount); insert into public.lawyer_penalty_settlements(penalty_id,payment_id,lawyer_id,client_id,booking_id,amount,currency) values(v_penalty.id,v_payment.id,v_penalty.lawyer_id,v_penalty.client_id,v_penalty.booking_id,v_take,v_penalty.currency) on conflict do nothing returning id into v_settlement; if v_settlement is null then exit; end if; update public.lawyer_penalties set remaining_amount=remaining_amount-v_take,status=case when remaining_amount-v_take<=0 then 'تم التحصيل' else 'تسوية جزئية' end,settled_at=case when remaining_amount-v_take<=0 then now() else settled_at end where id=v_penalty.id; update public.client_credits set status=case when amount<=(select coalesce(sum(s.amount),0) from public.lawyer_penalty_settlements s where s.penalty_id=v_penalty.id) then 'مستحق' else status end,settled_at=case when amount<=(select coalesce(sum(s.amount),0) from public.lawyer_penalty_settlements s where s.penalty_id=v_penalty.id) then now() else settled_at end,reference_id=v_settlement where booking_id=v_penalty.booking_id; v_remaining:=v_remaining-v_take; v_total:=v_total+v_take; end loop; return v_total; end; $$;
revoke execute on function public.settle_oldest_lawyer_penalties_for_payment(uuid) from public,anon,authenticated;
create or replace function public.settle_penalties_after_payment() returns trigger language plpgsql security definer set search_path=public as $$ begin if NEW.status='تم الدفع' and (TG_OP='INSERT' or OLD.status is distinct from NEW.status) then perform public.settle_oldest_lawyer_penalties_for_payment(NEW.id); end if; return NEW; end; $$;
revoke execute on function public.settle_penalties_after_payment() from public,anon,authenticated;
drop trigger if exists settle_penalties_after_payment on public.payments;
create trigger settle_penalties_after_payment after insert or update of status on public.payments for each row execute function public.settle_penalties_after_payment();

-- يمنع المحامي من الإلغاء النهائي المباشر عبر change_booking_status؛ الإلغاء الإداري يمر عبر review_booking_cancellation.
create or replace function public.change_booking_status(p_booking_id uuid,p_new_status text) returns public.bookings language plpgsql security definer set search_path=public as $$ declare v_actor uuid:=auth.uid(); v_profile uuid; v_booking public.bookings; v_paid boolean; v_duration integer; begin if v_actor is null then raise exception 'يجب تسجيل الدخول أولاً'; end if; if p_new_status not in ('مؤكد','قيد التنفيذ','مكتمل','ملغي','مسترد') then raise exception 'حالة الحجز غير صالحة'; end if; select id into v_profile from public.profiles where auth_id=v_actor limit 1; select * into v_booking from public.bookings where id=p_booking_id for update; if not found then raise exception 'الحجز غير موجود'; end if; select exists(select 1 from public.payments where booking_id=v_booking.id and status='تم الدفع') into v_paid; if public.is_admin() then null; elsif v_booking.user_id=v_profile and p_new_status='ملغي' and v_booking.status in ('قيد انتظار الدفع','قيد معالجة الدفع','مؤكد') then null; elsif v_booking.lawyer_id=v_profile and p_new_status='قيد التنفيذ' then if v_booking.status<>'مؤكد' or not v_paid or not v_booking.lawyer_approved or v_booking.consultation_status<>'لم تبدأ' then raise exception 'لا يمكن بدء الاستشارة قبل تأكيد الدفع والحجز وموافقة المحامي'; end if; v_duration:=coalesce(v_booking.package_duration_minutes,30); if now()<v_booking.scheduled_at-interval '5 minutes' or now()>v_booking.scheduled_at+make_interval(mins=>v_duration) then raise exception 'لا يمكن بدء الاستشارة خارج وقتها المحدد'; end if; elsif v_booking.lawyer_id=v_profile and p_new_status='مكتمل' then if v_booking.status<>'قيد التنفيذ' or v_booking.consultation_status<>'قيد التنفيذ' or v_booking.started_at is null then raise exception 'لا يمكن إنهاء الاستشارة في حالتها الحالية'; end if; else raise exception 'غير مصرح بهذا الإجراء'; end if; update public.bookings set status=p_new_status,consultation_status=case when p_new_status='قيد التنفيذ' then 'قيد التنفيذ' when p_new_status='مكتمل' then 'انتهت' else consultation_status end,started_at=case when p_new_status='قيد التنفيذ' then coalesce(started_at,now()) else started_at end,completed_at=case when p_new_status='مكتمل' then now() else completed_at end,cancelled_at=case when p_new_status='ملغي' then now() else cancelled_at end where id=p_booking_id returning * into v_booking; return v_booking; end; $$;
revoke execute on function public.change_booking_status(uuid,text) from public,anon; grant execute on function public.change_booking_status(uuid,text) to authenticated;
revoke update,delete on public.financial_audit_log from anon,authenticated;
