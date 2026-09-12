import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/legal_specializations.dart';
import '../providers/lawyers_provider.dart';

class LegalCategoriesPage extends ConsumerWidget {
  const LegalCategoriesPage({super.key});

  IconData _iconFor(String category) {
    if (category == LegalSpecializations.uncertainClientChoice) return Icons.help_outline_rounded;
    final value = category.toLowerCase();
    if (value.contains('شركات')) return Icons.business_center_rounded;
    if (value.contains('عقاري') || value.contains('عقار')) return Icons.home_work_rounded;
    if (value.contains('جنائي')) return Icons.gavel_rounded;
    if (value.contains('أحوال') || value.contains('اسرة')) return Icons.family_restroom_rounded;
    if (value.contains('عمال')) return Icons.engineering_rounded;
    if (value.contains('إداري') || value.contains('اداري')) return Icons.account_balance_rounded;
    if (value.contains('مرور')) return Icons.directions_car_rounded;
    return Icons.balance_rounded;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final categories = LegalSpecializations.clientChoices;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('الفئات'),
        centerTitle: true,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_forward_rounded)),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.22,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            final uncertain = category == LegalSpecializations.uncertainClientChoice;
            final icon = _iconFor(category);
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () {
                  ref.read(selectedCategoryProvider.notifier).setCategory(uncertain ? null : category);
                  context.push('/lawyers');
                },
                child: Ink(
                  decoration: BoxDecoration(
                    color: dark ? scheme.surfaceContainerHighest.withValues(alpha: .72) : scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: uncertain ? scheme.primary.withValues(alpha: .45) : scheme.outlineVariant.withValues(alpha: .75),
                    ),
                    boxShadow: dark ? null : [BoxShadow(color: scheme.shadow.withValues(alpha: .045), blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 11),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: dark ? scheme.primary.withValues(alpha: .14) : scheme.primaryContainer.withValues(alpha: .65),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: scheme.primary, size: 26),
                      ),
                      const SizedBox(height: 11),
                      Text(
                        category,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        uncertain ? 'اعرض كل المحامين' : 'اختر التخصص',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 10.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
