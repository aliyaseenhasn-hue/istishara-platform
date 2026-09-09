import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ManualPaymentRequiredPage extends StatelessWidget {
  const ManualPaymentRequiredPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('الدفع')), 
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                elevation: 0,
                color: scheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 58,
                        color: scheme.primary,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'الدفع يتم عبر حساب المنصة',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'تم إيقاف مسار تسجيل المبلغ النقدي لدى المحامي. '
                        'لأي حجز يحتاج إلى دفع، افتح الاستشارة من قائمة حجوزاتك ثم اختر «إكمال الدفع»، '
                        'وحول المبلغ إلى حساب المنصة وارفع الإيصال ليتم التحقق منه من الإدارة.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          height: 1.6,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => context.go('/bookings'),
                          icon: const Icon(Icons.event_note_outlined),
                          label: const Text('الذهاب إلى الاستشارات'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
