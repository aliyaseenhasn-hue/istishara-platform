import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/authentication/presentation/providers/auth_provider.dart';
import 'main_bottom_nav.dart';

class AppShell extends ConsumerWidget {
  final Widget child;
  final String location;

  const AppShell({super.key, required this.child, required this.location});

  int _currentIndex(bool isLawyer) {
    final currentLocation = location;
    if (isLawyer) {
      if (currentLocation == '/lawyer-profile-edit') return 2;
      if (currentLocation == '/app-settings' || currentLocation == '/profile' || currentLocation == '/notification-settings' || currentLocation == '/payment-methods' || currentLocation == '/help-center' || currentLocation == '/lawyer-availability' || currentLocation == '/lawyer-specialization-change' || currentLocation == '/lawyer-wallet') return 3;
      if (currentLocation == '/bookings' || currentLocation == '/booking-details' || currentLocation == '/manual-payment' || currentLocation == '/manual-payment-required' || currentLocation == '/upload-payment' || currentLocation == '/payment-result' || currentLocation == '/chats' || currentLocation.startsWith('/chat/')) return 1;
      return 0;
    }
    if (currentLocation == '/app-settings' || currentLocation == '/profile' || currentLocation == '/notification-settings' || currentLocation == '/payment-methods' || currentLocation == '/help-center') return 3;
    if (currentLocation == '/bookings' || currentLocation == '/booking-details' || currentLocation == '/manual-payment' || currentLocation == '/manual-payment-required' || currentLocation == '/upload-payment' || currentLocation == '/payment-result' || currentLocation == '/chats' || currentLocation.startsWith('/chat/')) return 2;
    if (currentLocation == '/lawyers' || currentLocation.startsWith('/lawyer-details/')) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(authStateChangesProvider).valueOrNull;
    final isLawyer = user?.role == 'lawyer';
    final selectedIndex = _currentIndex(isLawyer);

    final hidesShellNav = user == null ||
        location == '/create-booking' ||
        location.startsWith('/lawyer-details/') ||
        location == '/booking-details' ||
        location == '/lawyer-availability' ||
        (isLawyer && location == '/notifications');

    if (hidesShellNav) return child;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: ColoredBox(
        color: scheme.surface,
        child: ClipRect(
          child: RepaintBoundary(child: child),
        ),
      ),
      bottomNavigationBar: MainBottomNav(
        currentIndex: selectedIndex,
        isLawyer: isLawyer,
      ),
    );
  }
}
