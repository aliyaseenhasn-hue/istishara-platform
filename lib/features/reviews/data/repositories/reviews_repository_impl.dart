import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/review.dart';
import '../../domain/repositories/reviews_repository.dart';

class ReviewsRepositoryImpl implements ReviewsRepository {
  final SupabaseClient _supabase;

  ReviewsRepositoryImpl(this._supabase);

  @override
  Future<void> addReview(Review review) async {
    // قاعدة البيانات تتحقق من ملكية الحجز واكتماله والدفع وعدم تكرار التقييم.
    await _supabase.from('reviews').insert({
      'booking_id': review.bookingId,
      'user_id': review.userId,
      'lawyer_id': review.lawyerId,
      'rating': review.rating,
      'comment': review.comment,
    });
  }

  @override
  Future<List<Review>> getLawyerReviews(String lawyerId) async {
    final response = await _supabase
        .from('public_reviews')
        .select('review_id,lawyer_id,rating,comment,created_at')
        .eq('lawyer_id', lawyerId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Review(
              id: json['review_id'],
              bookingId: '',
              userId: '',
              lawyerId: json['lawyer_id'],
              rating: (json['rating'] as num).toDouble(),
              comment: json['comment'] ?? '',
              createdAt: DateTime.parse(json['created_at']),
            ))
        .toList();
  }
}
