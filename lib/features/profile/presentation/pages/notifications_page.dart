import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../bookings/data/models/booking_model.dart';
import '../providers/notifications_provider.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  Future<void> _open(BuildContext context, AppNotification item) async {
    final referenceId = item.referenceId?.trim();
    final isBookingTarget = item.referenceType == 'booking' ||
        item.referenceType == 'payment' ||
        item.type == 'booking' ||
        item.type == 'payment';

    if (isBookingTarget && referenceId != null && referenceId.isNotEmpty) {
      try {
        final response = await SupabaseConfig.client.rpc(
          'get_booking_for_notification',
          params: {'p_booking_id': referenceId},
        );
        Map<String, dynamic>? row;
        if (response is List && response.isNotEmpty) {
          row = Map<String, dynamic>.from(response.first as Map);
        } else if (response is Map && response.isNotEmpty) {
          row = Map<String, dynamic>.from(response);
        }
        if (row != null && context.mounted) {
          final booking = BookingModel.fromJson(row).toEntity();
          context.push('/booking-details', extra: booking);
          return;
        }
      } catch (_) {}
    }

    if (!context.mounted) return;
    if (item.type == 'chat' || item.referenceType == 'conversation') {
      context.push('/chats');
    } else if (isBookingTarget) {
      context.push('/bookings');
    } else if (item.type == 'profile') {
      context.push('/profile');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadNotificationsCountProvider).valueOrNull ?? 0;

    Future<void> refresh() async {
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationsCountProvider);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.teal,
        onRefresh: refresh,
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.teal)),
          error: (_, __) => _NotificationState(
            icon: Icons.notifications_off_rounded,
            title: 'تعذر تحميل التنبيهات',
            actionLabel: 'إعادة المحاولة',
            onAction: refresh,
          ),
          data: (items) => CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _NotificationsHeader(
                  unread: unread,
                  onMarkAll: unread == 0
                      ? null
                      : () async {
                          await markAllNotificationsAsRead();
                          await refresh();
                        },
                ),
              ),
              if (items.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyNotifications(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 34),
                  sliver: SliverList.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) => _NotificationCard(
                      item: items[index],
                      onOpen: () => _open(context, items[index]),
                      onRefresh: refresh,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationsHeader extends StatelessWidget {
  final int unread;
  final Future<void> Function()? onMarkAll;

  const _NotificationsHeader({required this.unread, required this.onMarkAll});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 12,
        left: 18,
        right: 18,
        bottom: 22,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.tertiary, AppColors.teal],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 19),
                color: Colors.white,
                tooltip: 'رجوع',
              ),
              const Spacer(),
              const Text(
                'التنبيهات',
                textAlign: TextAlign.right,
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 10),
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: .22)),
                ),
                child: const Icon(Icons.notifications_active_rounded, color: AppColors.goldLight),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (onMarkAll != null)
                TextButton.icon(
                  onPressed: onMarkAll,
                  icon: const Icon(Icons.done_all_rounded, size: 17),
                  label: const Text('قراءة الكل'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                )
              else
                const SizedBox.shrink(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.goldLight.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.goldLight.withValues(alpha: .30)),
                ),
                child: Text(
                  unread == 0 ? 'كل شيء محدث' : '$unread تنبيه غير مقروء',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification item;
  final Future<void> Function() onOpen;
  final Future<void> Function() onRefresh;

  const _NotificationCard({required this.item, required this.onOpen, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final unread = !item.isRead;
    final visual = _visualFor(item.type);
    final time = DateFormat('yyyy/MM/dd - HH:mm', 'ar').format(item.createdAt.toLocal());

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: unread ? visual.color.withValues(alpha: .38) : AppColors.outlineVariant.withValues(alpha: .75),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: unread ? .10 : .045),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(23),
          onTap: () async {
            if (unread) await markNotificationAsRead(item.id);
            await onRefresh();
            await onOpen();
          },
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NotificationIcon(icon: visual.icon, color: visual.color, unread: unread),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (unread)
                            Container(
                              margin: const EdgeInsetsDirectional.only(start: 8, top: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: visual.color.withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'جديد',
                                style: TextStyle(color: visual.color, fontSize: 10, fontWeight: FontWeight.w900),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              item.title,
                              textAlign: TextAlign.right,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                height: 1.35,
                                fontWeight: unread ? FontWeight.w900 : FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        item.body,
                        textAlign: TextAlign.right,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.55),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Text(
                              time,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.outline, fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.schedule_rounded, size: 14, color: visual.color),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _NotificationVisual _visualFor(String type) {
    switch (type.toLowerCase()) {
      case 'chat':
      case 'message':
        return const _NotificationVisual(Icons.chat_bubble_rounded, AppColors.teal);
      case 'payment':
        return const _NotificationVisual(Icons.payments_rounded, AppColors.success);
      case 'booking':
        return const _NotificationVisual(Icons.event_available_rounded, AppColors.primaryLight);
      case 'profile':
        return const _NotificationVisual(Icons.person_rounded, Color(0xFF7C4DFF));
      case 'warning':
      case 'alert':
        return const _NotificationVisual(Icons.warning_amber_rounded, AppColors.warning);
      default:
        return const _NotificationVisual(Icons.notifications_rounded, AppColors.secondary);
    }
  }
}

class _NotificationVisual {
  final IconData icon;
  final Color color;

  const _NotificationVisual(this.icon, this.color);
}

class _NotificationIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool unread;

  const _NotificationIcon({required this.icon, required this.color, required this.unread});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: .19), color.withValues(alpha: .07)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withValues(alpha: unread ? .30 : .18)),
      ),
      child: Icon(icon, color: color, size: 25),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryContainer, AppColors.teal],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.teal.withValues(alpha: .18),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(Icons.notifications_active_rounded, size: 45, color: Colors.white),
            ),
            const SizedBox(height: 22),
            const Text(
              'لا توجد تنبيهات حالياً',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'ستظهر هنا آخر تحديثات حسابك واستشاراتك.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String actionLabel;
  final Future<void> Function() onAction;

  const _NotificationState({required this.icon, required this.title, required this.actionLabel, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(color: AppColors.errorContainer, borderRadius: BorderRadius.circular(24)),
              child: Icon(icon, size: 38, color: AppColors.error),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}
