import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  final bool isAdminLogin;
  const LoginPage({super.key, this.isAdminLogin = false});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  Timer? _timer;
  String? _token;
  String? _telegramUrl;
  bool _busy = false;
  bool _checking = false;
  bool _telegramReady = false;
  bool _redirectingToSignup = false;
  ValueNotifier<bool>? _telegramReadyNotifier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _telegramReadyNotifier?.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _token != null) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _pollTelegramStatus();
      });
    }
  }

  String _digits(String v) => v
      .replaceAllMapped(RegExp(r'[٠-٩]'), (m) => '٠١٢٣٤٥٦٧٨٩'.indexOf(m.group(0)!).toString())
      .replaceAllMapped(RegExp(r'[۰-۹]'), (m) => '۰۱۲۳۴۵۶۷۸۹'.indexOf(m.group(0)!).toString());

  String _normalizedPhone() {
    var p = _digits(_phone.text).replaceAll(RegExp(r'\s+'), '').replaceAll(RegExp(r'[()\-]'), '');
    if (p.startsWith('+964')) p = p.substring(4);
    if (p.startsWith('00964')) p = p.substring(5);
    if (p.startsWith('964')) p = p.substring(3);
    if (p.startsWith('0')) p = p.substring(1);
    return '964$p';
  }

  void _error(Object e) {
    if (!mounted) return;
    var message = e.toString().replaceFirst('Exception: ', '').trim();
    if (message.isEmpty) message = 'حدث خطأ غير متوقع أثناء تسجيل الدخول.';
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      duration: const Duration(seconds: 7),
      backgroundColor: Theme.of(context).colorScheme.error,
      showCloseIcon: true,
      closeIconColor: Theme.of(context).colorScheme.onError,
      content: Directionality(
        textDirection: TextDirection.rtl,
        child: Text(message, textAlign: TextAlign.right, maxLines: 5, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Theme.of(context).colorScheme.onError, fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    ));
  }

  Uri? _telegramAppUri() {
    final url = _telegramUrl;
    final token = _token;
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

  Future<void> _openTelegram() async {
    final appUri = _telegramAppUri();
    if (appUri == null) {
      _error(Exception('رابط Telegram غير صالح. ابدأ محاولة جديدة.'));
      return;
    }
    try {
      final ok = await launchUrl(appUri, mode: LaunchMode.externalApplication);
      if (!ok) {
        throw Exception('تعذر فتح تطبيق Telegram مباشرة. تأكد من تثبيت Telegram ثم حاول مرة أخرى.');
      }
    } catch (e) {
      _error(e);
    }
  }

  Future<void> _start() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _telegramReady = false;
      _redirectingToSignup = false;
      _checking = false;
    });
    _telegramReadyNotifier?.dispose();
    _telegramReadyNotifier = ValueNotifier<bool>(false);
    try {
      final d = await ref.read(authControllerProvider.notifier).startTelegramLogin(_normalizedPhone());
      _token = d['request_token'] as String?;
      _telegramUrl = d['telegram_url'] as String?;
      if (_token == null || _token!.isEmpty || _telegramUrl == null || _telegramUrl!.isEmpty) {
        throw Exception('تعذر إنشاء طلب Telegram. حاول مرة أخرى.');
      }
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(milliseconds: 900), (_) => _pollTelegramStatus());
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => ValueListenableBuilder<bool>(
          valueListenable: _telegramReadyNotifier!,
          builder: (context, ready, _) => AlertDialog(
            title: const Text('تسجيل الدخول عبر Telegram', textAlign: TextAlign.right),
            content: Directionality(
              textDirection: TextDirection.rtl,
              child: Text(ready
                  ? 'تم التحقق من رقم الهاتف. جارٍ تحديد الحساب المرتبط به.'
                  : 'افتح Telegram واضغط «بدء» ثم اختر «مشاركة رقم الهاتف». بعد نجاح التحقق سيحدد النظام الحساب المرتبط تلقائياً.'),
            ),
            actions: [
              TextButton(
                onPressed: _checking || _redirectingToSignup ? null : () {
                  _cancelTelegram();
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('إلغاء'),
              ),
              FilledButton.icon(
                onPressed: _checking || _redirectingToSignup ? null : _openTelegram,
                icon: const Icon(Icons.telegram),
                label: const Text('فتح Telegram'),
              ),
              FilledButton(
                onPressed: _checking || _redirectingToSignup ? null : () => _completeTelegram(dialogContext),
                child: Text(_checking ? 'جارٍ الدخول...' : 'متابعة'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) _error(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Map<String, dynamic>?> _fetchTelegramStatus() async {
    final token = _token;
    if (token == null || token.isEmpty) return null;
    final r = await Supabase.instance.client.functions.invoke('telegram-auth-v2', body: {'action': 'status', 'request_token': token});
    if (r.data is! Map) return null;
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<void> _pollTelegramStatus() async {
    final token = _token;
    if (token == null || token.isEmpty || _checking || _redirectingToSignup) return;
    try {
      final data = await _fetchTelegramStatus();
      if (data == null) return;
      await _handleTelegramStatus(data);
    } catch (_) {}
  }

  Future<void> _handleTelegramStatus(Map<String, dynamic> data) async {
    final status = data['status']?.toString();
    if (status == 'telegram_verified') {
      final mode = data['mode']?.toString();
      final verifiedProfileId = data['verified_profile_id']?.toString();
      if (mode == 'login' && (verifiedProfileId == null || verifiedProfileId.isEmpty || verifiedProfileId == 'null')) {
        _redirectingToSignup = true;
        _timer?.cancel();
        _timer = null;
        if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
        _token = null;
        _telegramUrl = null;
        if (mounted) context.go('/signup');
        return;
      }
      if (mounted) {
        setState(() => _telegramReady = true);
        _telegramReadyNotifier?.value = true;
      }
      return;
    }
    if (status == 'expired') {
      _cancelTelegram();
      if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
      if (mounted) _error(Exception('انتهت صلاحية طلب Telegram. حاول مرة أخرى.'));
    }
  }

  Future<bool> _waitForTelegramVerification() async {
    for (var attempt = 0; attempt < 8; attempt++) {
      if (!mounted || _token == null || _token!.isEmpty) return false;
      try {
        final data = await _fetchTelegramStatus();
        if (data == null) return false;
        final status = data['status']?.toString();
        if (status == 'telegram_verified') {
          await _handleTelegramStatus(data);
          return _telegramReady;
        }
        if (status == 'expired') {
          await _handleTelegramStatus(data);
          return false;
        }
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
    return _telegramReady;
  }

  Future<void> _completeTelegram(BuildContext dialogContext) async {
    final token = _token;
    if (token == null || token.isEmpty || _checking || _redirectingToSignup) return;
    setState(() => _checking = true);
    final verified = await _waitForTelegramVerification();
    if (!mounted || _redirectingToSignup || _token == null || _token!.isEmpty) return;
    if (!verified) {
      setState(() => _checking = false);
      _error(Exception('لم يكتمل التحقق من Telegram بعد. تأكد من الضغط على «مشاركة رقم الهاتف» داخل Telegram، ثم حاول «متابعة» مرة أخرى.'));
      return;
    }
    try {
      await ref.read(authControllerProvider.notifier).verifyTelegramLogin(requestToken: _token!, code: '');
      final client = Supabase.instance.client;
      if (client.auth.currentSession == null || client.auth.currentUser == null) {
        throw Exception('تم التحقق من Telegram لكن لم يتم تثبيت جلسة الدخول.');
      }
      await ref.read(authRepositoryProvider).refreshUser();
      _timer?.cancel();
      _timer = null;
      _token = null;
      _telegramUrl = null;
      _telegramReady = false;
      _telegramReadyNotifier?.value = false;
      if (!mounted) return;
      Navigator.of(dialogContext).pop();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (mounted) context.go('/profile');
    } catch (e) {
      if (!mounted) return;
      setState(() => _checking = false);
      _error(e);
    }
  }

  void _cancelTelegram() {
    _timer?.cancel();
    _timer = null;
    _token = null;
    _telegramUrl = null;
    if (mounted) {
      setState(() {
        _checking = false;
        _telegramReady = false;
        _redirectingToSignup = false;
      });
    } else {
      _checking = false;
      _telegramReady = false;
      _redirectingToSignup = false;
    }
    _telegramReadyNotifier?.value = false;
  }

  Future<void> _google() async {
    try {
      await ref.read(authControllerProvider.notifier).signInWithGoogle();
    } catch (e) {
      if (mounted) _error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Form(
                  key: _formKey,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () => context.canPop() ? context.pop() : context.go('/'), icon: const Icon(Icons.arrow_forward_rounded), label: const Text('العودة'))),
                          const SizedBox(height: 12),
                          Align(alignment: Alignment.center, child: Icon(Icons.balance_rounded, size: 54, color: AppColors.primary)),
                          const SizedBox(height: 14),
                          Text(widget.isAdminLogin ? 'دخول الإدارة' : 'تسجيل الدخول', textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          const Text('أدخل رقم هاتفك العراقي لإتمام الدخول بأمان عبر Telegram.', textAlign: TextAlign.center),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            textDirection: TextDirection.ltr,
                            decoration: const InputDecoration(labelText: 'رقم الهاتف العراقي', hintText: '07xxxxxxxxx أو ٠٧xxxxxxxxx', prefixIcon: Icon(Icons.phone_android_rounded)),
                            validator: (v) {
                              final p = _digits(v ?? '').replaceAll(RegExp(r'\s+'), '');
                              final d = p.replaceFirst(RegExp(r'^\+964|^00964|^964|^0'), '');
                              return RegExp(r'^7\d{9}$').hasMatch(d) ? null : 'أدخل رقم هاتف عراقي صحيح مثل 07701234567';
                            },
                          ),
                          const SizedBox(height: 16),
                          SizedBox(height: 52, child: ElevatedButton.icon(onPressed: (_busy || auth.isLoading) ? null : _start, icon: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded), label: Text(_busy ? 'جارٍ تجهيز Telegram...' : 'تسجيل الدخول عبر Telegram'))),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(onPressed: auth.isLoading ? null : _google, icon: const Icon(Icons.account_circle_outlined), label: const Text('المتابعة باستخدام Google')),
                          const SizedBox(height: 16),
                          TextButton(onPressed: () => context.go('/signup'), child: const Text('ليس لديك حساب؟ إنشاء حساب جديد')),
                        ],
                      ),
                    ),
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