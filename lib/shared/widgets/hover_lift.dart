import 'package:flutter/material.dart';

/// Subtle desktop/web hover and keyboard-focus motion for card surfaces.
/// It is intentionally presentation-only and has no effect on tap behavior.
class HoverLift extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final double lift;
  final double scale;

  const HoverLift({
    super.key,
    required this.child,
    this.borderRadius = 18,
    this.lift = 3,
    this.scale = 1.012,
  });

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = _hovered || _focused;

    return FocusableActionDetector(
      onShowFocusHighlight: (value) {
        if (_focused != value) setState(() => _focused = value);
      },
      child: MouseRegion(
        onEnter: (_) {
          if (!_hovered) setState(() => _hovered = true);
        },
        onExit: (_) {
          if (_hovered) setState(() => _hovered = false);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, active ? -widget.lift : 0, 0),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: .13),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : const [],
          ),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            scale: active ? widget.scale : 1,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
