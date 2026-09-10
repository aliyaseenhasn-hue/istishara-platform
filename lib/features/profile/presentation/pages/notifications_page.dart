import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/styles/priority_visuals.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../bookings/data/models/booking_model.dart';
import '../providers/notifications_provider.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  Future<void> _open(BuildContext context, AppNotification item) async {
    final referenceId = item.referenceId?.trim();
    final isAppointmentTarget = item.referenceType == 'appointment_request';
    final isBookingTarget = item.referenceType == 'booking' ||
        item.referenceType == 'payment' ||
        item.type == 'booking' ||
        item.type == 'payment';

    if (isAppointmentTarget) {
      final suffix = referenceId != null && referenceId.isNotEmpty
          ? '?request_id=${Uri.encodeQueryComponent(referenceId)}'
          : '';
      if (context.mounted) context.push('/appointment-requests$suffix');
      return;
    }

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
          context.push(
            '/booking-details',
            extra: BookingModel.fromJson(row).toEntity(),
          );
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
    final scheme = Theme.of(context).colorScheme;
    final async = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadNotificationsCountProvider).valueOrNull ?? 0;

    Future<void> refresh() async {
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationsCountProvider);
      await ref.read(notificationsProvider.future);
      await ref.read(unreadNotificationsCountProvider.future);
    }

    Future<void> markAllRead() async {
      try {
        await markAllNotificationsAsRead();
        await refresh();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم اعتبار جميع الإشعارات مقروءة')),
          );
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تعذر تحديث حالة الإشعارات. حاول مرة أخرى.'),
            ),
          );
        }
      }
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      body: RefreshIndicator(
        color: AppColors.teal,
        onRefresh: refresh,
        child: async.when(
          loading: () => const LoadingWidget(size: 30),
          error: (_, __) => _NotificationState(
            icon: Icons.notifications_off_rounded,
            title: 'تعذر تحميل التنبيهات',
            actionLabel: 'إعادة المحاولة',
            onAction: refresh,
          ),
          data: (items) => CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _NotificationsHeader(
                  unread: unread,
                  onMarkAll: markAllRead,
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
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Directionality(
                        textDirection: ui.TextDirection.ltr,
                        child: Dismissible(
                          key: ValueKey('notification-${item.id}'),
                          direction: DismissDirection.startToEnd,
                          dismissThresholds: const {
                            DismissDirection.startToEnd: 0.30,
                          },
                          confirmDismiss: (_) async {
                            try {
                              await deleteNotification(item.id);
                              return true;
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'تعذر حذف الإشعار. حاول مرة أخرى.',
                                    ),
                                  ),
                                );
                              }
                              return false;
                            }
                          },
                          onDismissed: (_) {
                            ref.invalidate(notificationsProvider);
                            ref.invalidate(unreadNotificationsCountProvider);
                          },
                          background: Container(
                            margin: const EdgeInsets.only(bottom: 13),
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            alignment: Alignment.centerLeft,
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(23),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.delete_outline_rounded, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'حذف',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          child: Directionality(
                            textDirection: ui.TextDirection.rtl,
                            child: _NotificationCard(
                              item: item,
                              onOpen: () => _open(context, item),
                              onRefresh: refresh,
                            ),
                          ),
                        ),
                      );
                    },
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
  final Future<void> Function() onMarkAll;

  const _NotificationsHeader({
    required this.unread,
    required this.onMarkAll,
  });

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
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .22),
                  ),
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: AppColors.goldLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.goldLight.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.goldLight.withValues(alpha: .30),
                ),
              ),
              child: Text(
                unread == 0 ? 'كل شيء محدث' : '$unread تنبيه غير مقروء',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: onMarkAll,
              icon: const Icon(Icons.done_all_rounded, size: 19),
              label: const Text(
                'اعتبار جميع الإشعارات مقروءة',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                backgroundColor: AppColors.goldLight,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'اسحب الإشعار إلى اليمين لحذفه',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: 6),
              Icon(
                Icons.swipe_right_alt_rounded,
                color: Colors.white70,
                size: 18,
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

  const _NotificationCard({
    required this.item,
    required this.onOpen,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unread = !item.isRead;
    final visual = PriorityVisuals.notification(
      type: item.type,
      title: item.title,
      body: item.body,
    );
    final time = DateFormat('yyyy/MM/dd - HH:mm', 'ar').format(
      item.createdAt.toLocal(),
    );
    final prominent = unread || visual.level >= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      decoration: BoxDecoration(
        color: prominent
            ? Color.alphaBlend(
                visual.accent.withValues(alpha: unread ? .08 : .045),
                scheme.surface,
              )
            : scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: visual.accent.withValues(alpha: prominent ? .55 : .22),
          width: visual.level >= 3 ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: visual.accent.withValues(alpha: prominent ? .11 : .035),
            blurRadius: 18,
            offset: const Offset(0, 7),
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
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: visual.level >= 3 ? 5 : 3,
                  decoration: BoxDecoration(
                    color: visual.accent,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(23),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _NotificationIcon(
                          icon: visual.icon,
                          color: visual.accent,
                          unread: unread,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (prominent)
                                    Container(
                                      margin: const EdgeInsetsDirectional.only(
                                        start: 8,
                                        top: 2,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: visual.background,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        unread ? '${visual.label} • جديد' : visual.label,
                                        style: TextStyle(
                                          color: visual.foreground,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      textAlign: TextAlign.right,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: scheme.onSurface,
                                        fontSize: 15,
                                        height: 1.35,
                                        fontWeight: prominent
                                            ? FontWeight.w900
                                            : FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 7),
                              Text(
                                item.body,
                                textAlign: TextAlign.right,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 13,
                                  height: 1.55,
                                ),
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
                                      style: TextStyle(
                                        color: scheme.outline,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.schedule_rounded,
                                    size: 14,
                                    color: visual.accent,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool unread;

  const _NotificationIcon({
    required this.icon,
    required this.color,
    required this.unread,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: unread ? .22 : .15),
            color.withValues(alpha: .06),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withValues(alpha: unread ? .34 : .20)),
      ),
      child: Icon(icon, color: color, size: 25),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

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
              child: const Icon(
                Icons.notifications_active_rounded,
                size: 45,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'لا توجد تنبيهات حالياً',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ستظهر هنا آخر تحديثات حسابك واستشاراتك.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.5,
              ),
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

  const _NotificationState({
    required this.icon,
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

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
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 38, color: AppColors.error),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              label: Text(
                actionLabel,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
