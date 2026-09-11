import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/theme_mode_provider.dart';
import '../core/services/notification_service.dart';
import '../shared/widgets/loading_widget.dart';
import '../shared/providers/global_loading_provider.dart';
import '../features/profile/presentation/providers/notifications_provider.dart';
import '../features/bookings/presentation/providers/bookings_provider.dart';
import '../features/chat/presentation/providers/chat_provider.dart';
import 'router.dart';
import 'theme.dart';

class LawConnectApp extends ConsumerWidget {
  const LawConnectApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final isLoading = ref.watch(globalLoadingProvider);
    final themeMode = ref.watch(themeModeProvider);
    ref.watch(unreadNotificationsCountProvider);

    ref.listen<AsyncValue<AppNotification>>(realtimeNotificationsProvider, (_, next) {
      next.whenData((notification) {
        NotificationService.showNotification(
          title: notification.title,
          body: notification.body,
          payload: notification.id,
        );
        ref.invalidate(notificationsProvider);
        ref.invalidate(unreadNotificationsCountProvider);

        final bookingRelated = notification.referenceType == 'booking' ||
            notification.type == 'booking' ||
            notification.type.contains('payment') ||
            notification.type.contains('cancellation');
        if (bookingRelated) {
          ref.invalidate(userBookingsProvider);
          ref.invalidate(lawyerBookingsProvider);
          final bookingId = notification.referenceType == 'booking'
              ? notification.referenceId
              : null;
          if (bookingId != null && bookingId.isNotEmpty) {
            ref.invalidate(bookingDetailsProvider(bookingId));
          }
        }

        final chatRelated = notification.referenceType == 'conversation' ||
            notification.referenceType == 'chat' ||
            notification.type == 'chat';
        if (chatRelated) {
          ref.invalidate(conversationsListProvider);
        }
      });
    });

    return MaterialApp.router(
      title: 'استشارة',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
        },
      ),
      locale: const Locale('ar', 'IQ'),
      supportedLocales: const [Locale('ar', 'IQ')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            if (isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: const Center(child: LoadingWidget(size: 60)),
                ),
              ),
          ],
        );
      },
    );
  }
}
