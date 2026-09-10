import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../providers/chat_provider.dart';

final conversationsListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final authUser = SupabaseConfig.client.auth.currentUser;
  if (authUser == null) return const [];

  final profile = await SupabaseConfig.client
      .from('profiles')
      .select('id')
      .eq('auth_id', authUser.id)
      .maybeSingle();
  final profileId = profile?['id']?.toString();
  if (profileId == null) return const [];

  final rows = await SupabaseConfig.client
      .from('conversations')
      .select('id,user_id,lawyer_id,last_message,last_message_at')
      .or('user_id.eq.$profileId,lawyer_id.eq.$profileId')
      .order('last_message_at', ascending: false);

  return (rows as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList();
});

class ConversationsPage extends ConsumerWidget {
  const ConversationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final conversations = ref.watch(conversationsListProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المحادثات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: scheme.onSurface)),
            const SizedBox(height: 3),
            Text('تواصل مع محاميك بأمان', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
      body: conversations.when(
        loading: () => const LoadingWidget(size: 30),
        error: (error, _) => _StateView(
          icon: Icons.cloud_off_rounded,
          title: 'تعذر تحميل المحادثات',
          message: error.toString().replaceFirst('Exception: ', ''),
          action: FilledButton.tonalIcon(
            onPressed: () => ref.invalidate(conversationsListProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const _StateView(
              icon: Icons.forum_outlined,
              title: 'لا توجد محادثات حالياً',
              message: 'ستظهر محادثاتك هنا بعد بدء الاستشارة والتواصل مع المحامي.',
            );
          }

          return RefreshIndicator(
            color: AppColors.teal,
            onRefresh: () async => ref.invalidate(conversationsListProvider),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final conversation = items[index];
                final id = conversation['id']?.toString();
                if (id == null) return const SizedBox.shrink();

                return Consumer(
                  builder: (context, ref, _) {
                    final name = ref.watch(chatOtherPartyNameProvider(id));
                    final lastMessage = conversation['last_message']?.toString().trim();
                    final displayName = name.maybeWhen(
                      data: (value) => value?.trim().isNotEmpty == true ? value! : 'المحادثة',
                      orElse: () => 'جاري تحميل الاسم...',
                    );

                    return Material(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => context.push('/chat/$id'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: scheme.outlineVariant.withValues(alpha: .62)),
                            boxShadow: [
                              BoxShadow(color: scheme.shadow.withValues(alpha: .05), blurRadius: 16, offset: const Offset(0, 6)),
                            ],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 27,
                                backgroundColor: scheme.primaryContainer,
                                child: Icon(Icons.person_outline_rounded, color: scheme.primary, size: 27),
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: scheme.onSurface, fontSize: 15.5, fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      lastMessage?.isNotEmpty == true ? lastMessage! : 'لا توجد رسائل بعد',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5, height: 1.3),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.chevron_left_rounded, color: scheme.onSurfaceVariant),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _StateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const _StateView({required this.icon, required this.title, required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
              child: Icon(icon, size: 35, color: scheme.primary),
            ),
            const SizedBox(height: 18),
            Text(title, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurface, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant, height: 1.55)),
            if (action != null) ...[const SizedBox(height: 14), action!],
          ],
        ),
      ),
    );
  }
}
