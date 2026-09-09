import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';

/// الشريط السفلي الثابت.
/// تبقى الوجهات الأساسية فقط هنا؛ أدوات المحامي الثانوية متاحة من رأس الرئيسية.
class MainBottomNav extends ConsumerWidget {
  final int currentIndex;
  final bool isLawyer;

  const MainBottomNav({super.key, required this.currentIndex, this.isLawyer = false});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = isLawyer ? _lawyerItems : _clientItems;
    final selectedIndex = currentIndex.clamp(0, items.length - 1).toInt();
    final direction = Directionality.of(context);

    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(12, 5, 12, 8),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(27),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: .24),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withValues(alpha: .10),
                blurRadius: 24,
                spreadRadius: 1,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(7),
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
    final target = isLawyer
        ? switch (index) {
            0 => '/lawyer-home',
            1 => '/bookings',
            2 => '/lawyer-profile-edit',
            3 => '/app-settings',
            _ => '/lawyer-home',
          }
        : switch (index) {
            0 => '/',
            1 => '/lawyers',
            2 => '/bookings',
            3 => '/app-settings',
            _ => '/',
          };
    if (GoRouterState.of(context).uri.path != target) context.go(target);
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
    final iconColor = selected ? Colors.white : AppColors.primaryDark;
    final textColor = selected ? Colors.white : AppColors.textPrimary;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onTap,
            hoverColor: AppColors.primary.withValues(alpha: .06),
            focusColor: AppColors.primary.withValues(alpha: .08),
            splashColor: AppColors.primary.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              constraints: const BoxConstraints(minHeight: 60),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.primaryDark, AppColors.primary],
                      )
                    : null,
                color: selected ? null : AppColors.primaryFixed.withValues(alpha: .82),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? AppColors.gold.withValues(alpha: .78)
                      : AppColors.primaryLight.withValues(alpha: .30),
                  width: selected ? 1.4 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: .22),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: selected ? 31 : 29,
                    height: selected ? 31 : 29,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withValues(alpha: .14)
                          : AppColors.surface.withValues(alpha: .88),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? Colors.white.withValues(alpha: .20)
                            : AppColors.primaryLight.withValues(alpha: .25),
                      ),
                    ),
                    child: Icon(
                      selected ? item.activeIcon : item.icon,
                      color: iconColor,
                      size: selected ? 23 : 22,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 11.5,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                      height: 1.1,
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
