import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:storage_client/storage_client.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/theme_mode_provider.dart';
import '../../../../shared/widgets/safe_network_avatar.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateChangesProvider).value;
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final scheme = Theme.of(context).colorScheme;
    if (user == null) return Scaffold(backgroundColor: scheme.surface, body: Center(child: Text('يرجى تسجيل الدخول', style: TextStyle(color: scheme.onSurface))));

    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 260,
          pinned: true,
          elevation: 0,
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          title: const Text('الملف الشخصي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          centerTitle: true,
          flexibleSpace: FlexibleSpaceBar(background: _profileHero(user: user, isDark: isDark)),
        ),
        SliverPadding(padding: const EdgeInsets.fromLTRB(20, 22, 20, 50), sliver: SliverList(delegate: SliverChildListDelegate([
          _section(context, 'الاستشارات', [
            _tile(context, Icons.history_rounded, 'سجل الاستشارات', 'الحجوزات والاستشارات السابقة', () => context.push('/bookings')),
            _tile(context, Icons.payments_outlined, 'طرق الدفع', 'إدارة وسائل الدفع', () => context.push('/payment-methods')),
          ]),
          const SizedBox(height: 22),
          _section(context, 'الحساب والإعدادات', [
            _tile(context, Icons.person_outline_rounded, 'المعلومات الشخصية', 'الصورة والاسم ورقم واتساب وبيانات التواصل', () => _showEditProfileDialog(context, ref)),
            if (user.role == 'lawyer')
              _tile(context, Icons.badge_outlined, 'المعلومات المهنية', 'التخصص والباقات وأوقات التوفر والبيانات المهنية', () => context.push('/lawyer-profile-edit')),
            Card(elevation: 0, margin: const EdgeInsets.only(bottom: 10), color: scheme.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17), side: BorderSide(color: scheme.outlineVariant)), child: SwitchListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2), secondary: _iconBox(context, isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded), title: Text('مظهر التطبيق', style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w700)), subtitle: Text(isDark ? 'الوضع الداكن' : 'الوضع الفاتح', style: TextStyle(color: scheme.onSurfaceVariant)), value: isDark, activeThumbColor: AppColors.gold, activeTrackColor: AppColors.goldSoft, onChanged: (v) => ref.read(themeModeProvider.notifier).setMode(v ? ThemeMode.dark : ThemeMode.light))),
            _tile(context, Icons.notifications_none_rounded, 'الإشعارات', 'إدارة تفضيلات التنبيهات', () => context.push('/notification-settings')),
            _tile(context, Icons.help_outline_rounded, 'مركز المساعدة', 'الأسئلة والدعم', () => context.push('/help-center')),
          ]),
          const SizedBox(height: 22),
          _section(context, 'الدعم والحساب', [
            _tile(context, Icons.privacy_tip_outlined, 'سياسة الخصوصية', 'مراجعة سياسة حماية البيانات', () => _showPrivacyPolicy(context)),
            Card(elevation: 0, margin: const EdgeInsets.only(bottom: 10), color: scheme.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17), side: BorderSide(color: scheme.outlineVariant)), child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3), leading: _iconBox(context, Icons.logout_rounded, danger: true), title: const Text('تسجيل الخروج', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w800)), onTap: () => _logout(context, ref))),
            Center(child: TextButton.icon(onPressed: () => _showDeleteConfirmation(context, ref), icon: Icon(Icons.delete_outline_rounded, color: scheme.onSurfaceVariant, size: 18), label: Text('حذف الحساب نهائياً', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)))),
          ]),
          const SizedBox(height: 25),
          Center(child: Text('استشارة • منصتك القانونية', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11))),
        ]))),
      ]),
    );
  }

  Widget _profileHero({required dynamic user, required bool isDark}) => Builder(builder: (context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: isDark
              ? const [Color(0xFF1A2811), Color(0xFF355A2B), Color(0xFF17684C)]
              : const [AppColors.primaryDark, AppColors.primary, AppColors.secondary],
        ),
      ),
      child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: AppColors.goldTransparentStrong, shape: BoxShape.circle, border: Border.all(color: AppColors.goldSoft, width: 2)),
          child: SafeNetworkAvatar(
            imageUrl: user.avatarUrl,
            radius: 49,
            backgroundColor: AppColors.surfaceVariant,
            iconColor: AppColors.primary,
            icon: Icons.person_rounded,
            iconSize: 52,
          ),
        ),
        const SizedBox(height: 12),
        Text(user.fullName ?? 'مستخدم', style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: AppColors.goldTransparent, borderRadius: BorderRadius.circular(99)),
          child: const Text('يمكن تعديل البيانات من المعلومات الشخصية', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 18),
      ])),
    );
  });

  Widget _section(BuildContext context, String title, List<Widget> children) { final scheme = Theme.of(context).colorScheme; return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Padding(padding: const EdgeInsetsDirectional.only(end: 6, bottom: 9), child: Text(title, textAlign: TextAlign.right, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w800))), ...children]); }
  Widget _iconBox(BuildContext context, IconData icon, {bool danger = false}) { final scheme = Theme.of(context).colorScheme; return Container(width: 42, height: 42, alignment: Alignment.center, decoration: BoxDecoration(color: danger ? AppColors.error.withValues(alpha: .10) : AppColors.goldTransparent, borderRadius: BorderRadius.circular(13), border: danger ? null : Border.all(color: AppColors.goldTransparentStrong)), child: Icon(icon, color: danger ? AppColors.error : scheme.primary, size: 21)); }
  Widget _tile(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) { final scheme = Theme.of(context).colorScheme; return Card(elevation: 0, margin: const EdgeInsets.only(bottom: 10), color: scheme.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17), side: BorderSide(color: scheme.outlineVariant)), child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3), leading: _iconBox(context, icon), title: Text(title, textAlign: TextAlign.right, style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w700)), subtitle: Text(subtitle, textAlign: TextAlign.right, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)), trailing: Icon(Icons.chevron_left_rounded, color: scheme.primary), onTap: onTap)); }

  void _showPrivacyPolicy(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .78,
        minChildSize: .55,
        maxChildSize: .94,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text('سياسة الخصوصية', textAlign: TextAlign.right, style: TextStyle(color: scheme.primary, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            _privacySection(context, 'البيانات التي نجمعها', 'قد تشمل الاسم ورقم الهاتف أو البريد الإلكتروني عند استخدامه ورقم واتساب والمدينة وبيانات الحساب والصورة الشخصية وبيانات الحجوزات والرسائل والملفات التي يختار المستخدم رفعها، إضافة إلى بيانات تقنية لازمة لتشغيل الإشعارات والخدمة.'),
            _privacySection(context, 'بيانات المحامين', 'قد تشمل بيانات الملف المهني والتخصص والخبرة وبيانات الترخيص أو النقابة ومستندات التحقق. لا تُعامل مستندات التحقق كمحتوى عام.'),
            _privacySection(context, 'لماذا نستخدمها؟', 'لتشغيل الحسابات والحجوزات والاستشارات والمدفوعات والتواصل والإشعارات ودعم المستخدمين ومنع إساءة استخدام المنصة.'),
            _privacySection(context, 'مشاركة البيانات', 'تظهر المعلومات وفق حالة الحجز والصلاحيات المعتمدة، وقد تُعالج البيانات التقنية اللازمة لدى مزودي الخدمات الذين تعتمد عليهم المنصة لتشغيل الاستضافة والمصادقة والإشعارات وتسجيل الدخول والدفع عند استخدامه.'),
            _privacySection(context, 'حذف الحساب', 'يمكن طلب حذف الحساب من داخل التطبيق. عند اكتمال الحذف تُزال بيانات التعريف المباشر وهوية تسجيل الدخول والملفات الشخصية التي لا يلزم الاحتفاظ بها. قد تبقى سجلات محدودة مرتبطة بالحجوزات أو المدفوعات أو النزاعات أو متطلبات أمنية وقانونية مشروعة، وتُفصل عن الملف العام كلما أمكن.'),
            _privacySection(context, 'الاستشارات النشطة', 'قد يلزم إنهاء أو إلغاء الاستشارات النشطة قبل إكمال حذف الحساب حتى لا يؤدي الحذف إلى الإخلال بخدمة جارية أو بحقوق الأطراف.'),
            _privacySection(context, 'التحديثات', 'قد تتغير هذه السياسة عند إضافة وظائف أو مزودي خدمات أو متطلبات جديدة، وتنشر النسخة المحدثة مع تاريخ سريان واضح.'),
            const SizedBox(height: 6),
            Text('آخر تحديث: 12 سبتمبر 2026. النسخة الكاملة منشورة في الموقع الرسمي لمنصة استشارة.', textAlign: TextAlign.right, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11, height: 1.6)),
          ],
        ),
      ),
    );
  }

  Widget _privacySection(BuildContext context, String title, String body) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: scheme.surfaceContainerLowest, borderRadius: BorderRadius.circular(15), border: Border.all(color: scheme.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(title, textAlign: TextAlign.right, style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Text(body, textAlign: TextAlign.right, style: TextStyle(color: scheme.onSurface, fontSize: 12, height: 1.6)),
      ]),
    );
  }

  Future<void> _updateAvatar(
    BuildContext context,
    WidgetRef ref, {
    String? fullName,
    String? whatsapp,
    String? city,
  }) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1200);
      if (image == null) return;
      final user = ref.read(authStateChangesProvider).value;
      if (user == null) return;

      final normalizedName = fullName?.trim();
      final normalizedWhatsapp = whatsapp?.trim();
      if (normalizedName != null || normalizedWhatsapp != null || city != null) {
        if (normalizedName == null || normalizedName.isEmpty || normalizedWhatsapp == null || normalizedWhatsapp.isEmpty) {
          throw Exception('الاسم الكامل ورقم واتساب مطلوبان');
        }
        await SupabaseConfig.client.rpc('update_own_profile_contact', params: {
          'p_full_name': normalizedName,
          'p_phone': normalizedWhatsapp,
          'p_whatsapp_number': normalizedWhatsapp,
          'p_city': city?.trim().isEmpty == true ? null : city?.trim(),
        });
      }

      final bytes = await image.readAsBytes();
      final ext = image.name.split('.').last.toLowerCase();
      final contentType = switch (ext) {'png' => 'image/png', 'webp' => 'image/webp', _ => 'image/jpeg'};
      final path = '${user.id}/profile_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await SupabaseConfig.client.storage.from('avatars').uploadBinary(path, bytes, fileOptions: FileOptions(upsert: true, contentType: contentType));
      final url = SupabaseConfig.client.storage.from('avatars').getPublicUrl(path);
      await SupabaseConfig.client.from('profiles').update({'avatar_url': url}).eq('auth_id', user.id);
      await ref.read(authRepositoryProvider).refreshUser();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(normalizedName == null ? 'تم تحديث الصورة الشخصية' : 'تم تحديث الصورة والمعلومات الشخصية بنجاح')),
        );
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحديث الصورة: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: AppColors.error));
    }
  }

  Future<void> _showEditProfileDialog(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authStateChangesProvider).value;
    if (user == null) return;
    try {
      final row = await SupabaseConfig.client.from('profiles').select('full_name,whatsapp_number,city').eq('auth_id', user.id).maybeSingle();
      if (!context.mounted) return;
      final nameController = TextEditingController(text: row?['full_name']?.toString() ?? user.fullName ?? '');
      final whatsappController = TextEditingController(text: row?['whatsapp_number']?.toString() ?? user.phone ?? '');
      final governorateController = TextEditingController(text: row?['city']?.toString() ?? '');
      var saving = false;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            surfaceTintColor: AppColors.goldTransparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: AppColors.goldSoft)),
            title: const Text('المعلومات الشخصية', textAlign: TextAlign.right, style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w900)),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.goldTransparent, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.goldTransparentStrong)),
                  child: Row(children: [
                    CircleAvatar(radius: 28, backgroundColor: AppColors.surfaceVariant, backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty ? NetworkImage(user.avatarUrl!) : null, child: user.avatarUrl == null || user.avatarUrl!.isEmpty ? const Icon(Icons.person_rounded, color: AppColors.primary) : null),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: saving
                            ? null
                            : () => _updateAvatar(
                                  context,
                                  ref,
                                  fullName: nameController.text,
                                  whatsapp: whatsappController.text,
                                  city: governorateController.text,
                                ),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('تغيير الصورة الشخصية'),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'الاسم الكامل', prefixIcon: Icon(Icons.person_outline))),
                const SizedBox(height: 10),
                TextField(controller: whatsappController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم واتساب للتواصل', hintText: '+9647xxxxxxxxx', prefixIcon: Icon(Icons.chat_outlined))),
                const SizedBox(height: 10),
                TextField(controller: governorateController, decoration: const InputDecoration(labelText: 'المحافظة', prefixIcon: Icon(Icons.location_on_outlined))),
                const SizedBox(height: 10),
                const Align(alignment: Alignment.centerRight, child: Text('يمكنك إدارة الصورة والاسم ورقم واتساب والمحافظة من هنا.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
              ]),
            ),
            actions: [
              TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: saving ? null : () async {
                  final name = nameController.text.trim();
                  final whatsapp = whatsappController.text.trim();
                  if (name.isEmpty || whatsapp.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الاسم الكامل ورقم واتساب مطلوبان')));
                    return;
                  }
                  setState(() => saving = true);
                  try {
                    await SupabaseConfig.client.rpc('update_own_profile_contact', params: {
                      'p_full_name': name,
                      'p_phone': whatsapp,
                      'p_whatsapp_number': whatsapp,
                      'p_city': governorateController.text.trim().isEmpty ? null : governorateController.text.trim(),
                    });
                    await ref.read(authRepositoryProvider).refreshUser();
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ المعلومات بنجاح')));
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ المعلومات: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: AppColors.error));
                    setState(() => saving = false);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary, foregroundColor: Colors.white),
                child: Text(saving ? 'جاري الحفظ...' : 'حفظ التغييرات'),
              ),
            ],
          ),
        ),
      );
      nameController.dispose();
      whatsappController.dispose();
      governorateController.dispose();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحميل المعلومات: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: AppColors.error));
    }
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async { await ref.read(authControllerProvider.notifier).logout(); if (context.mounted) context.go('/login'); }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الحساب؟'),
        content: const Text('هل أنت متأكد من حذف حسابك نهائياً؟ لا يمكن التراجع عن هذا الإجراء. ستُزال بيانات التعريف وهوية تسجيل الدخول والملفات الشخصية التي لا يلزم الاحتفاظ بها، وقد تبقى سجلات محدودة مرتبطة بالحجوزات أو المدفوعات عند الحاجة القانونية أو التشغيلية. يجب إنهاء أو إلغاء أي استشارة نشطة أولاً.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authControllerProvider.notifier).deleteAccount();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white, elevation: 0),
            child: const Text('نعم، احذف الحساب', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
