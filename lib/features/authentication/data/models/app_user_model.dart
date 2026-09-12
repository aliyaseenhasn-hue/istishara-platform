import '../../domain/entities/app_user.dart';

class AppUserModel {
  final String id;
  final String? email;
  final String? fullName;
  final String? phone;
  final String? avatarUrl;
  final String role;
  final bool isVerified;
  final bool hasProfessionalProfile;
  final bool? isOnboardingComplete;
  final String? walletNumber;

  const AppUserModel({
    required this.id,
    this.email,
    this.fullName,
    this.phone,
    this.avatarUrl,
    this.role = 'user',
    this.isVerified = false,
    this.hasProfessionalProfile = false,
    this.isOnboardingComplete,
    this.walletNumber,
  });

  factory AppUserModel.fromJson(Map<String, dynamic> json) {
    return AppUserModel(
      id: json['id'] as String? ?? '',
      email: json['email'] as String?,
      fullName: json['full_name'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: json['role'] as String? ?? 'user',
      isVerified: json['is_verified'] as bool? ?? false,
      hasProfessionalProfile: json['has_professional_profile'] as bool? ?? false,
      isOnboardingComplete: json['onboarding_completed'] as bool?,
      walletNumber: json['wallet_number'] as String?,
    );
  }

  AppUser toEntity() => AppUser(
        id: id,
        email: email,
        fullName: fullName,
        phone: phone,
        avatarUrl: avatarUrl,
        role: role,
        isVerified: isVerified,
        hasProfessionalProfile: hasProfessionalProfile,
        isOnboardingComplete: isOnboardingComplete ?? false,
        walletNumber: walletNumber,
      );
}
