-- Wallet-first manual payments and bounded custom appointment negotiation.
-- Existing booking-linked payments remain valid for already-created bookings.

create table if not exists public.client_wallets (
  user_id uuid primary key references public.profiles(id) on delete restrict,
  available_balance numeric(18,2) not null default 0 check (available_balance >= 0),
  held_balance numeric(18,2) not null default 0 check (held_balance >= 0),
  currency text not null default 'IQD' check (currency = 'IQD'),
  updated_at timestamptz not null default now()
);

create table if not exists public.client_wallet_topups (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete restrict,
  amount numeric(18,2) not null check (amount > 0),
  currency text not null default 'IQD' check (currency = 'IQD'),
  transaction_number text not null check (length(trim(transaction_number)) between 3 and 120),
  receipt_url text not null check (length(trim(receipt_url)) > 0),
  status text not null default 'قيد المراجعة'
    check (status in ('قيد المراجعة','معتمد','مرفوض')),
  review_deadline_at timestamptz not null default (now() + interval '30 minutes'),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id) on delete set null,
  admin_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists client_wallet_topups_active_transaction_uidx
on public.client_wallet_topups(lower(trim(transaction_number)))
where status in ('قيد المراجعة','معتمد');
create index if not exists client_wallet_topups_review_queue_idx
on public.client_wallet_topups(status, review_deadline_at, created_at);
create index if not exists client_wallet_topups_user_created_idx
on public.client_wallet_topups(user_id, created_at desc);

create table if not exists public.client_wallet_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete restrict,
  amount numeric(18,2) not null,
  entry_type text not null check (entry_type in (
    'topup','booking_payment','appointment_hold','appointment_release','appointment_capture','admin_adjustment'
  )),
  topup_id uuid references public.client_wallet_topups(id) on delete restrict,
  booking_id uuid references public.bookings(id) on delete restrict,
  appointment_request_id uuid,
  balance_after numeric(18,2) not null check (balance_after >= 0),
  idempotency_key text not null unique,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists client_wallet_ledger_user_created_idx
on public.client_wallet_ledger(user_id, created_at desc);

create table if not exists public.custom_appointment_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete restrict,
  lawyer_id uuid not null references public.profiles(id) on delete restrict,
  package_name text not null,
  package_description text,
  consultation_type text not null check (consultation_type in ('نصية','صوتية','فيديو')),
  consultation_mode text not null check (consultation_mode in ('عن بعد','في المكتب')),
  description text,
  document_url text,
  price numeric(18,2) not null check (price >= 0),
  duration_minutes integer not null check (duration_minutes between 15 and 180),
  payment_required boolean not null default true,
  reserved_amount numeric(18,2) not null default 0 check (reserved_amount >= 0),
  client_windows jsonb not null,
  lawyer_options jsonb,
  selected_option integer,
  status text not null default 'بانتظار رد المحامي' check (status in (
    'بانتظار رد المحامي','بانتظار اختيار العميل','مؤكد','مرفوض','منتهي','ملغي'
  )),
  rejection_reason text,
  booking_id uuid references public.bookings(id) on delete restrict,
  expires_at timestamptz not null default (now() + interval '12 hours'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.client_wallet_ledger
  drop constraint if exists client_wallet_ledger_appointment_request_id_fkey;
alter table public.client_wallet_ledger
  add constraint client_wallet_ledger_appointment_request_id_fkey
  foreign key (appointment_request_id) references public.custom_appointment_requests(id) on delete restrict;

create index if not exists custom_appointment_requests_user_idx
on public.custom_appointment_requests(user_id, created_at desc);
create index if not exists custom_appointment_requests_lawyer_status_idx
on public.custom_appointment_requests(lawyer_id, status, expires_at);
create unique index if not exists custom_appointment_requests_booking_uidx
on public.custom_appointment_requests(booking_id) where booking_id is not null;

alter table public.client_wallets enable row level security;
alter table public.client_wallet_topups enable row level security;
alter table public.client_wallet_ledger enable row level security;
alter table public.custom_appointment_requests enable row level security;

revoke all on public.client_wallets, public.client_wallet_topups,
  public.client_wallet_ledger, public.custom_appointment_requests
from public, anon, authenticated;
grant select on public.client_wallets, public.client_wallet_topups,
  public.client_wallet_ledger, public.custom_appointment_requests
to authenticated;

drop policy if exists client_wallets_select_participant on public.client_wallets;
create policy client_wallets_select_participant on public.client_wallets
for select to authenticated using (
  user_id = (select p.id from public.profiles p where p.auth_id=(select auth.uid()) limit 1)
  or (select public.is_admin())
);

drop policy if exists client_wallet_topups_select_participant on public.client_wallet_topups;
create policy client_wallet_topups_select_participant on public.client_wallet_topups
for select to authenticated using (
  user_id = (select p.id from public.profiles p where p.auth_id=(select auth.uid()) limit 1)
  or (select public.is_admin())
);

drop policy if exists client_wallet_ledger_select_participant on public.client_wallet_ledger;
create policy client_wallet_ledger_select_participant on public.client_wallet_ledger
for select to authenticated using (
  user_id = (select p.id from public.profiles p where p.auth_id=(select auth.uid()) limit 1)
  or (select public.is_admin())
);

drop policy if exists custom_appointment_requests_select_participant on public.custom_appointment_requests;
create policy custom_appointment_requests_select_participant on public.custom_appointment_requests
for select to authenticated using (
  user_id = (select p.id from public.profiles p where p.auth_id=(select auth.uid()) limit 1)
  or lawyer_id = (select p.id from public.profiles p where p.auth_id=(select auth.uid()) limit 1)
  or (select public.is_admin())
);

create or replace function public.get_my_client_wallet()
returns table(available_balance numeric, held_balance numeric, currency text)
language plpgsql
security definer
set search_path=public
as $$
declare v_user_id uuid;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  select id into v_user_id from public.profiles
  where auth_id=auth.uid() and role='user' and status='active' limit 1;
  if v_user_id is null then raise exception 'محفظة العميل متاحة لطالب الاستشارة فقط'; end if;
  insert into public.client_wallets(user_id) values(v_user_id) on conflict(user_id) do nothing;
  return query select w.available_balance,w.held_balance,w.currency
  from public.client_wallets w where w.user_id=v_user_id;
end;
$$;

create or replace function public.submit_client_wallet_topup(
  p_amount numeric,
  p_transaction_number text,
  p_receipt_url text
) returns public.client_wallet_topups
language plpgsql
security definer
set search_path=public
as $$
declare
  v_user_id uuid;
  v_settings public.manual_payment_settings%rowtype;
  v_topup public.client_wallet_topups;
  v_admin record;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  select id into v_user_id from public.profiles
  where auth_id=auth.uid() and role='user' and status='active' limit 1;
  if v_user_id is null then raise exception 'شحن المحفظة متاح لطالب الاستشارة فقط'; end if;
  if p_amount is null or p_amount < 1000 then raise exception 'أدخل مبلغ شحن صحيحاً'; end if;
  if nullif(trim(coalesce(p_transaction_number,'')),'') is null then raise exception 'رقم عملية التحويل مطلوب'; end if;
  if nullif(trim(coalesce(p_receipt_url,'')),'') is null then raise exception 'إيصال التحويل مطلوب'; end if;

  select * into v_settings from public.manual_payment_settings where id=true;
  if not coalesce(v_settings.enabled,false) then raise exception 'الدفع اليدوي غير متاح حالياً'; end if;

  insert into public.client_wallet_topups(user_id,amount,transaction_number,receipt_url)
  values(v_user_id,round(p_amount,2),trim(p_transaction_number),trim(p_receipt_url))
  returning * into v_topup;

  for v_admin in select id from public.profiles where role='admin' and status='active' loop
    perform public.enqueue_user_notification(
      v_admin.id,'شحن محفظة يحتاج مراجعة',
      'تم رفع إيصال شحن بقيمة '||to_char(v_topup.amount,'FM999G999G999G990')||' د.ع. مهلة المراجعة 30 دقيقة.',
      'wallet_topup_review',v_topup.id,'wallet_topup'
    );
  end loop;
  return v_topup;
exception when unique_violation then
  raise exception 'رقم التحويل مستخدم في طلب شحن آخر';
end;
$$;

create or replace function public.get_pending_client_wallet_topups()
returns table(
  id uuid,user_id uuid,client_name text,amount numeric,currency text,
  transaction_number text,receipt_url text,status text,review_deadline_at timestamptz,
  is_overdue boolean,created_at timestamptz
)
language plpgsql
security definer
set search_path=public
as $$
begin
  if auth.uid() is null or not public.is_admin() then raise exception 'غير مصرح: هذه العملية للإدارة فقط'; end if;
  return query
  select t.id,t.user_id,coalesce(nullif(trim(p.full_name),''),'طالب استشارة'),
         t.amount,t.currency,t.transaction_number,t.receipt_url,t.status,
         t.review_deadline_at,(now()>t.review_deadline_at),t.created_at
  from public.client_wallet_topups t
  join public.profiles p on p.id=t.user_id
  where t.status='قيد المراجعة'
  order by (now()>t.review_deadline_at) desc,t.review_deadline_at,t.created_at;
end;
$$;

create or replace function public.admin_review_client_wallet_topup(
  p_topup_id uuid,
  p_approved boolean,
  p_note text default null
) returns public.client_wallet_topups
language plpgsql
security definer
set search_path=public
as $$
declare
  v_admin_id uuid;
  v_topup public.client_wallet_topups;
  v_balance numeric;
begin
  if auth.uid() is null or not public.is_admin() then raise exception 'غير مصرح: هذه العملية للإدارة فقط'; end if;
  select id into v_admin_id from public.profiles where auth_id=auth.uid() limit 1;
  select * into v_topup from public.client_wallet_topups where id=p_topup_id for update;
  if not found then raise exception 'طلب الشحن غير موجود'; end if;
  if v_topup.status<>'قيد المراجعة' then raise exception 'تمت مراجعة طلب الشحن مسبقاً'; end if;

  if coalesce(p_approved,false) then
    insert into public.client_wallets(user_id,available_balance,updated_at)
    values(v_topup.user_id,v_topup.amount,now())
    on conflict(user_id) do update set
      available_balance=public.client_wallets.available_balance+excluded.available_balance,
      updated_at=now()
    returning available_balance into v_balance;

    insert into public.client_wallet_ledger(
      user_id,amount,entry_type,topup_id,balance_after,idempotency_key,metadata
    ) values(
      v_topup.user_id,v_topup.amount,'topup',v_topup.id,v_balance,
      'topup:'||v_topup.id,jsonb_build_object('transaction_number',v_topup.transaction_number)
    );
  end if;

  update public.client_wallet_topups
  set status=case when coalesce(p_approved,false) then 'معتمد' else 'مرفوض' end,
      reviewed_at=now(),reviewed_by=v_admin_id,
      admin_note=nullif(trim(coalesce(p_note,'')),''),updated_at=now()
  where id=v_topup.id returning * into v_topup;

  perform public.enqueue_user_notification(
    v_topup.user_id,
    case when p_approved then 'تم اعتماد شحن المحفظة' else 'تم رفض إيصال الشحن' end,
    case when p_approved
      then 'أضيف '||to_char(v_topup.amount,'FM999G999G999G990')||' د.ع إلى محفظتك ويمكنك حجز الموعد الآن.'
      else 'لم يتم اعتماد إيصال الشحن. راجع ملاحظة الإدارة وأعد المحاولة.' end,
    case when p_approved then 'wallet_topup_approved' else 'wallet_topup_rejected' end,
    v_topup.id,'wallet_topup'
  );
  return v_topup;
end;
$$;

-- Wallet is a distinct, auditable payment method after an approved top-up.
alter table public.payments drop constraint if exists payments_payment_method_check;
alter table public.payments add constraint payments_payment_method_check check (
  payment_method in (
    'زين كاش','آسيا حوالة','كي كارد','بطاقة مصرفية','zaincash','fatoora','cash',
    'bank_transfer','wallet','يدوي','ZainCash','Asia Hawala','Qi Card','MasterCard'
  )
);

create or replace function public.create_wallet_funded_booking(
  p_lawyer_id uuid,
  p_scheduled_at timestamptz,
  p_package_name text,
  p_consultation_type text,
  p_description text default null,
  p_document_url text default null,
  p_client_whatsapp text default null,
  p_slot_id uuid default null,
  p_consultation_mode text default 'عن بعد'
) returns public.bookings
language plpgsql
security definer
set search_path=public
as $$
declare
  v_booking public.bookings;
  v_wallet public.client_wallets%rowtype;
  v_balance numeric;
begin
  v_booking := public.create_booking(
    p_lawyer_id,p_scheduled_at,p_package_name,p_consultation_type,
    p_description,p_document_url,p_client_whatsapp,p_slot_id,p_consultation_mode
  );

  update public.bookings set lawyer_approved=true,lawyer_approved_at=now()
  where id=v_booking.id;

  if v_booking.payment_required then
    select * into v_wallet from public.client_wallets
    where user_id=v_booking.user_id for update;
    if not found or v_wallet.available_balance < v_booking.price then
      raise exception 'رصيد المحفظة غير كافٍ. اشحن المحفظة وانتظر اعتماد الإدارة ثم أعد الحجز';
    end if;

    update public.client_wallets
    set available_balance=available_balance-v_booking.price,updated_at=now()
    where user_id=v_booking.user_id returning available_balance into v_balance;

    update public.bookings set status='قيد معالجة الدفع' where id=v_booking.id;
    insert into public.client_wallet_ledger(
      user_id,amount,entry_type,booking_id,balance_after,idempotency_key
    ) values(
      v_booking.user_id,-v_booking.price,'booking_payment',v_booking.id,v_balance,
      'booking:'||v_booking.id||':wallet'
    );
    insert into public.payments(
      booking_id,amount,payment_method,transaction_number,status,verified_at,is_manual
    ) values(
      v_booking.id,v_booking.price,'wallet','wallet-'||v_booking.id,'تم الدفع',now(),false
    );
  else
    update public.bookings set status='مؤكد' where id=v_booking.id;
  end if;

  select * into v_booking from public.bookings where id=v_booking.id;
  return v_booking;
end;
$$;

create or replace function public.expire_stale_custom_appointment_requests()
returns integer
language plpgsql
security definer
set search_path=public
as $$
declare r record; v_count integer:=0; v_balance numeric;
begin
  for r in
    select * from public.custom_appointment_requests
    where status in ('بانتظار رد المحامي','بانتظار اختيار العميل') and expires_at<=now()
    for update skip locked
  loop
    if r.reserved_amount>0 then
      update public.client_wallets
      set available_balance=available_balance+r.reserved_amount,
          held_balance=greatest(0,held_balance-r.reserved_amount),updated_at=now()
      where user_id=r.user_id returning available_balance into v_balance;
      insert into public.client_wallet_ledger(
        user_id,amount,entry_type,appointment_request_id,balance_after,idempotency_key
      ) values(
        r.user_id,r.reserved_amount,'appointment_release',r.id,v_balance,
        'appointment:'||r.id||':expiry-release'
      ) on conflict(idempotency_key) do nothing;
    end if;
    update public.custom_appointment_requests
    set status='منتهي',updated_at=now() where id=r.id;
    perform public.enqueue_user_notification(
      r.user_id,'انتهى طلب الموعد الخاص',
      'لم يكتمل الاتفاق خلال المهلة، وأُعيد المبلغ المحجوز إلى رصيدك.',
      'appointment_request_expired',r.id,'appointment_request'
    );
    v_count:=v_count+1;
  end loop;
  return v_count;
end;
$$;

create or replace function public.submit_custom_appointment_request(
  p_lawyer_id uuid,
  p_package_name text,
  p_consultation_type text,
  p_consultation_mode text,
  p_description text,
  p_document_url text,
  p_client_windows jsonb
) returns public.custom_appointment_requests
language plpgsql
security definer
set search_path=public
as $$
declare
  v_user_id uuid; v_whatsapp text; v_lawyer_name text; v_lawyer_whatsapp text;
  v_package jsonb; v_price numeric; v_duration integer:=30; v_package_description text;
  v_type text:=case when trim(coalesce(p_consultation_type,''))='مرئية' then 'فيديو' else trim(coalesce(p_consultation_type,'')) end;
  v_mode text:=trim(coalesce(p_consultation_mode,'عن بعد'));
  v_free_beta boolean; v_payments_enabled boolean; v_manual_enabled boolean;
  v_payment_required boolean; v_wallet public.client_wallets%rowtype; v_balance numeric;
  v_item jsonb; v_start timestamptz; v_end timestamptz; v_request public.custom_appointment_requests;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  perform public.expire_stale_custom_appointment_requests();
  select id,nullif(trim(whatsapp_number),'') into v_user_id,v_whatsapp from public.profiles
  where auth_id=auth.uid() and role='user' and status='active' limit 1;
  if v_user_id is null then raise exception 'طلب الموعد متاح لطالب الاستشارة فقط'; end if;
  if v_whatsapp is null then raise exception 'أضف رقم واتساب في الملف الشخصي أولاً'; end if;

  select coalesce(nullif(trim(p.full_name),''),'المحامي'),
         coalesce(nullif(trim(lp.whatsapp),''),nullif(trim(p.whatsapp_number),'')),
         lp.consultation_price
  into v_lawyer_name,v_lawyer_whatsapp,v_price
  from public.profiles p join public.lawyer_profiles lp on lp.profile_id=p.id
  where p.id=p_lawyer_id and p.role='lawyer' and p.status='active'
    and lp.verified=true and lp.availability=true;
  if not found then raise exception 'المحامي غير متاح لاستقبال الطلبات'; end if;
  if v_mode not in ('عن بعد','في المكتب') then raise exception 'طريقة التنفيذ غير صالحة'; end if;
  if v_mode='عن بعد' and v_lawyer_whatsapp is null then raise exception 'المحامي لم يضف رقم التواصل بعد'; end if;
  if v_type not in ('نصية','صوتية','فيديو') then raise exception 'نوع الاستشارة غير صالح'; end if;

  if lower(trim(coalesce(p_package_name,'')))<>lower('استشارة مختلفة') then
    select elem into v_package
    from public.lawyer_profiles lp,
      lateral jsonb_array_elements(coalesce(lp.services,'[]'::jsonb)) elem
    where lp.profile_id=p_lawyer_id
      and lower(coalesce(elem->>'title',''))=lower(trim(p_package_name)) limit 1;
    if v_package is null then raise exception 'الخدمة المحددة غير متاحة'; end if;
    v_price:=nullif(v_package->>'price','')::numeric;
    v_duration:=coalesce(nullif(v_package->>'duration_minutes','')::integer,30);
    v_package_description:=v_package->>'description';
  end if;
  if v_price is null or v_price<=0 then raise exception 'سعر الاستشارة غير محدد'; end if;

  if jsonb_typeof(p_client_windows)<>'array'
     or jsonb_array_length(p_client_windows)<1
     or jsonb_array_length(p_client_windows)>3 then
    raise exception 'حدد من فترة واحدة إلى ثلاث فترات مناسبة';
  end if;
  for v_item in select value from jsonb_array_elements(p_client_windows) loop
    begin
      v_start:=(v_item->>'start')::timestamptz;
      v_end:=(v_item->>'end')::timestamptz;
    exception when others then raise exception 'إحدى الفترات المقترحة غير صالحة'; end;
    if v_start<=now()+interval '30 minutes' or v_end<=v_start or v_end-v_start>interval '12 hours' then
      raise exception 'يجب أن تكون الفترات مستقبلية وواضحة ولا تتجاوز 12 ساعة';
    end if;
  end loop;

  select free_beta_enabled,payments_enabled into v_free_beta,v_payments_enabled
  from public.app_release_settings where id=true;
  select enabled into v_manual_enabled from public.manual_payment_settings where id=true;
  v_payment_required:=not coalesce(v_free_beta,false);
  if v_payment_required and not (coalesce(v_payments_enabled,false) and coalesce(v_manual_enabled,false)) then
    raise exception 'الحجوزات المدفوعة متوقفة مؤقتاً';
  end if;

  if v_payment_required then
    select * into v_wallet from public.client_wallets where user_id=v_user_id for update;
    if not found or v_wallet.available_balance<v_price then
      raise exception 'رصيد المحفظة غير كافٍ لإرسال طلب الموعد';
    end if;
    update public.client_wallets
    set available_balance=available_balance-v_price,held_balance=held_balance+v_price,updated_at=now()
    where user_id=v_user_id returning available_balance into v_balance;
  end if;

  insert into public.custom_appointment_requests(
    user_id,lawyer_id,package_name,package_description,consultation_type,consultation_mode,
    description,document_url,price,duration_minutes,payment_required,reserved_amount,client_windows
  ) values(
    v_user_id,p_lawyer_id,coalesce(nullif(trim(p_package_name),''),'استشارة مختلفة'),
    v_package_description,v_type,v_mode,nullif(trim(coalesce(p_description,'')),''),p_document_url,
    case when v_payment_required then v_price else 0 end,v_duration,v_payment_required,
    case when v_payment_required then v_price else 0 end,p_client_windows
  ) returning * into v_request;

  if v_payment_required then
    insert into public.client_wallet_ledger(
      user_id,amount,entry_type,appointment_request_id,balance_after,idempotency_key
    ) values(
      v_user_id,-v_price,'appointment_hold',v_request.id,v_balance,
      'appointment:'||v_request.id||':hold'
    );
  end if;
  perform public.enqueue_user_notification(
    p_lawyer_id,'طلب موعد خاص جديد',
    'اقترح طالب استشارة ثلاث فترات كحد أقصى. اختر موعداً أو اقترح بدائل خلال 12 ساعة.',
    'appointment_request_new',v_request.id,'appointment_request'
  );
  return v_request;
end;
$$;

create or replace function public.lawyer_respond_custom_appointment_request(
  p_request_id uuid,
  p_options jsonb default null,
  p_reject_reason text default null
) returns public.custom_appointment_requests
language plpgsql
security definer
set search_path=public
as $$
declare
  v_lawyer_id uuid; v_request public.custom_appointment_requests;
  v_item jsonb; v_start timestamptz; v_balance numeric;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  perform public.expire_stale_custom_appointment_requests();
  select id into v_lawyer_id from public.profiles
  where auth_id=auth.uid() and role='lawyer' and status='active' limit 1;
  select * into v_request from public.custom_appointment_requests
  where id=p_request_id and lawyer_id=v_lawyer_id for update;
  if not found then raise exception 'طلب الموعد غير موجود'; end if;
  if v_request.status<>'بانتظار رد المحامي' or v_request.expires_at<=now() then
    raise exception 'انتهت مهلة الرد على هذا الطلب';
  end if;

  if nullif(trim(coalesce(p_reject_reason,'')),'') is not null then
    if v_request.reserved_amount>0 then
      update public.client_wallets set
        available_balance=available_balance+v_request.reserved_amount,
        held_balance=greatest(0,held_balance-v_request.reserved_amount),updated_at=now()
      where user_id=v_request.user_id returning available_balance into v_balance;
      insert into public.client_wallet_ledger(
        user_id,amount,entry_type,appointment_request_id,balance_after,idempotency_key
      ) values(
        v_request.user_id,v_request.reserved_amount,'appointment_release',v_request.id,v_balance,
        'appointment:'||v_request.id||':rejected-release'
      );
    end if;
    update public.custom_appointment_requests set
      status='مرفوض',rejection_reason=trim(p_reject_reason),updated_at=now()
    where id=v_request.id returning * into v_request;
    perform public.enqueue_user_notification(
      v_request.user_id,'تعذر قبول طلب الموعد',
      'رفض المحامي الطلب، وأُعيد المبلغ المحجوز إلى رصيدك.',
      'appointment_request_rejected',v_request.id,'appointment_request'
    );
    return v_request;
  end if;

  if jsonb_typeof(p_options)<>'array' or jsonb_array_length(p_options)<1 or jsonb_array_length(p_options)>3 then
    raise exception 'اقترح من موعد واحد إلى ثلاثة مواعيد';
  end if;
  for v_item in select value from jsonb_array_elements(p_options) loop
    begin v_start:=(v_item->>'start')::timestamptz;
    exception when others then raise exception 'أحد المواعيد المقترحة غير صالح'; end;
    if v_start<=now()+interval '30 minutes' then raise exception 'يجب أن يكون الموعد في المستقبل'; end if;
    if exists(
      select 1 from public.bookings b where b.lawyer_id=v_lawyer_id
      and b.status not in ('ملغي','مسترد','بانتظار الاسترداد','مكتمل')
      and tstzrange(b.scheduled_at,b.scheduled_at+make_interval(mins=>coalesce(b.package_duration_minutes,30)),'[)')
          && tstzrange(v_start,v_start+make_interval(mins=>v_request.duration_minutes),'[)')
    ) then raise exception 'أحد المواعيد المقترحة يتعارض مع حجز قائم'; end if;
  end loop;

  update public.custom_appointment_requests set
    lawyer_options=p_options,status='بانتظار اختيار العميل',expires_at=now()+interval '12 hours',updated_at=now()
  where id=v_request.id returning * into v_request;
  perform public.enqueue_user_notification(
    v_request.user_id,'اقترح المحامي مواعيد مناسبة',
    'اختر أحد المواعيد المقترحة خلال 12 ساعة لتأكيد الحجز.',
    'appointment_options_ready',v_request.id,'appointment_request'
  );
  return v_request;
end;
$$;

create or replace function public.client_confirm_custom_appointment(
  p_request_id uuid,
  p_option_index integer
) returns public.bookings
language plpgsql
security definer
set search_path=public
as $$
declare
  v_user_id uuid; v_whatsapp text; v_request public.custom_appointment_requests;
  v_option jsonb; v_start timestamptz; v_booking public.bookings; v_wallet public.client_wallets%rowtype;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  perform public.expire_stale_custom_appointment_requests();
  select id,nullif(trim(whatsapp_number),'') into v_user_id,v_whatsapp from public.profiles
  where auth_id=auth.uid() and role='user' and status='active' limit 1;
  select * into v_request from public.custom_appointment_requests
  where id=p_request_id and user_id=v_user_id for update;
  if not found then raise exception 'طلب الموعد غير موجود'; end if;
  if v_request.status<>'بانتظار اختيار العميل' or v_request.expires_at<=now() then
    raise exception 'انتهت مهلة اختيار الموعد';
  end if;
  if p_option_index is null or p_option_index<0
     or p_option_index>=jsonb_array_length(v_request.lawyer_options) then
    raise exception 'الموعد المختار غير صالح';
  end if;
  v_option:=v_request.lawyer_options->p_option_index;
  v_start:=(v_option->>'start')::timestamptz;
  if v_start<=now() then raise exception 'الموعد المختار انتهى'; end if;

  if exists(
    select 1 from public.bookings b where b.lawyer_id=v_request.lawyer_id
    and b.status not in ('ملغي','مسترد','بانتظار الاسترداد','مكتمل')
    and tstzrange(b.scheduled_at,b.scheduled_at+make_interval(mins=>coalesce(b.package_duration_minutes,30)),'[)')
        && tstzrange(v_start,v_start+make_interval(mins=>v_request.duration_minutes),'[)')
  ) then raise exception 'الموعد لم يعد متاحاً؛ اطلب من المحامي اقتراح موعد جديد'; end if;

  if v_request.payment_required then
    select * into v_wallet from public.client_wallets where user_id=v_user_id for update;
    if not found or v_wallet.held_balance<v_request.reserved_amount then
      raise exception 'تعذر العثور على المبلغ المحجوز لهذا الطلب';
    end if;
    update public.client_wallets set
      held_balance=held_balance-v_request.reserved_amount,updated_at=now()
    where user_id=v_user_id;
  end if;

  insert into public.bookings(
    user_id,lawyer_id,status,scheduled_at,price,consultation_type,consultation_mode,
    manual_payment_required,payment_required,payment_confirmed_at,
    payment_waived_at,payment_waiver_reason,description,document_url,whatsapp_number,
    package_name,package_description,package_duration_minutes,consultation_status,
    lawyer_approved,lawyer_approved_at
  ) values(
    v_user_id,v_request.lawyer_id,
    case when v_request.payment_required then 'قيد معالجة الدفع' else 'مؤكد' end,
    v_start,v_request.price,v_request.consultation_type,v_request.consultation_mode,
    false,v_request.payment_required,
    case when v_request.payment_required then now() else null end,
    case when v_request.payment_required then null else now() end,
    case when v_request.payment_required then null else 'free_beta' end,
    v_request.description,v_request.document_url,v_whatsapp,v_request.package_name,
    v_request.package_description,v_request.duration_minutes,'لم تبدأ',true,now()
  ) returning * into v_booking;

  if v_request.payment_required then
    insert into public.client_wallet_ledger(
      user_id,amount,entry_type,appointment_request_id,booking_id,balance_after,idempotency_key
    ) values(
      v_user_id,0,'appointment_capture',v_request.id,v_booking.id,v_wallet.available_balance,
      'appointment:'||v_request.id||':capture'
    );
    insert into public.payments(
      booking_id,amount,payment_method,transaction_number,status,verified_at,is_manual
    ) values(
      v_booking.id,v_request.price,'wallet','wallet-'||v_booking.id,'تم الدفع',now(),false
    );
  end if;

  update public.custom_appointment_requests set
    status='مؤكد',selected_option=p_option_index,booking_id=v_booking.id,updated_at=now()
  where id=v_request.id;
  select * into v_booking from public.bookings where id=v_booking.id;
  return v_booking;
end;
$$;

create or replace function public.cancel_custom_appointment_request(p_request_id uuid)
returns public.custom_appointment_requests
language plpgsql
security definer
set search_path=public
as $$
declare v_user_id uuid; v_request public.custom_appointment_requests; v_balance numeric;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  select id into v_user_id from public.profiles where auth_id=auth.uid() and status='active' limit 1;
  select * into v_request from public.custom_appointment_requests
  where id=p_request_id and user_id=v_user_id for update;
  if not found then raise exception 'طلب الموعد غير موجود'; end if;
  if v_request.status not in ('بانتظار رد المحامي','بانتظار اختيار العميل') then
    raise exception 'لا يمكن إلغاء الطلب في حالته الحالية';
  end if;
  if v_request.reserved_amount>0 then
    update public.client_wallets set
      available_balance=available_balance+v_request.reserved_amount,
      held_balance=greatest(0,held_balance-v_request.reserved_amount),updated_at=now()
    where user_id=v_user_id returning available_balance into v_balance;
    insert into public.client_wallet_ledger(
      user_id,amount,entry_type,appointment_request_id,balance_after,idempotency_key
    ) values(
      v_user_id,v_request.reserved_amount,'appointment_release',v_request.id,v_balance,
      'appointment:'||v_request.id||':cancel-release'
    );
  end if;
  update public.custom_appointment_requests set status='ملغي',updated_at=now()
  where id=v_request.id returning * into v_request;
  perform public.enqueue_user_notification(
    v_request.lawyer_id,'أُلغي طلب الموعد الخاص',
    'ألغى طالب الاستشارة طلب الموعد قبل تأكيده.','appointment_request_cancelled',
    v_request.id,'appointment_request'
  );
  return v_request;
end;
$$;

revoke all on function public.get_my_client_wallet() from public,anon;
revoke all on function public.submit_client_wallet_topup(numeric,text,text) from public,anon;
revoke all on function public.get_pending_client_wallet_topups() from public,anon;
revoke all on function public.admin_review_client_wallet_topup(uuid,boolean,text) from public,anon;
revoke all on function public.create_wallet_funded_booking(uuid,timestamptz,text,text,text,text,text,uuid,text) from public,anon;
revoke all on function public.submit_custom_appointment_request(uuid,text,text,text,text,text,jsonb) from public,anon;
revoke all on function public.lawyer_respond_custom_appointment_request(uuid,jsonb,text) from public,anon;
revoke all on function public.client_confirm_custom_appointment(uuid,integer) from public,anon;
revoke all on function public.cancel_custom_appointment_request(uuid) from public,anon;
revoke all on function public.expire_stale_custom_appointment_requests() from public,anon,authenticated;

grant execute on function public.get_my_client_wallet() to authenticated;
grant execute on function public.submit_client_wallet_topup(numeric,text,text) to authenticated;
grant execute on function public.get_pending_client_wallet_topups() to authenticated;
grant execute on function public.admin_review_client_wallet_topup(uuid,boolean,text) to authenticated;
grant execute on function public.create_wallet_funded_booking(uuid,timestamptz,text,text,text,text,text,uuid,text) to authenticated;
grant execute on function public.submit_custom_appointment_request(uuid,text,text,text,text,text,jsonb) to authenticated;
grant execute on function public.lawyer_respond_custom_appointment_request(uuid,jsonb,text) to authenticated;
grant execute on function public.client_confirm_custom_appointment(uuid,integer) to authenticated;
grant execute on function public.cancel_custom_appointment_request(uuid) to authenticated;

do $$
declare v_job_id bigint;
begin
  select jobid into v_job_id from cron.job where jobname='expire-custom-appointment-requests' limit 1;
  if v_job_id is not null then perform cron.unschedule(v_job_id); end if;
  perform cron.schedule(
    'expire-custom-appointment-requests','*/5 * * * *',
    'select public.expire_stale_custom_appointment_requests();'
  );
end;
$$;

do $$
begin
  if not exists(
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='client_wallets'
  ) then alter publication supabase_realtime add table public.client_wallets; end if;
  if not exists(
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='client_wallet_topups'
  ) then alter publication supabase_realtime add table public.client_wallet_topups; end if;
  if not exists(
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='custom_appointment_requests'
  ) then alter publication supabase_realtime add table public.custom_appointment_requests; end if;
end;
$$;

comment on table public.client_wallet_topups is
  'Manual wallet funding receipts. Admin review SLA is tracked independently from appointments.';
comment on table public.custom_appointment_requests is
  'One bounded negotiation round: client windows, lawyer options, then client final selection.';
