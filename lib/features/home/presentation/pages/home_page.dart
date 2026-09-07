class _EmptyState extends StatelessWidget {
  final IconData icon; final String text;
  const _EmptyState({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 20), child: Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: scheme.surfaceContainerLowest, borderRadius: BorderRadius.circular(16), border: Border.all(color: scheme.outlineVariant)), child: Column(children: [Icon(icon, color: scheme.onSurfaceVariant, size: 28), const SizedBox(height: 7), Text(text, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant))])));
  }
}

class _NotificationBell extends StatelessWidget {
  final int unreadCount; final VoidCallback onTap;
  const _NotificationBell({required this.unreadCount, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(button: true, label: 'التنبيهات', child: Material(color: scheme.surfaceContainerLowest, shape: const CircleBorder(), child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: SizedBox(width: 44, height: 44, child: Stack(alignment: Alignment.center, children: [
      Icon(Icons.notifications_none_rounded, color: scheme.onSurface, size: 24),
      if (unreadCount > 0) Positioned(top: 2, right: 1, child: Container(constraints: const BoxConstraints(minWidth: 18, minHeight: 18), padding: const EdgeInsets.symmetric(horizontal: 4), alignment: Alignment.center, decoration: BoxDecoration(color: scheme.error, borderRadius: BorderRadius.circular(99), border: Border.all(color: scheme.surfaceContainerLowest, width: 1.5)), child: Text(unreadCount > 99 ? '99+' : '$unreadCount', style: TextStyle(color: scheme.onError, fontSize: 8, fontWeight: FontWeight.w900)))),
    ])))));
  }
}