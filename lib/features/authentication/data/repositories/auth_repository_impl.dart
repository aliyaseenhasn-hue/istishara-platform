import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/config/supabase_config.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient _supabase;
  final _userStateController = StreamController<AppUser?>.broadcast();
  late final StreamSubscription<AuthState> _authSubscription;

  AuthRepositoryImpl([SupabaseClient? client]) : _supabase = client ?? SupabaseConfig.client {
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) async {
      try {
        final sessionUser = data.session?.user;
        if (sessionUser == null) {
          _userStateController.add(null);
          return;
        }
        final profile = await _supabase.from('profiles').select().eq('auth_id', sessionUser.id).maybeSingle();
        if (profile == null && await _isCurrentAccountClosed()) {
          _userStateController.add(null);
          return;
        }
        final lawyerProfile = profile?['role']?.toString() == 'lawyer'
            ? await _supabase.from('lawyer_profiles').select('verified').eq('profile_id', profile?['id']).maybeSingle()
            : null;
        _userStateController.add(_toAppUser(sessionUser, profile, lawyerProfile));
      } catch (e) {
        debugPrint('Auth state profile sync failed: $e');
      }
    }, onError: (Object e, StackTrace st) {
      debugPrint('Auth state stream error: $e');
    });
    Future.microtask(refreshUser);
  }

  Future<bool> _isCurrentAccountClosed() async {
    try {
      final result = await _supabase.rpc('is_my_account_closed');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  Exception _friendlyNetworkError(Object error) {
    final text = error.toString().toLowerCase();
    const networkHints = ['socketexception','failed host lookup','network is unreachable','network request failed','networkerror','failed to fetch','xmlhttprequest','connection reset','connection refused','connection closed','connection timed out','timed out','timeout','clientexception','no internet','internet connection'];
    if (networkHints.any(text.contains)) return Exception('تعذر إكمال العملية بسبب انقطاع الاتصال بالإنترنت. تحقق من اتصالك بالإنترنت وحاول مرة أخرى.');
    if (error is AuthException) return Exception(error.message);
    if (error is FunctionException) {
      final details = error.details;
      if (details is Map) {
        final message = details['error']?.toString().trim();
        if (message != null && message.isNotEmpty) return Exception(message);
        final messageAlt = details['message']?.toString().trim();
        if (messageAlt != null && messageAlt.isNotEmpty) return Exception(messageAlt);
      }
      final detailText = details?.toString().trim();
      if (detailText != null && detailText.isNotEmpty && detailText != 'null') return Exception(detailText);
      return Exception(error.reasonPhrase ?? 'تعذر الاتصال بالخدمة. تحقق من اتصالك بالإنترنت وحاول مرة أخرى.');
    }
    return Exception(error.toString().replaceFirst('Exception: ', ''));
  }

  AppUser _toAppUser(User user, Map<String, dynamic>? profile, [Map<String, dynamic>? lawyerProfile]) {
    final lawyerVerified = profile?['role']?.toString() == 'lawyer' && lawyerProfile?['verified'] == true;
    return AppUser(
      id: user.id,
      email: profile?['email']?.toString() ?? user.email,
      fullName: profile?['full_name']?.toString() ?? user.userMetadata?['full_name']?.toString(),
      phone: profile?['phone']?.toString() ?? user.phone,
      avatarUrl: profile?['avatar_url']?.toString(),
      role: profile?['role']?.toString() ?? user.userMetadata?['role']?.toString() ?? 'user',
      isVerified: lawyerVerified || profile?['is_verified'] == true,
      hasProfessionalProfile: profile?['has_professional_profile'] == true,
      isOnboardingComplete: profile?['onboarding_completed'] == true,
      walletNumber: profile?['wallet_number']?.toString(),
    );
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;
      final profile = await _supabase.from('profiles').select().eq('auth_id', user.id).maybeSingle();
      if (profile == null && await _isCurrentAccountClosed()) return null;
      final lawyerProfile = profile?['role']?.toString() == 'lawyer'
          ? await _supabase.from('lawyer_profiles').select('verified').eq('profile_id', profile?['id']).maybeSingle()
          : null;
      return _toAppUser(user, profile, lawyerProfile);
    } catch (e) {
      throw _friendlyNetworkError(e);
    }
  }

  @override
  Future<void> signInWithEmail({required String email, required String password}) async {
    try {
      await _supabase.auth.signInWithPassword(email: email, password: password);
      if (await _isCurrentAccountClosed()) {
        await _supabase.auth.signOut();
        throw Exception('هذا الحساب مغلق ولا يمكن تسجيل الدخول إليه.');
      }
    } catch (e) {
      throw _friendlyNetworkError(e);
    }
  }

  @override
  Future<void> signUpWithEmail({required String email, required String password, required String fullName, required String role}) async {
    try {
      final response = await _supabase.auth.signUp(email: email, password: password, data: {'full_name': fullName, 'role': role});
      if (response.user == null) throw Exception('تعذر إنشاء الحساب');
      await updateProfile(fullName: fullName, role: role);
    } catch (e) {
      throw _friendlyNetworkError(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw _friendlyNetworkError(e);
    }
  }

  @override
  Future<void> signInWithPhone(String phone) async {
    try {
      await _supabase.auth.signInWithOtp(phone: phone);
    } catch (e) {
      throw _friendlyNetworkError(e);
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    try {
      final redirectUrl = kIsWeb
          ? Uri.parse('${Uri.base.origin}${Uri.base.path.startsWith('/istishara-platform') ? '/istishara-platform/' : '/'}')
          : Uri.parse('io.supabase.astshara://login-callback/');
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl.toString(),
        queryParams: {'prompt': 'select_account'},
      );
    } catch (e) {
      throw _friendlyNetworkError(e);
    }
  }

  @override
  Future<void> signInWithTelegram() async => throw UnsupportedError('استخدم تسجيل Telegram عبر رمز التحقق داخل التطبيق');

  @override
  Future<Map<String, dynamic>> startTelegramLogin(String phone, {bool registration = false, String? fullName, String? role}) async {
    try {
      final body = <String, dynamic>{'action': 'start', 'phone': phone, 'mode': registration ? 'signup' : 'login'};
      if (fullName != null && fullName.trim().isNotEmpty) body['full_name'] = fullName.trim();
      if (role != null && role.trim().isNotEmpty) body['role'] = role.trim();
      final result = await _supabase.functions.invoke('telegram-auth-v2', body: body);
      if (result.data is! Map) throw Exception('تعذر بدء تسجيل Telegram');
      final data = Map<String, dynamic>.from(result.data as Map);
      if (data['ok'] != true) throw Exception(data['error'] ?? 'تعذر بدء تسجيل Telegram');
      return data;
    } catch (e) {
      throw _friendlyNetworkError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> verifyTelegramLogin({required String requestToken, required String code}) async {
    try {
      final result = await _supabase.functions.invoke('telegram-auth-v2', body: {'action': 'verify', 'request_token': requestToken, 'code': code});
      if (result.data is! Map) throw Exception('تعذر التحقق من Telegram');
      final data = Map<String, dynamic>.from(result.data as Map);
      if (data['ok'] != true) throw Exception(data['error'] ?? 'تعذر إكمال تسجيل الدخول');

      final accessToken = data['access_token'];
      final refreshToken = data['refresh_token'];
      if (accessToken is String && accessToken.isNotEmpty && refreshToken is String && refreshToken.isNotEmpty) {
        final response = await _supabase.auth.setSession(refreshToken, accessToken: accessToken);
        if (response.session == null || _supabase.auth.currentUser == null) throw Exception('تم التحقق من Telegram لكن تعذر تثبيت جلسة الدخول في التطبيق');
        if (await _isCurrentAccountClosed()) {
          await _supabase.auth.signOut();
          throw Exception('هذا الحساب مغلق ولا يمكن تسجيل الدخول إليه.');
        }
        await refreshUser();
        return data;
      }

      final syntheticEmail = data['syntheticEmail'];
      final password = data['password'];
      if (syntheticEmail is String && syntheticEmail.isNotEmpty && password is String && password.isNotEmpty) {
        await signInWithEmail(email: syntheticEmail, password: password);
        if (_supabase.auth.currentUser == null) throw Exception('تعذر تثبيت جلسة الدخول في التطبيق');
        await refreshUser();
        return data;
      }
      throw Exception('تم التحقق من Telegram لكن تعذر إنشاء جلسة الدخول');
    } catch (e) {
      throw _friendlyNetworkError(e);
    }
  }

  @override
  Future<void> verifyOTP({required String phone, required String token}) async {
    try {
      await _supabase.auth.verifyOTP(phone: phone, token: token, type: OtpType.sms);
      if (await _isCurrentAccountClosed()) {
        await _supabase.auth.signOut();
        throw Exception('هذا الحساب مغلق ولا يمكن تسجيل الدخول إليه.');
      }
    } catch (e) {
      throw _friendlyNetworkError(e);
    }
  }

  @override
  Future<void> updateProfile({String? fullName, String? email, String? role, String? avatarUrl, bool? onboardingCompleted, String? walletNumber}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('لا يوجد مستخدم مسجل دخول');
      if (await _isCurrentAccountClosed()) throw Exception('هذا الحساب مغلق ولا يمكن تعديله.');

      final data = <String, dynamic>{};
      if (fullName != null && fullName.trim().isNotEmpty) data['full_name'] = fullName.trim();
      if (email != null && email.trim().isNotEmpty) data['email'] = email.trim();
      if (role != null && (role == 'lawyer' || role == 'user')) data['role'] = role;
      if (avatarUrl != null && avatarUrl.trim().isNotEmpty) data['avatar_url'] = avatarUrl.trim();
      if (onboardingCompleted != null) data['onboarding_completed'] = onboardingCompleted;
      if (walletNumber != null) data['wallet_number'] = walletNumber.trim();
      if (data.isEmpty) return;

      final existing = await _supabase.from('profiles').select('id, role').eq('auth_id', user.id).maybeSingle();
      if (existing != null) {
        data.remove('role');
        if (data.isNotEmpty) {
          await _supabase.from('profiles').update({...data, 'updated_at': DateTime.now().toIso8601String()}).eq('auth_id', user.id);
        }
      } else {
        await _supabase.from('profiles').insert({...data, 'auth_id': user.id, 'updated_at': DateTime.now().toIso8601String()});
      }
      await refreshUser();
    } catch (e) {
      throw _friendlyNetworkError(e);
    }
  }

  @override
  Future<void> refreshUser() async {
    final current = await getCurrentUser();
    _userStateController.add(current);
  }

  @override
  Future<void> deleteAccount() async {
    try {
      if (_supabase.auth.currentUser == null) return;
      await _supabase.rpc('close_my_account');
      try {
        await _supabase.auth.signOut();
      } catch (_) {}
      _userStateController.add(null);
    } catch (e) {
      throw _friendlyNetworkError(e);
    }
  }

  @override
  Stream<AppUser?> authStateChanges() => _userStateController.stream;

  void dispose() {
    _authSubscription.cancel();
    _userStateController.close();
  }
}
