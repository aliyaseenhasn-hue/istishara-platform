# تنفيذ السياسة المالية — 2026-09-11

هذا الملف يوثق تنفيذ السياسة المالية الجديدة لمنصة «استشارة» في `main` وSupabase الإنتاجي.

## السياسة النشطة

الإصدار المالي النشط: **2**، ويطبق على العمليات الجديدة فقط:

- عمولة المنصة: **10%**.
- سحب رصيد العميل: مفعّل.
- الحد الأدنى لسحب العميل: **10,000 د.ع**.
- مدة المعالجة: **1–3 أيام عمل**.
- لا توجد عمولة منصة على سحب العميل؛ يسمح فقط برسوم التحويل الفعلية إن وجدت.
- مستحق المحامي يبقى معلقاً **24 ساعة بعد اكتمال الاستشارة**.
- تسوية المحامين الافتراضية: **أسبوعياً يوم الخميس**.
- التحويل المالي الخارجي ما زال يدوياً ويجب تسجيل مرجعه داخل النظام.

## منع الأثر الرجعي

تمت إضافة `platform_financial_policy_versions` وحفظ snapshot للسياسة داخل كل حجز جديد عبر:

- `financial_policy_version`
- `commission_rate_snapshot`
- `lawyer_earnings_hold_hours_snapshot`
- `financial_policy_snapshot`

تم التحقق من تثبيت **24 حجزاً سابقاً** على الإصدار 1، ولا يوجد حجز قديم بلا نسخة سياسة.

طلبات `custom_appointment_requests` تحفظ السياسة منذ إنشاء طلب الموعد المرن، وتنتقل نفس النسخة إلى `booking` عند التأكيد، لذلك تغيير الإدارة للسياسة أثناء انتظار الرد لا يغيّر شروط الطلب القائم.

## سحب رصيد العميل

تم إنشاء `client_wallet_withdrawal_requests` ودورة السحب التالية:

1. السحب من `available_balance` فقط.
2. يشترط حساب استلام افتراضي صالح في `client_payout_accounts`.
3. عند الطلب ينتقل المبلغ إلى `held_balance` وتسجل `withdrawal_hold`.
4. يمكن للعميل إلغاء الطلب قبل بدء المعالجة، فيرجع المبلغ وتسجل `withdrawal_release`.
5. الإدارة تستطيع: بدء المعالجة، الرفض وإعادة الرصيد، أو تسجيل التحويل الفعلي.
6. لا يمكن تسجيل الطلب `paid` بدون `provider_reference`.
7. عند الدفع تسجل رسوم التحويل الفعلية فقط عند سماح سياسة الطلب بها، ويحسب `net_amount` منها.

تم توسيع قيد `client_wallet_ledger.entry_type` لدعم:

- `withdrawal_hold`
- `withdrawal_release`
- `withdrawal_capture`

## مستحقات المحامي

صافي المحامي يذهب أولاً إلى `pending_balance`. بعد اكتمال الاستشارة يحدد `earnings_available_at` وفق snapshot الحجز. في الإصدار 2 تكون المدة 24 ساعة.

Cron باسم `release-matured-lawyer-earnings` يعمل كل 5 دقائق لتحرير المستحقات المستوفية إلى `available_balance`.

تم ربط `lawyer_payout_requests` بإصدار السياسة وإضافة `scheduled_payout_date`. التسوية الافتراضية أسبوعية يوم الخميس، مع بقاء التنفيذ الخارجي يدوياً وتسجيل مرجع التحويل.

## الواجهات المعدلة

- `lib/features/payments/presentation/providers/client_wallet_provider.dart`
- `lib/features/payments/presentation/pages/client_wallet_page.dart`
- `lib/features/admin/presentation/pages/financial_management_page.dart`
- `lib/features/lawyers/presentation/pages/lawyer_wallet_page.dart`
- `lib/core/services/notification_service.dart`
- `lib/features/profile/presentation/pages/notifications_page.dart`
- `supabase/functions/send-pwa-push/index.ts`

لوحة الإدارة المالية أصبحت تدير العمولة، سحب العميل، حدود ومدة السحب، رسوم التحويل، ساعات حجز مستحق المحامي، دورية التسوية، وطلبات السحب، مع إبقاء التعويضات وطلبات سحب المحامين الحالية.

محفظة العميل تعرض طلبات السحب وحالاتها وإلغاء الطلب قبل المعالجة. محفظة المحامي تعرض الرصيد المعلق والمتاح وفترة الحجز ودورية التسوية.

## الإشعارات

`reference_type = client_wallet_withdrawal` يوجه:

- العميل إلى `/client-wallet`.
- الإدارة إلى `/admin/financial`.

تم تطبيق التوجيه في الإشعارات الداخلية وNative/PWA. وتم نشر `send-pwa-push` الحية كـ **version 11 ACTIVE**.

## Migrations

- `20260911033000_versioned_financial_policy_and_delayed_lawyer_earnings.sql`
- `20260911033500_client_wallet_withdrawals_and_weekly_lawyer_payout_policy.sql`
- `20260911034000_expose_client_withdrawal_fee_snapshot_to_admin.sql`
- `20260911034500_allow_client_wallet_withdrawal_ledger_entries.sql`
- `20260911035000_snapshot_financial_policy_for_flexible_appointment_requests.sql`

## Commits الرئيسية

- `c1fb568dc6a7adc3520dfe1e8300d828e8e34c0c` — versioned financial policy + delayed lawyer earnings.
- `d753bd37acd7dfef9aefdd3b01fc91da1f4e719d` — client withdrawals + weekly payout policy.
- `80dca195447270e1f2f08248d5ff4949519e0204` — client wallet data/providers.
- `cc7afeaa1d2884175bd35c688910050d841b40b7` — client withdrawal UI.
- `af321a1d2aea1e02a3d5c36aa0ded38713966c7e` — withdrawal fee snapshot for admin.
- `a45543b72822df7002414edf1a1a7e2c475842ae` — financial management UI.
- `2e9c8faba12fcefe21aae1ed33b981a6da9c374b` — lawyer wallet policy display.
- `818991d64994dc6f427243c7aac2d3656254f7a4` — withdrawal ledger entry types.
- `8b35226e8ed2cb6dd0c8e31ce688a0ad60141cb2` — flexible appointment policy snapshot.
- `5029d6f202a791e3515fe2a9dcd414befe0ebfee` — wallet withdrawal notification routing.
- `9656a7c8104cee52ff0da7c1342f862ac5ab77ec` — PWA withdrawal deep links.
- `65ad6751b3d0ba904674a93229c6611ca8588196` — in-app notification routing.

## قواعد ثابتة للمستقبل

1. لا أثر رجعي لأي تعديل مالي.
2. استخدم snapshot العملية، لا الإعداد الحالي، لحساب العمليات القائمة.
3. لا يسحب العميل رصيداً محجوزاً.
4. لا يعتبر السحب مدفوعاً دون مرجع تحويل فعلي.
5. رسوم التحويل ليست عمولة منصة.
6. لا يتحول مستحق المحامي إلى متاح قبل `earnings_available_at`.
7. أي تعديل جديد في العمولة أو السحب أو فترة الحجز أو دورية التسوية يجب أن ينشئ إصدار سياسة جديداً للعمليات الجديدة.
