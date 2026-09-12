import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';

/// الشريط السفلي الثابت.
/// تبقى الوجهات الأساسية فقط هنا؛ أدوات المحامي الثانوية متاحة من رأس الرئيسية.
class MainBottomNav extends ConsumerStatefulWidget {
  final int currentIndex;
  final bool isLawyer;

  const MainBottomNav({
    super.key,
    required this.currentIndex,
    this.isLawyer = false,
  });

  @override
  ConsumerState<MainBottomNav> createState() => _MainBottomNavState();
}

class _MainBottomNavState extends ConsumerState<MainBottomNav> {
  static const _clientItems = <_NavItem>[
    _NavItem(Icons.home_outlined, Icons.home_rounded, 'الرئيسية'),
    _NavItem(Icons.people_outline_rounded, Icons.people_rounded, 'المحامون'),
    _NavItem(Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'استشاراتي'),
    _NavItem(Icons.settings_outlined, Icons.settings_rounded, 'الإعدادات'),
  ];

  static const _lawyerItems = <_NavItem>[
    _NavItem(Icons.home_outlined, Icons.home_rounded, 'الرئيسية'),
    _NavItem(Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'استشاراتي'),
    _NavItem(Icons.badge_outlined, Icons.badge_rounded, 'الملف المهني'),
    _NavItem(Icons.settings_outlined, Icons.settings_rounded, 'الإعدادات'),
  ];

  late int _visualIndex;

  @override
  void initState() {
    super.initState();
    _visualIndex = widget.currentIndex;
  }

  @override
  void didUpdateWidget(covariant MainBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex ||
        oldWidget.isLawyer != widget.isLawyer) {
      _visualIndex = widget.currentIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.isLawyer ? _lawyerItems : _clientItems;
    final selectedIndex = _visualIndex.clamp(0, items.length - 1).toInt();
    final direction = Directionality.of(context);

    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: .24),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withValues(alpha: .10),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.all(5),
          child: Row(
            textDirection: direction,
            children: List.generate(
              items.length,
              (index) => Expanded(
                child: _NavDestination(
                  item: items[index],
                  selected: index == selectedIndex,
                  onTap: () => _navigate(context, index),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigate(BuildContext context, int index) {
    if (_visualIndex != index) {
      setState(() => _visualIndex = index);
    }

    final target = widget.isLawyer
        ? switch (index) {
            0 => '/lawyer-home',
            1 => '/bookings',
            2 => '/lawyer-profile-edit',
            3 => '/app-settings',
            _ => '/lawyer-home',
          }
        : switch (index) {
            0 => '/home',
            1 => '/lawyers',
            2 => '/bookings',
            3 => '/app-settings',
            _ => '/home',
          };

    if (GoRouterState.of(context).uri.path != target) {
      context.go(target);
    }
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem(this.icon, this.activeIcon, this.label);
}

class _NavDestination extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavDestination({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = selected ? Colors.white : AppColors.textSecondary;
    final textColor = selected ? AppColors.primaryDark : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            onTap: onTap,
            splashFactory: NoSplash.splashFactory,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            focusColor: AppColors.primary.withValues(alpha: .05),
            borderRadius: BorderRadius.circular(15),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 125),
              curve: Curves.easeOutCubic,
              constraints: const BoxConstraints(minHeight: 50),
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primaryFixed
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: selected
                      ? AppColors.primary.withValues(alpha: .18)
                      : Colors.transparent,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedScale(
                    duration: const Duration(milliseconds: 125),
                    curve: Curves.easeOutCubic,
                    scale: selected ? 1.04 : 1,
                    child: Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        selected ? item.activeIcon : item.icon,
                        color: iconColor,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 125),
                    curve: Curves.easeOutCubic,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 10.5,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                      height: 1.1,
                    ),
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
