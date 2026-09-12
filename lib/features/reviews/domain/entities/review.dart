class Review {
  final String id;
  final String bookingId;
  final String userId;
  final String lawyerId;
  final double rating;
  final String comment;
  final DateTime? createdAt;

  const Review({
    required this.id,
    required this.bookingId,
    required this.userId,
    required this.lawyerId,
    required this.rating,
    required this.comment,
    this.createdAt,
  });

  Review copyWith({
    String? id,
    String? bookingId,
    String? userId,
    String? lawyerId,
    double? rating,
    String? comment,
    DateTime? createdAt,
  }) {
    return Review(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      userId: userId ?? this.userId,
      lawyerId: lawyerId ?? this.lawyerId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
