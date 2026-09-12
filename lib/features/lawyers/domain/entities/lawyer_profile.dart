class LawyerService {
  final String title;
  final double price;
  final String? description;

  const LawyerService({
    required this.title,
    required this.price,
    this.description,
  });

  /// Compatibility identifier used by booking UI. Services in the current
  /// profile model are embedded by title rather than by a separate database id.
  String get id => title;

  Map<String, dynamic> toJson() => {
        'title': title,
        'price': price,
        'description': description,
      };

  factory LawyerService.fromJson(Map<String, dynamic> json) => LawyerService(
        title: json['title'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        description: json['description'] as String?,
      );

  LawyerService copyWith({String? title, double? price, String? description}) =>
      LawyerService(
        title: title ?? this.title,
        price: price ?? this.price,
        description: description ?? this.description,
      );
}

class LawyerProfile {
  final String id;
  final String profileId;
  final String? fullName;
  final String? licenseNumber;
  final String? practiceLicenseClass;
  final String? bio;
  final List<String> specializations;
  final int? yearsExperience;
  final double? consultationPrice;
  final String? whatsapp;
  final String? idCardUrl;
  final double rating;
  final int reviewCount;
  final bool verified;
  final bool availability;
  final String? avatarUrl;
  final List<LawyerService> services;

  const LawyerProfile({
    required this.id,
    required this.profileId,
    this.fullName,
    this.licenseNumber,
    this.practiceLicenseClass,
    this.bio,
    this.specializations = const [],
    this.yearsExperience,
    this.consultationPrice,
    this.whatsapp,
    this.idCardUrl,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.verified = false,
    this.availability = true,
    this.avatarUrl,
    this.services = const [],
  });

  LawyerProfile copyWith({
    String? id,
    String? profileId,
    String? fullName,
    String? licenseNumber,
    String? practiceLicenseClass,
    String? bio,
    List<String>? specializations,
    int? yearsExperience,
    double? consultationPrice,
    String? whatsapp,
    String? idCardUrl,
    double? rating,
    int? reviewCount,
    bool? verified,
    bool? availability,
    String? avatarUrl,
    List<LawyerService>? services,
  }) {
    return LawyerProfile(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      fullName: fullName ?? this.fullName,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      practiceLicenseClass: practiceLicenseClass ?? this.practiceLicenseClass,
      bio: bio ?? this.bio,
      specializations: specializations ?? this.specializations,
      yearsExperience: yearsExperience ?? this.yearsExperience,
      consultationPrice: consultationPrice ?? this.consultationPrice,
      whatsapp: whatsapp ?? this.whatsapp,
      idCardUrl: idCardUrl ?? this.idCardUrl,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      verified: verified ?? this.verified,
      availability: availability ?? this.availability,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      services: services ?? this.services,
    );
  }
}
