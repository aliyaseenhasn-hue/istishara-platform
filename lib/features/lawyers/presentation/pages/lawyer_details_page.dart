import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../providers/lawyers_provider.dart';
import '../widgets/lawyer_achievements_gallery.dart';
import '../widgets/follow_lawyer_button.dart';

class LawyerDetailsPage extends ConsumerWidget {
  final String profileId;
  const LawyerDetailsPage({super.key, required this.profileId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final chatAvailability = ref.watch(chatAvailabilityForLawyerProvider(profileId));
    final currentUserId = ref.watch(authStateChangesProvider).value?.id;
    final isOwnProfile = currentUserId == profileId;
    final ownProfileAsync = isOwnProfile ? ref.watch(ownLawyerProfileProvider(profileId)) : null;
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
                        Positioned(top: 90, left: 0, right: 0, child: Center(child: CircleAvatar(radius: 59, backgroundColor: scheme.surface, child: CircleAvatar(radius: 54, backgroundColor: scheme.surfaceContainerHighest, backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null, child: avatar == null || avatar.isEmpty ? Text(name.substring(0, 1), style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: scheme.primary)) : null)))),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 225, 20, 110),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(mainAxisAlignment: MainAxisAlignment.center, children: [Flexible(child: Text(name, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurface, fontSize: 22, fontWeight: FontWeight.w900))), if (lawyer.verified) Padding(padding: const EdgeInsets.only(right: 6), child: Icon(Icons.verified_rounded, color: scheme.primary, size: 20))]),
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
                              const SizedBox(height: 16),
                              _Stats(lawyer: lawyer),
                              const SizedBox(height: 22),
                              _BioSection(bio: bio),
                              const SizedBox(height: 24),
                              LawyerAchievementsGallery(lawyerId: lawyer.id, editable: false),
                              const SizedBox(height: 20),
                              _ActionPanel(lawyer: lawyer),
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
                                onPressed: () => context.push('/create-booking', extra: {'lawyer': lawyer}),
                                icon: const Icon(Icons.calendar_month_rounded),
                                label: const Text('حجز موعد استشارة', style: TextStyle(fontWeight: FontWeight.w900)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 112,
                            height: 52,
                            child: chatAvailability.when(
                              loading: () => OutlinedButton.icon(
                                onPressed: null,
                                icon: const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                label: const Text('محادثة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                              ),
                              error: (_, __) => OutlinedButton.icon(
                                onPressed: null,
                                icon: const Icon(Icons.lock_outline_rounded, size: 18),
                                label: const Text('محادثة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                              ),
                              data: (conversationId) {
                                final enabled = conversationId != null;
                                return OutlinedButton.icon(
                                  onPressed: enabled ? () => context.push('/chat/$conversationId') : null,
                                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                                  label: Text(enabled ? 'محادثة' : 'بعد الحجز', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                );
                              },
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(textDirection: TextDirection.rtl, children: [
              Icon(Icons.badge_outlined, color: scheme.primary),
              const SizedBox(width: 8),
              Text('نبذة عن المحامي', textAlign: TextAlign.right, style: TextStyle(color: scheme.onSurface, fontSize: 17, fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(height: 10),
            Text(
              bio.isEmpty ? 'لم يضف المحامي نبذة مهنية بعد.' : bio,
              textAlign: TextAlign.right,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.7, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  final dynamic lawyer;
  const _ActionPanel({required this.lawyer});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.primaryContainer.withValues(alpha: .45),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('ابدأ طلبك', textAlign: TextAlign.right, style: TextStyle(color: scheme.onSurface, fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text('اختر الحجز أو طلب استشارة بنوع مختلف وفق الخدمات المتاحة للمحامي.', textAlign: TextAlign.right, style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5, fontSize: 12)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push('/create-booking', extra: {'lawyer': lawyer, 'isCustom': true}),
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('طلب استشارة بنوع مختلف', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(color: scheme.surfaceContainerLowest, borderRadius: BorderRadius.circular(16), border: Border.all(color: scheme.outlineVariant)),
      child: Row(children: [_item(context, lawyer.rating.toStringAsFixed(1), 'التقييم'), _divider(context), _item(context, '${lawyer.yearsExperience ?? 0}+', 'سنوات الخبرة'), _divider(context), _item(context, '$specializationCount', 'التخصصات')]),
    );
  }

  Widget _divider(BuildContext context) => Container(width: 1, height: 42, color: Theme.of(context).colorScheme.outlineVariant);
  Widget _item(BuildContext context, String value, String label) => Expanded(child: Column(children: [Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary)), const SizedBox(height: 3), Text(label, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant))]));
}
