import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../bookings/presentation/providers/bookings_provider.dart';
import '../providers/lawyers_provider.dart';
import '../widgets/lawyer_achievements_gallery.dart';
import '../widgets/follow_lawyer_button.dart';

class LawyerDetailsPage extends ConsumerWidget {
  final String profileId;
  const LawyerDetailsPage({super.key, required this.profileId});

  Future<void> _followAndReturnHome(BuildContext context, String lawyerId) async {
    final authUser = SupabaseConfig.client.auth.currentUser;
    if (authUser == null) return;
    final profile = await SupabaseConfig.client.from('profiles').select('id').eq('auth_id', authUser.id).maybeSingle();
    final followerId = profile?['id']?.toString();
    if (followerId == null || followerId.isEmpty) return;
    final existing = await SupabaseConfig.client
        .from('lawyer_followers')
        .select('lawyer_id')
        .eq('follower_id', followerId)
        .eq('lawyer_id', lawyerId)
        .maybeSingle();
    if (existing == null) {
      await SupabaseConfig.client.from('lawyer_followers').insert({'follower_id': followerId, 'lawyer_id': lawyerId});
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت متابعة المحامي. في حال توفر موعد سيتم إشعارك.')));
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (context.mounted) context.go('/home');
  }

  Future<void> _openBookingOrNoSlots(BuildContext context, WidgetRef ref, dynamic lawyer, {bool isCustom = false}) async {
    try {
      final slots = await ref.read(availableSlotsProvider(lawyer.profileId).future);
      if (!context.mounted) return;
      if (slots.isNotEmpty) {
        context.push('/create-booking', extra: {'lawyer': lawyer, if (isCustom) 'isCustom': true});
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          final scheme = Theme.of(dialogContext).colorScheme;
          return AlertDialog(
            icon: Icon(Icons.event_busy_outlined, size: 42, color: scheme.primary),
            title: const Text('لا توجد مواعيد متاحة', textAlign: TextAlign.center),
            content: const Text(
              'لا توجد مواعيد متاحة لدى هذا المحامي حالياً. يمكنك متابعة المحامي وسيتم إشعارك عند إضافة موعد جديد.',
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  context.go('/home');
                },
                child: const Text('إلغاء'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  try {
                    await _followAndReturnHome(context, lawyer.profileId);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر متابعة المحامي حالياً. حاول مرة أخرى.')));
                    }
                  }
                },
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('تابع المحامي'),
              ),
            ],
          );
        },
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر التحقق من المواعيد حالياً. حاول مرة أخرى.')));
      }
    }
  }

  Future<void> _openWhatsApp(BuildContext context, String value) async {
    var phone = value.replaceAll(RegExp(r'[^0-9+]'), '');
    if (phone.startsWith('00')) phone = '+${phone.substring(2)}';
    if (phone.startsWith('07')) phone = '+964${phone.substring(1)}';
    final uri = Uri.parse('https://wa.me/${phone.replaceAll('+', '')}');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح واتساب')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final currentUserId = ref.watch(authStateChangesProvider).value?.id;
    final isOwnProfile = currentUserId == profileId;
    final ownProfileAsync = isOwnProfile ? ref.watch(ownLawyerProfileProvider(profileId)) : null;
    final whatsapp = ref.watch(lawyerAcceptedWhatsAppProvider(profileId));

    return ColoredBox(
      color: scheme.surface,
      child: ref.watch(lawyerProfileProvider(profileId)).when(
        loading: () => const Center(child: LoadingWidget()),
        error: (_, __) => Center(child: Text('تعذر تحميل الملف الشخصي', style: TextStyle(color: scheme.onSurfaceVariant))),
        data: (publicLawyer) {
          if (publicLawyer == null) return Center(child: Text('المحامي غير موجود', style: TextStyle(color: scheme.onSurface)));
          final lawyer = ownProfileAsync?.value ?? publicLawyer;
          final name = lawyer.fullName?.trim().isNotEmpty == true ? lawyer.fullName!.trim() : 'محامي';
          final avatar = lawyer.avatarUrl;
          final bio = lawyer.bio?.trim() ?? '';
          final specializationText = lawyer.specializations.isEmpty ? 'محامي ومستشار قانوني' : lawyer.specializations.join('، ');
          final licenseClass = lawyer.practiceLicenseClass;

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    backgroundColor: scheme.surface,
                    foregroundColor: scheme.onSurface,
                    surfaceTintColor: Colors.transparent,
                    title: const Text('الملف الشخصي', style: TextStyle(fontWeight: FontWeight.w800)),
                    leading: IconButton(tooltip: 'رجوع', onPressed: () => context.pop(), icon: const Icon(Icons.arrow_forward_rounded)),
                  ),
                  SliverToBoxAdapter(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(height: 150, decoration: BoxDecoration(gradient: LinearGradient(colors: [scheme.primary, scheme.primaryContainer]))),
                        Positioned(
                          top: 90,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: CircleAvatar(
                              radius: 59,
                              backgroundColor: scheme.surface,
                              child: CircleAvatar(
                                radius: 54,
                                backgroundColor: scheme.surfaceContainerHighest,
                                backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
                                child: avatar == null || avatar.isEmpty ? Text(name.substring(0, 1), style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: scheme.primary)) : null,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 225, 20, 110),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Flexible(child: Text(name, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurface, fontSize: 22, fontWeight: FontWeight.w900))),
                                if (lawyer.verified) Padding(padding: const EdgeInsets.only(right: 6), child: Icon(Icons.verified_rounded, color: scheme.primary, size: 20)),
                              ]),
                              const SizedBox(height: 8),
                              Text(specializationText, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14, height: 1.4)),
                              if (!isOwnProfile) ...[
                                const SizedBox(height: 14),
                                FollowLawyerButton(lawyerId: lawyer.profileId),
                              ],
                              if (isOwnProfile && licenseClass != null && licenseClass.trim().isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.center,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(14), border: Border.all(color: scheme.outlineVariant)),
                                    child: Text('الصلاحية: ${licenseClass == 'مطلقة' ? 'مطلقة' : 'الفئة $licenseClass'}', style: TextStyle(color: scheme.onPrimaryContainer, fontSize: 13, fontWeight: FontWeight.w800)),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),
                              _Stats(lawyer: lawyer),
                              const SizedBox(height: 26),
                              _BioSection(bio: bio),
                              const SizedBox(height: 26),
                              LawyerAchievementsGallery(lawyerId: lawyer.id, editable: false),
                              const SizedBox(height: 24),
                              _ActionPanel(onCustomRequest: () => _openBookingOrNoSlots(context, ref, lawyer, isCustom: true)),
                              const SizedBox(height: 90),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!isOwnProfile)
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 8,
                  child: SafeArea(
                    top: false,
                    child: Material(
                      color: Colors.transparent,
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: ElevatedButton.icon(
                                onPressed: () => _openBookingOrNoSlots(context, ref, lawyer),
                                icon: const Icon(Icons.calendar_month_rounded),
                                label: const Text('حجز موعد استشارة', style: TextStyle(fontWeight: FontWeight.w900)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 118,
                            height: 52,
                            child: whatsapp.when(
                              loading: () => OutlinedButton.icon(onPressed: null, icon: const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)), label: const Text('واتساب', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                              error: (_, __) => OutlinedButton.icon(onPressed: null, icon: const Icon(Icons.lock_outline_rounded, size: 18), label: const Text('واتساب', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                              data: (number) => OutlinedButton.icon(
                                onPressed: number == null ? null : () => _openWhatsApp(context, number),
                                icon: Icon(number == null ? Icons.lock_outline_rounded : Icons.chat_rounded, size: 18),
                                label: Text(number == null ? 'بعد القبول' : 'واتساب', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _BioSection extends StatelessWidget {
  final String bio;
  const _BioSection({required this.bio});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: scheme.outlineVariant)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(textDirection: TextDirection.rtl, children: [Icon(Icons.badge_outlined, color: scheme.primary), const SizedBox(width: 8), Text('نبذة عن المحامي', textAlign: TextAlign.right, style: TextStyle(color: scheme.onSurface, fontSize: 17, fontWeight: FontWeight.w900))]),
          const SizedBox(height: 10),
          Text(bio.isEmpty ? 'لم يضف المحامي نبذة مهنية بعد.' : bio, textAlign: TextAlign.right, style: TextStyle(color: scheme.onSurfaceVariant, height: 1.7, fontSize: 13)),
        ]),
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  final VoidCallback onCustomRequest;
  const _ActionPanel({required this.onCustomRequest});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.primaryContainer.withValues(alpha: .45),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('ابدأ طلبك', textAlign: TextAlign.right, style: TextStyle(color: scheme.onSurface, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text('اختر الحجز أو طلب استشارة بنوع مختلف وفق الخدمات المتاحة للمحامي.', textAlign: TextAlign.right, style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5, fontSize: 12)),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: onCustomRequest, icon: const Icon(Icons.edit_note_rounded), label: const Text('طلب استشارة بنوع مختلف', style: TextStyle(fontWeight: FontWeight.w700))),
        ]),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  final dynamic lawyer;
  const _Stats({required this.lawyer});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final specializationCount = (lawyer.specializations as List).length;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(color: scheme.surfaceContainerLowest, borderRadius: BorderRadius.circular(16), border: Border.all(color: scheme.outlineVariant)),
      child: Row(children: [_item(context, lawyer.rating.toStringAsFixed(1), 'التقييم'), _divider(context), _item(context, '${lawyer.yearsExperience ?? 0}+', 'سنوات الخبرة'), _divider(context), _item(context, '$specializationCount', 'التخصصات')]),
    );
  }
  Widget _divider(BuildContext context) => Container(width: 1, height: 42, color: Theme.of(context).colorScheme.outlineVariant);
  Widget _item(BuildContext context, String value, String label) => Expanded(child: Column(children: [Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary)), const SizedBox(height: 4), Text(label, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant))]));
}
