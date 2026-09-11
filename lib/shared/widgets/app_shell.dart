import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/authentication/presentation/providers/auth_provider.dart';
import '../../features/bookings/presentation/widgets/client_appointment_requests_home_card.dart';
import 'main_bottom_nav.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  final String location;

  const AppShell({
    super.key,
    required this.child,
    required this.location,
  });

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final Map<String, Widget> _primaryBodies = <String, Widget>{};
  String? _cachedUserId;

  int _currentIndex(bool isLawyer) {
    final currentLocation = widget.location;
    if (isLawyer) {
      if (currentLocation == '/lawyer-profile-edit') return 2;
      if (currentLocation == '/app-settings' ||
          currentLocation == '/profile' ||
          currentLocation == '/notification-settings' ||
          currentLocation == '/payment-methods' ||
          currentLocation == '/help-center' ||
          currentLocation == '/lawyer-availability' ||
          currentLocation == '/lawyer-specialization-change' ||
          currentLocation == '/lawyer-wallet') {
        return 3;
      }
      if (currentLocation == '/bookings' ||
          currentLocation == '/booking-details' ||
          currentLocation == '/manual-payment' ||
          currentLocation == '/manual-payment-required' ||
          currentLocation == '/upload-payment' ||
          currentLocation == '/payment-result' ||
          currentLocation == '/chats' ||
          currentLocation.startsWith('/chat/')) {
        return 1;
      }
      return 0;
    }

    if (currentLocation == '/app-settings' ||
        currentLocation == '/profile' ||
        currentLocation == '/notification-settings' ||
        currentLocation == '/payment-methods' ||
        currentLocation == '/help-center') {
      return 3;
    }
    if (currentLocation == '/bookings' ||
        currentLocation == '/booking-details' ||
        currentLocation == '/manual-payment' ||
        currentLocation == '/manual-payment-required' ||
        currentLocation == '/upload-payment' ||
        currentLocation == '/payment-result' ||
        currentLocation == '/chats' ||
        currentLocation.startsWith('/chat/')) {
      return 2;
    }
    if (currentLocation == '/lawyers' ||
        currentLocation.startsWith('/lawyers/') ||
        currentLocation.startsWith('/lawyer-details/')) {
      return 1;
    }
    return 0;
  }

  List<String> _primaryKeys(bool isLawyer) => isLawyer
      ? const <String>[
          'lawyer:/lawyer-home',
          'lawyer:/bookings',
          'lawyer:/lawyer-profile-edit',
          'lawyer:/app-settings',
        ]
      : const <String>[
          'client:/home',
          'client:/lawyers',
          'client:/bookings',
          'client:/app-settings',
        ];

  String? _primaryKey(bool isLawyer) {
    final location = widget.location;
    if (isLawyer) {
      if (location == '/lawyer-home' ||
          location == '/bookings' ||
          location == '/lawyer-profile-edit' ||
          location == '/app-settings') {
        return 'lawyer:$location';
      }
      return null;
    }
    if (location == '/home' ||
        location == '/lawyers' ||
        location == '/bookings' ||
        location == '/app-settings') {
      return 'client:$location';
    }
    return null;
  }

  Widget _regularBody(BuildContext context, Widget child) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: ClipRect(
        child: RepaintBoundary(child: child),
      ),
    );
  }

  Widget _primaryBody({
    required bool isLawyer,
    required String location,
    required Widget child,
  }) {
    return _PrimaryTabBody(
      clientHome: !isLawyer && location == '/home',
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(authStateChangesProvider).valueOrNull;
    final isLawyer = user?.role == 'lawyer';
    final selectedIndex = _currentIndex(isLawyer);

    // Never reuse mounted tab state across authenticated accounts.
    if (_cachedUserId != user?.id) {
      _cachedUserId = user?.id;
      _primaryBodies.clear();
    }

    final hidesShellNav = user == null ||
        widget.location == '/create-booking' ||
        widget.location == '/client-wallet' ||
        widget.location.startsWith('/lawyer-details/') ||
        widget.location == '/booking-details' ||
        widget.location == '/lawyer-availability' ||
        (isLawyer && widget.location == '/notifications');

    // ClientWalletPage owns its Scaffold and keyboard handling. Returning it
    // directly avoids nesting that Scaffold inside AppShell's Scaffold and
    // ClipRect, which can clip/over-shift focused fields on iOS PWA.
    if (hidesShellNav) return widget.child;

    final currentPrimaryKey = _primaryKey(isLawyer);
    Widget body;
    if (currentPrimaryKey != null) {
      _primaryBodies.putIfAbsent(
        currentPrimaryKey,
        () => _primaryBody(
          isLawyer: isLawyer,
          location: widget.location,
          child: widget.child,
        ),
      );
      final keys = _primaryKeys(isLawyer);
      final activeIndex = keys.indexOf(currentPrimaryKey);
      body = IndexedStack(
        index: activeIndex < 0 ? 0 : activeIndex,
        children: [
          for (var i = 0; i < keys.length; i++)
            TickerMode(
              enabled: i == activeIndex,
              child: _primaryBodies[keys[i]] ?? const SizedBox.shrink(),
            ),
        ],
      );
    } else {
      body = _regularBody(context, widget.child);
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      resizeToAvoidBottomInset: true,
      body: body,
      bottomNavigationBar: MainBottomNav(
        currentIndex: selectedIndex,
        isLawyer: isLawyer,
      ),
    );
  }
}

class _PrimaryTabBody extends StatelessWidget {
  final bool clientHome;
  final Widget child;

  const _PrimaryTabBody({
    required this.clientHome,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (clientHome) {
      return SafeArea(
        bottom: false,
        child: Column(
          children: [
            const ClientAppointmentRequestsHomeCard(),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: child,
              ),
            ),
          ],
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: ClipRect(
        child: RepaintBoundary(child: child),
      ),
    );
  }
}
