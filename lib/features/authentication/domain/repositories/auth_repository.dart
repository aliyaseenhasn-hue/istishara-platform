import '../entities/app_user.dart';

abstract class AuthRepository {
  Future<AppUser?> getCurrentUser();
  Future<void> signInWithEmail({required String email, required String password});
  Future<void> signUpWithEmail({required String email, required String password, required String fullName, required String role});
  Future<void> signOut();
  Future<void> signInWithPhone(String phone);
  Future<void> verifyOTP({required String phone, required String token});
  Future<void> signInWithGoogle();
  Future<void> signInWithTelegram();
  Future<Map<String, dynamic>> startTelegramLogin(String phone, {bool registration = false, String? fullName, String? role});
  Future<Map<String, dynamic>> verifyTelegramLogin({required String requestToken, required String code});
  Future<void> updateProfile({String? fullName, String? email, String? role, String? avatarUrl, bool? onboardingCompleted, String? walletNumber});
  Future<void> refreshUser();
  Future<void> deleteAccount();
  Stream<AppUser?> authStateChanges();
}