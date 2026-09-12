class AppUser {
  final String id;
  final String? email;
  final String? fullName;
  final String? phone;
  final String? avatarUrl;
  final String role;
  final bool isVerified;
  final bool hasProfessionalProfile;
  final bool isOnboardingComplete;
  final String? walletNumber;

  const AppUser({
    required this.id,
    this.email,
    this.fullName,
    this.phone,
    this.avatarUrl,
    this.role = 'user',
    this.isVerified = false,
    this.hasProfessionalProfile = false,
    this.isOnboardingComplete = false,
    this.walletNumber,
  });

  AppUser copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? role,
    bool? isVerified,
    bool? hasProfessionalProfile,
    bool? isOnboardingComplete,
    String? walletNumber,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      isVerified: isVerified ?? this.isVerified,
      hasProfessionalProfile: hasProfessionalProfile ?? this.hasProfessionalProfile,
      isOnboardingComplete: isOnboardingComplete ?? this.isOnboardingComplete,
      walletNumber: walletNumber ?? this.walletNumber,
    );
  }
}
