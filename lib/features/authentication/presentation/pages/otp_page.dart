import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/user_facing_error.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../providers/auth_provider.dart';

class OtpPage extends ConsumerStatefulWidget {
  final String phone;
  const OtpPage({super.key, required this.phone});

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage> {
  final _otpController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _otpController.text.trim();
    if (code.length != 6 || _submitting) return;
    setState(() => _submitting = true);
    try {
      await ref.read(authControllerProvider.notifier).verifyOTP(widget.phone, code);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(authControllerProvider);

    ref.listen<AsyncValue<void>>(authControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(UserFacingError.text(error, fallback: 'تعذر التحقق من الرمز. تحقق منه وحاول مرة أخرى.')),
              backgroundColor: scheme.error,
            ),
          );
        },
      );
    });

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => context.canPop() ? context.pop() : context.go('/login'),
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text('العودة'),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(26),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [scheme.primaryContainer, scheme.surfaceContainerHighest],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              width: 68,
                              height: 68,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                borderRadius: BorderRadius.circular(21),
                              ),
                              child: Icon(Icons.verified_user_rounded, size: 34, color: scheme.onPrimary),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            'أدخل رمز التحقق',
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900, color: scheme.onSurface),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'أرسلنا رمز تحقق مكوناً من 6 أرقام إلى الرقم التالي:',
                            textAlign: TextAlign.right,
                            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.6),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            widget.phone,
                            textAlign: TextAlign.right,
                            textDirection: TextDirection.ltr,
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: scheme.primary),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: scheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: scheme.outlineVariant),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: _otpController,
                                  autofocus: true,
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  textAlign: TextAlign.center,
                                  textDirection: TextDirection.ltr,
                                  decoration: InputDecoration(
                                    hintText: '000000',
                                    counterText: '',
                                    prefixIcon: const Icon(Icons.password_rounded),
                                    filled: true,
                                    fillColor: scheme.surfaceContainerLowest,
                                  ),
                                  style: TextStyle(
                                    fontSize: 28,
                                    letterSpacing: 10,
                                    fontWeight: FontWeight.w900,
                                    color: scheme.onSurface,
                                  ),
                                  onChanged: (value) {
                                    if (value.length == 6) _verify();
                                  },
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 52,
                                  child: FilledButton.icon(
                                    onPressed: state.isLoading || _submitting ? null : _verify,
                                    icon: state.isLoading || _submitting
                                        ? const SizedBox(width: 19, height: 19, child: CircularProgressIndicator(strokeWidth: 2))
                                        : const Icon(Icons.login_rounded),
                                    label: Text(
                                      state.isLoading || _submitting ? 'جارٍ التحقق...' : 'تأكيد ودخول',
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'لأمان حسابك، لا تشارك رمز التحقق مع أي شخص.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: state.isLoading || _submitting ? null : () => context.canPop() ? context.pop() : context.go('/login'),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('تغيير رقم الهاتف'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
