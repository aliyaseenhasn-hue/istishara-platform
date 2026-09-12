import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Compact access to the lawyer's secondary tools.
///
/// Appointment and consultation requests are intentionally handled together
/// on the lawyer dashboard. This menu contains only secondary tools.
class LawyerMoreMenuButton extends StatelessWidget {
  const LawyerMoreMenuButton({super.key});

  static const _actions = <_LawyerMenuAction>[
    _LawyerMenuAction(Icons.schedule_rounded, 'أوقات التوفر', '/lawyer-availability'),
    _LawyerMenuAction(Icons.account_balance_wallet_outlined, 'المحفظة', '/lawyer-wallet'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PopupMenuButton<_LawyerMenuAction>(
      tooltip: 'المزيد من أدوات المحامي',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      onSelected: (action) => context.push(action.route),
      itemBuilder: (context) => _actions
          .map(
            (action) => PopupMenuItem<_LawyerMenuAction>(
              value: action,
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer.withValues(alpha: .55),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(action.icon, size: 20, color: scheme.onSecondaryContainer),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      action.label,
                      textAlign: TextAlign.right,
                      style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
      child: Semantics(
        button: true,
        label: 'المزيد من أدوات المحامي',
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.secondaryContainer.withValues(alpha: .72),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.secondary.withValues(alpha: .24)),
          ),
          child: Icon(Icons.menu_rounded, size: 24, color: scheme.onSecondaryContainer),
        ),
      ),
    );
  }
}

class _LawyerMenuAction {
  final IconData icon;
  final String label;
  final String route;

  const _LawyerMenuAction(this.icon, this.label, this.route);
}
