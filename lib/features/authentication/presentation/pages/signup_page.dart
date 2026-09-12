import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';

class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});
  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> with WidgetsBindingObserver {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _selectedRole = 'user';
  bool _telegramStarting = false;
  bool _telegramChecking = false;
  bool _telegramReady = false;
  bool _telegramDialogOpen = false;
  bool _telegramAutoCompleting = false;
  String? _telegramToken;
  String? _telegramUrl;
  Timer? _telegramTimer;
  ValueNotifier<bool>? _telegramReadyNotifier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _telegramTimer?.cancel();
    _telegramReadyNotifier?.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _telegramToken != null) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _pollTelegramStatus();
      });
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    var message = error.toString().replaceFirst('Exception: ', '').trim();
    if (message.isEmpty) message = 'حدث خطأ غير متوقع أثناء إنشاء الحساب.';
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        duration: const Duration(seconds: 7),
        backgroundColor: Theme.of(context).colorScheme.error,
        showCloseIcon: true,
        closeIconColor: Theme.of(context).colorScheme.onError,
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: Text(
            message,
            textAlign: TextAlign.right,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onError,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  String _normalizePhone() {
    var phone = _phoneController.text.trim().replaceAll(RegExp(r'\s+'), '');
    if (phone.startsWith('+964')) phone = phone.substring(4);
    if (phone.startsWith('00964')) phone = phone.substring(5);
    if (phone.startsWith('964')) phone = phone.substring(3);
    if (phone.startsWith('0')) phone = phone.substring(1);
    return '964$phone';
  }

  Uri? _telegramAppUri() {
    final url = _telegramUrl;
    final token = _telegramToken;
    if (url == null || url.isEmpty || token == null || token.isEmpty) return null;
    final webUri = Uri.tryParse(url);
    if (webUri == null || webUri.host != 't.me' || webUri.pathSegments.isEmpty) return null;
    final username = webUri.pathSegments.first.trim();
    final start = webUri.queryParameters['start'];
    if (username.isEmpty || start == null || start.isEmpty || start != token) return null;
    return Uri(
      scheme: 'tg',
      host: 'resolve',
      queryParameters: {'domain': username, 'start': token},
    );
  }

  Future<void> _openTelegramApp() async {
    final appUri = _telegramAppUri();
    if (appUri == null) {
      _showError(Exception('رابط Telegram غير صالح. ابدأ محاولة جديدة.'));
      return;
    }
    try {
      final opened = await launchUrl(appUri, mode: LaunchMode.externalApplication);
      if (!opened) {
        throw Exception('تعذر فتح تطبيق Telegram مباشرة. تأكد من تثبيت Telegram ثم حاول مرة أخرى.');
      }
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _googleSignup() async {
    try {
      await ref.read(authControllerProvider.notifier).signInWithGoogle();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _startPhoneSignup() async {
    if (_telegramStarting || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _telegramStarting = true;
      _telegramReady = false;
    });
    _telegramReadyNotifier?.dispose();
    _telegramReadyNotifier = ValueNotifier<bool>(false);
    try {
      final data = await ref.read(authControllerProvider.notifier).startTelegramLogin(
        _normalizePhone(),
        registration: true,
        fullName: _nameController.text.trim(),
        role: _selectedRole,
      );
      final token = data['request_token'] as String?;
      final url = data['telegram_url'] as String?;
      if (token == null || token.isEmpty || url == null || url.isEmpty) {
        throw Exception('تعذر إنشاء طلب Telegram. حاول مرة أخرى.');
      }
      _telegramToken = token;
      _telegramUrl = url;
      _telegramTimer?.cancel();
      _telegramTimer = Timer.periodic(const Duration(seconds: 1), (_) => _pollTelegramStatus());
      await _openTelegramApp();
      if (mounted) await _showTelegramDialog();
    } catch (e) {
      _cancelTelegram();
      _showError(e);
    } finally {
      if (mounted) setState(() => _telegramStarting = false);
    }
  }

  Future<void> _pollTelegramStatus() async {
    final token = _telegramToken;
    if (token == null || token.isEmpty || _telegramChecking || _telegramReady || _telegramAutoCompleting) return;
    try {
      final result = await Supabase.instance.client.functions.invoke(
        'telegram-auth-v2',
        body: {'action': 'status', 'request_token': token},
      );
      if (result.data is! Map) return;
      final data = Map<String, dynamic>.from(result.data as Map);
      final status = data['status']?.toString();
      if (status == 'telegram_verified') {
        if (!mounted) return;
        setState(() => _telegramReady = true);
        _telegramReadyNotifier?.value = true;
        if (_telegramDialogOpen && !_telegramAutoCompleting) {
          _telegramAutoCompleting = true;
          await _completeTelegram(context);
        }
      } else if (status == 'expired') {
        _cancelTelegram();
        if (mounted && _telegramDialogOpen && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        _showError(Exception('انتهت صلاحية طلب Telegram. حاول مرة أخرى.'));
      }
    } catch (_) {}
  }

  Future<void> _showTelegramDialog() async {
    final notifier = _telegramReadyNotifier;
    if (notifier == null) return;
    _telegramDialogOpen = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => ValueListenableBuilder<bool>(
          valueListenable: notifier,
          builder: (context, ready, _) => AlertDialog(
            title: const Text('تأكيد رقم الهاتف', textAlign: TextAlign.right),
            content: Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                ready
                    ? 'تم التحقق من رقم الهاتف بنجاح. جارٍ إنشاء الحساب تلقائياً...'
                    : 'افتح Telegram واضغط «بدء» ثم اختر «مشاركة رقم الهاتف». بعد نجاح التحقق سيتم إنشاء الحساب وتحويلك تلقائياً إلى ملفك الشخصي.',
                textAlign: TextAlign.right,
              ),
            ),
            actions: [
              TextButton(
                onPressed: _telegramChecking || _telegramAutoCompleting ? null : () {
                  _cancelTelegram();
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('إلغاء'),
              ),
              if (!ready)
                FilledButton.icon(
                  onPressed: _telegramChecking || _telegramAutoCompleting || _telegramUrl == null ? null : _openTelegramApp,
                  icon: const Icon(Icons.telegram),
                  label: const Text('فتح Telegram'),
                ),
              if (!ready)
                FilledButton(
                  onPressed: _telegramChecking || _telegramAutoCompleting ? null : () => _continueTelegram(dialogContext),
                  child: const Text('متابعة'),
                ),
            ],
          ),
        ),
      );
    } finally {
      _telegramDialogOpen = false;
    }
  }

  Future<void> _continueTelegram(BuildContext dialogContext) async {
    if (_telegramChecking || _telegramAutoCompleting) return;
    await _pollTelegramStatus();
    if (!mounted || !_telegramReady) {
      _showError(Exception('لم يكتمل التحقق من Telegram بعد. أكمل مشاركة رقم الهاتف ثم انتظر لحظات.'));
      return;
    }
    await _completeTelegram(dialogContext);
  }

  Future<void> _completeTelegram(BuildContext dialogContext) async {
    final token = _telegramToken;
    if (token == null || token.isEmpty || _telegramChecking || !_telegramReady) return;
    setState(() => _telegramChecking = true);
    try {
      await ref.read(authControllerProvider.notifier).verifyTelegramLogin(
        requestToken: token,
        code: '',
      );
      final client = Supabase.instance.client;
      if (client.auth.currentSession == null || client.auth.currentUser == null) {
        throw Exception('تم التحقق من Telegram لكن لم يتم تثبيت جلسة الدخول.');
      }
      await ref.read(authRepositoryProvider).refreshUser();
      _cancelTelegram();
      if (!mounted) return;
      if (dialogContext.mounted && Navigator.of(dialogContext).canPop()) {
        Navigator.of(dialogContext).pop();
      }
      if (!mounted) return;
      context.go('/profile');
    } catch (e) {
      if (!mounted) return;
      _telegramAutoCompleting = false;
      setState(() => _telegramChecking = false);
      _showError(e);
    }
  }

  void _cancelTelegram() {
    _telegramTimer?.cancel();
    _telegramTimer = null;
    _telegramToken = null;
    _telegramUrl = null;
    _telegramChecking = false;
    _telegramReady = false;
    _telegramAutoCompleting = false;
    _telegramReadyNotifier?.value = false;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final form = _SignupForm(
                      formKey: _formKey,
                      nameController: _nameController,
                      phoneController: _phoneController,
                      selectedRole: _selectedRole,
                      loading: _telegramStarting || auth.isLoading,
                      onRoleChanged: (role) => setState(() => _selectedRole = role),
                      onPhoneSignup: _startPhoneSignup,
                      onGoogle: _googleSignup,
                    );
                    if (constraints.maxWidth >= 900) {
                      return Row(children: [const Expanded(child: _SignupBrand()), const SizedBox(width: 44), SizedBox(width: 480, child: form)]);
                    }
                    return form;
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignupBrand extends StatelessWidget {
  const _SignupBrand();
  @override
  Widget build(BuildContext context) => const Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
    Icon(Icons.balance_rounded, size: 58),
    SizedBox(height: 20),
    Text('أنشئ حسابك في استشارة', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
    SizedBox(height: 10),
    Text('سجّل باستخدام رقم هاتفك عبر Telegram أو حساب Google.'),
  ]);
}

class _SignupForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final String selectedRole;
  final bool loading;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onPhoneSignup;
  final VoidCallback onGoogle;

  const _SignupForm({required this.formKey, required this.nameController, required this.phoneController, required this.selectedRole, required this.loading, required this.onRoleChanged, required this.onPhoneSignup, required this.onGoogle});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Form(key: formKey, child: Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('إنشاء حساب', textAlign: TextAlign.right, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
      const SizedBox(height: 20),
      TextFormField(controller: nameController, decoration: const InputDecoration(labelText: 'الاسم الكامل', prefixIcon: Icon(Icons.person_outline_rounded)), validator: (v) => v == null || v.trim().length < 3 ? 'أدخل الاسم الكامل' : null),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: _RoleCard(title: 'طالب استشارة', subtitle: 'أبحث عن مساعدة قانونية', icon: Icons.person_search_outlined, selected: selectedRole == 'user', onTap: () => onRoleChanged('user'))),
        const SizedBox(width: 10),
        Expanded(child: _RoleCard(title: 'محامي', subtitle: 'أقدم خدمات قانونية', icon: Icons.gavel_rounded, selected: selectedRole == 'lawyer', onTap: () => onRoleChanged('lawyer'))),
      ]),
      const SizedBox(height: 16),
      TextFormField(controller: phoneController, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'رقم الهاتف العراقي', hintText: '07xxxxxxxxx', prefixIcon: Icon(Icons.phone_android_rounded)), validator: (v) {
        final value = v?.replaceAll(RegExp(r'\s+'), '') ?? '';
        return RegExp(r'^(?:\+?964|0)?7\d{9}$').hasMatch(value) ? null : 'أدخل رقم هاتف عراقي صحيح';
      }),
      const SizedBox(height: 16),
      SizedBox(height: 52, child: ElevatedButton.icon(onPressed: loading ? null : onPhoneSignup, icon: loading ? const SizedBox(width: 19, height: 19, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded), label: Text(loading ? 'جارٍ تجهيز التسجيل...' : 'التسجيل برقم الهاتف عبر Telegram'))),
      const SizedBox(height: 14),
      OutlinedButton.icon(onPressed: loading ? null : onGoogle, icon: const Icon(Icons.account_circle_outlined), label: const Text('المتابعة باستخدام Google')),
      const SizedBox(height: 12),
      TextButton(onPressed: loading ? null : () => context.go('/login'), child: const Text('لديك حساب بالفعل؟ تسجيل الدخول')),
      Text('بالمتابعة، أنت توافق على شروط الاستخدام وسياسة الخصوصية.', textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, color: s.onSurfaceVariant)),
    ]))));
  }
}

class _RoleCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _RoleCard({required this.title, required this.subtitle, required this.icon, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Container(padding: const EdgeInsets.all(12), constraints: const BoxConstraints(minHeight: 105), decoration: BoxDecoration(color: selected ? s.primaryContainer : s.surfaceContainerLowest, borderRadius: BorderRadius.circular(16), border: Border.all(color: selected ? s.primary : s.outlineVariant, width: selected ? 1.6 : 1)), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Icon(icon, color: selected ? s.onPrimaryContainer : s.onSurfaceVariant), const Spacer(), Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: selected ? s.onPrimaryContainer : s.onSurface)), const SizedBox(height: 3), Text(subtitle, textAlign: TextAlign.right, style: TextStyle(fontSize: 9.5, color: selected ? s.onPrimaryContainer.withValues(alpha: .78) : s.onSurfaceVariant))]))));
  }
}