import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/authentication/presentation/providers/auth_provider.dart';
import 'main_bottom_nav.dart';

class AppShell extends ConsumerWidget {
  final Widget child;
  final String location;

  const AppShell({super.key, required this.child, required this.location});

  int _currentIndex(bool isLawyer) {
    if (isLawyer) {
      if (location == '/app-settings' || location == '/profile' || location == '/notification-settings' || location == '/payment-methods' || location == '/help-center' || location == '/lawyer-profile-edit' || location == '/lawyer-availability' || location == '/lawyer-specialization-change' || location == '/lawyer-wallet') return 2;
      if (location == '/bookings' || location == '/booking-details' || location == '/manual-payment' || location == '/manual-payment-required' || location == '/upload-payment' || location == '/payment-result' || location == '/chats' || location.startsWith('/chat/')) return 1;
      return 0;
    }
    if (location == '/app-settings' || location == '/profile' || location == '/notification-settings' || location == '/payment-methods' || location == '/help-center') return 3;
    if (location == '/bookings' || location == '/booking-details' || location == '/manual-payment' || location == '/manual-payment-required' || location == '/upload-payment' || location == '/payment-result' || location == '/chats' || location.startsWith('/chat/')) return 2;
    if (location == '/lawyers' || location.startsWith('/lawyer-details/')) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(authStateChangesProvider).valueOrNull;
    final isLawyer = user?.role == 'lawyer';
    final hidesShellNav = user == null ||
        location == '/create-booking' ||
        location.startsWith('/lawyer-details/') ||
        location == '/booking-details' ||
        location == '/lawyer-profile-edit' ||
        location == '/lawyer-availability' ||
        (isLawyer && location == '/notifications');

    if (hidesShellNav) return child;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: ColoredBox(color: scheme.surface, child: child),
      bottomNavigationBar: MainBottomNav(currentIndex: _currentIndex(isLawyer), isLawyer: isLawyer),
    );
  }
}
