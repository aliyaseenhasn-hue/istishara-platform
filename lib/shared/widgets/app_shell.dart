import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/authentication/presentation/providers/auth_provider.dart';
import 'main_bottom_nav.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  final String location;

  const AppShell({super.key, required this.child, required this.location});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final Map<String, Widget> _cachedTabs = <String, Widget>{};
  String? _roleCacheKey;

  int _currentIndex(bool isLawyer) {
    final location = widget.location;
    if (isLawyer) {
      if (location == '/lawyer-profile-edit') return 2;
      if (location == '/app-settings' || location == '/profile' || location == '/notification-settings' || location == '/payment-methods' || location == '/help-center' || location == '/lawyer-availability' || location == '/lawyer-specialization-change' || location == '/lawyer-wallet') return 3;
      if (location == '/bookings' || location == '/booking-details' || location == '/manual-payment' || location == '/manual-payment-required' || location == '/upload-payment' || location == '/payment-result' || location == '/chats' || location.startsWith('/chat/')) return 1;
      return 0;
    }
    if (location == '/app-settings' || location == '/profile' || location == '/notification-settings' || location == '/payment-methods' || location == '/help-center') return 3;
    if (location == '/bookings' || location == '/booking-details' || location == '/manual-payment' || location == '/manual-payment-required' || location == '/upload-payment' || location == '/payment-result' || location == '/chats' || location.startsWith('/chat/')) return 2;
    if (location == '/lawyers' || location.startsWith('/lawyer-details/')) return 1;
    return 0;
  }

  bool _isPrimaryTab(bool isLawyer) {
    final location = widget.location;
    if (isLawyer) {
      return location == '/lawyer-home' ||
          location == '/bookings' ||
          location == '/lawyer-profile-edit' ||
          location == '/app-settings';
    }
    return location == '/home' ||
        location == '/lawyers' ||
        location == '/bookings' ||
        location == '/app-settings';
  }

  String _tabKey(bool isLawyer, int index) => '${isLawyer ? 'lawyer' : 'client'}-$index';

  Widget _buildCachedTabs(bool isLawyer, int selectedIndex) {
    final activeKey = _tabKey(isLawyer, selectedIndex);
    final activeChild = _cachedTabs[activeKey];
    if (activeChild == null) return widget.child;

    final layers = <Widget>[
      _CachedTabLayer(
        key: ValueKey<String>(activeKey),
        active: true,
        exitDx: 0,
        child: activeChild,
      ),
    ];

    for (var index = 0; index < 4; index++) {
      if (index == selectedIndex) continue;
      final key = _tabKey(isLawyer, index);
      final cached = _cachedTabs[key];
      if (cached == null) continue;
      layers.add(
        _CachedTabLayer(
          key: ValueKey<String>(key),
          active: false,
          exitDx: index < selectedIndex ? -.018 : .018,
          child: cached,
        ),
      );
    }

    return Stack(fit: StackFit.expand, children: layers);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(authStateChangesProvider).valueOrNull;
    final isLawyer = user?.role == 'lawyer';
    final roleKey = isLawyer ? 'lawyer' : 'client';

    if (_roleCacheKey != roleKey) {
      _roleCacheKey = roleKey;
      _cachedTabs.clear();
    }

    final selectedIndex = _currentIndex(isLawyer);
    final isPrimaryTab = _isPrimaryTab(isLawyer);
    if (isPrimaryTab) {
      _cachedTabs[_tabKey(isLawyer, selectedIndex)] = widget.child;
    }

    final hidesShellNav = user == null ||
        widget.location == '/create-booking' ||
        widget.location.startsWith('/lawyer-details/') ||
        widget.location == '/booking-details' ||
        widget.location == '/lawyer-availability' ||
        (isLawyer && widget.location == '/notifications');

    if (hidesShellNav) return widget.child;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: ColoredBox(
        color: scheme.surface,
        child: ClipRect(
          child: isPrimaryTab
              ? _buildCachedTabs(isLawyer, selectedIndex)
              : widget.child,
        ),
      ),
      bottomNavigationBar: MainBottomNav(
        currentIndex: selectedIndex,
        isLawyer: isLawyer,
      ),
    );
  }
}

class _CachedTabLayer extends StatelessWidget {
  final bool active;
  final double exitDx;
  final Widget child;

  const _CachedTabLayer({
    super.key,
    required this.active,
    required this.exitDx,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !active,
      child: ExcludeSemantics(
        excluding: !active,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          offset: active ? Offset.zero : Offset(exitDx, 0),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            opacity: active ? 1 : 0,
            child: RepaintBoundary(child: child),
          ),
        ),
      ),
    );
  }
}
