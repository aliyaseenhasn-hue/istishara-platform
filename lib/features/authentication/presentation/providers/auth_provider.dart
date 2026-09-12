import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:astshara/core/config/supabase_config.dart';
import 'package:astshara/core/services/push_notification_service.dart';
import 'package:astshara/core/services/pwa_notification_service.dart';
import '../../../../shared/providers/global_loading_provider.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

part 'auth_provider.g.dart';

@Riverpod(keepAlive: true)
AuthRepository authRepository(AuthRepositoryRef ref) => AuthRepositoryImpl(SupabaseConfig.client);

@Riverpod(keepAlive: true)
Stream<AppUser?> authStateChanges(AuthStateChangesRef ref) async* {
  final repository = ref.watch(authRepositoryProvider);
  // Emit the already-restored OAuth session first. This is important on web,
  // where the browser returns from Google by creating a fresh Flutter app.
  yield await repository.getCurrentUser();
  yield* repository.authStateChanges();
}

final currentProfileIdProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return null;
  final response = await SupabaseConfig.client.from('profiles').select('id').eq('auth_id', user.id).maybeSingle();
  return response?['id'] as String?;
});

@riverpod
class AuthController extends _$AuthController {
  @override
  FutureOr<void> build() {}

  Future<void> signIn(String email, String password) async {
    if (email.isEmpty || password.isEmpty) { state = AsyncValue.error(Exception('البريد الإلكتروني وكلمة المرور مطلوبة'), StackTrace.current); return; }
    ref.read(globalLoadingProvider.notifier).setLoading(true); state = const AsyncLoading();
    try { state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).signInWithEmail(email: email, password: password)); }
    finally { ref.read(globalLoadingProvider.notifier).setLoading(false); }
  }

  Future<void> signUp(String email, String password, String fullName, String role) async {
    if (email.isEmpty || password.isEmpty || fullName.isEmpty || role.isEmpty) { state = AsyncValue.error(Exception('جميع الحقول مطلوبة'), StackTrace.current); return; }
    if (password.length < 6) { state = AsyncValue.error(Exception('كلمة المرور يجب أن تكون 6 أحرف على الأقل'), StackTrace.current); return; }
    ref.read(globalLoadingProvider.notifier).setLoading(true); state = const AsyncLoading();
    try { state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).signUpWithEmail(email: email, password: password, fullName: fullName, role: role)); }
    finally { ref.read(globalLoadingProvider.notifier).setLoading(false); }
  }

  Future<void> logout() async {
    ref.read(globalLoadingProvider.notifier).setLoading(true);
    try {
      // Both cleanup operations are independent. Run them together so logout
      // only waits for the slower active channel instead of adding latencies.
      await Future.wait<void>([
        PwaNotificationService.releaseForCurrentUser(),
        PushNotificationService.releaseForCurrentUser(),
      ]);
      await ref.read(authRepositoryProvider).signOut();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    } finally {
      ref.read(globalLoadingProvider.notifier).setLoading(false);
    }
  }

  Future<void> deleteAccount() async {
    ref.read(globalLoadingProvider.notifier).setLoading(true);
    state = const AsyncLoading();
    try {
      await PwaNotificationService.releaseForCurrentUser();
      await PushNotificationService.releaseForCurrentUser();
      final response = await SupabaseConfig.client.functions.invoke(
        'delete-account',
        body: {'confirm': true},
      );
      if (response.data is Map && (response.data as Map)['ok'] != true) {
        throw Exception((response.data as Map)['error']?.toString() ?? 'تعذر حذف الحساب');
      }
      try {
        await SupabaseConfig.client.auth.signOut();
      } catch (_) {}
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    } finally {
      ref.read(globalLoadingProvider.notifier).setLoading(false);
    }
  }

  Future<void> signInWithPhone(String phone) async {
    if (phone.isEmpty) { state = AsyncValue.error(Exception('رقم الهاتف مطلوب'), StackTrace.current); return; }
    ref.read(globalLoadingProvider.notifier).setLoading(true); state = const AsyncLoading();
    try { state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).signInWithPhone(phone)); }
    finally { ref.read(globalLoadingProvider.notifier).setLoading(false); }
  }

  Future<void> signInWithGoogle() async {
    ref.read(globalLoadingProvider.notifier).setLoading(true); state = const AsyncLoading();
    try { state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).signInWithGoogle()); }
    finally { ref.read(globalLoadingProvider.notifier).setLoading(false); }
  }

  Future<Map<String, dynamic>> startTelegramLogin(String phone, {bool registration = false, String? fullName, String? role}) async {
    state = const AsyncLoading();
    try {
      final result = await ref.read(authRepositoryProvider).startTelegramLogin(phone, registration: registration, fullName: fullName, role: role);
      state = const AsyncData(null);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> verifyTelegramLogin({required String requestToken, required String code}) async {
    state = const AsyncLoading();
    try { await ref.read(authRepositoryProvider).verifyTelegramLogin(requestToken: requestToken, code: code); state = const AsyncData(null); }
    catch (e, st) { state = AsyncValue.error(e, st); rethrow; }
  }

  Future<void> signInWithTelegram() async => throw UnsupportedError('استخدم تسجيل Telegram عبر رمز التحقق');

  Future<void> verifyOTP(String phone, String token) async {
    if (phone.isEmpty || token.isEmpty) { state = AsyncValue.error(Exception('رقم الهاتف والرمز مطلوبان'), StackTrace.current); return; }
    ref.read(globalLoadingProvider.notifier).setLoading(true); state = const AsyncLoading();
    try { state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).verifyOTP(phone: phone, token: token)); }
    finally { ref.read(globalLoadingProvider.notifier).setLoading(false); }
  }

  Future<void> updateInitialProfile({required String fullName, String? email, required String role, bool onboardingCompleted = true}) async {
    if (fullName.isEmpty || role.isEmpty) { state = AsyncValue.error(Exception('الاسم الكامل والدور مطلوبان'), StackTrace.current); return; }
    ref.read(globalLoadingProvider.notifier).setLoading(true); state = const AsyncLoading();
    try { await ref.read(authRepositoryProvider).updateProfile(fullName: fullName, email: email, role: role, onboardingCompleted: onboardingCompleted); state = const AsyncData(null); }
    catch (e, st) { state = AsyncValue.error(e, st); }
    finally { ref.read(globalLoadingProvider.notifier).setLoading(false); }
  }
}
