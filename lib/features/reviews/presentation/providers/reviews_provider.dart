import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:astshara/core/config/supabase_config.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../data/repositories/reviews_repository_impl.dart';
import '../../domain/entities/review.dart';
import '../../domain/repositories/reviews_repository.dart';

part 'reviews_provider.g.dart';

@riverpod
ReviewsRepository reviewsRepository(ReviewsRepositoryRef ref) {
  return ReviewsRepositoryImpl(SupabaseConfig.client);
}

@riverpod
Future<List<Review>> lawyerReviews(LawyerReviewsRef ref, String lawyerId) {
  return ref.watch(reviewsRepositoryProvider).getLawyerReviews(lawyerId);
}

@riverpod
class ReviewController extends _$ReviewController {
  @override
  FutureOr<void> build() {}

  Future<void> submitReview({
    required String bookingId,
    required String lawyerId,
    required double rating,
    required String comment,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authStateChangesProvider).value;
      if (user == null) {
        throw Exception('يجب تسجيل الدخول لإرسال التقييم');
      }

      if (rating < 1 || rating > 5) {
        throw Exception('التقييم يجب أن يكون بين نجمة و5 نجوم');
      }

      final profileRow = await SupabaseConfig.client
          .from('profiles')
          .select('id')
          .eq('auth_id', user.id)
          .maybeSingle();

      if (profileRow == null || profileRow['id'] == null) {
        throw Exception('لم يتم العثور على ملف العميل');
      }

      final userProfileId = profileRow['id'] as String;

      // Always derive the lawyer from the booking. This prevents an incorrect
      // lawyerId supplied by the UI from making the INSERT fail RLS checks.
      final booking = await SupabaseConfig.client
          .from('bookings')
          .select('user_id, lawyer_id, status, consultation_status')
          .eq('id', bookingId)
          .maybeSingle();

      if (booking == null) {
        throw Exception('الحجز غير موجود');
      }

      if (booking['user_id']?.toString() != userProfileId) {
        throw Exception('لا يمكنك تقييم هذا الحجز');
      }

      final bookingLawyerId = booking['lawyer_id']?.toString();
      if (bookingLawyerId == null || bookingLawyerId.isEmpty) {
        throw Exception('لم يتم تحديد المحامي لهذا الحجز');
      }

      if (booking['status']?.toString() != 'مكتمل') {
        throw Exception('لا يمكن إرسال التقييم إلا بعد انتهاء الاستشارة');
      }

      final consultationStatus = booking['consultation_status']?.toString();
      if (consultationStatus != null &&
          consultationStatus.isNotEmpty &&
          consultationStatus != 'انتهت') {
        throw Exception('الاستشارة لم تنتهِ بعد');
      }

      final review = Review(
        id: '',
        bookingId: bookingId,
        userId: userProfileId,
        lawyerId: bookingLawyerId,
        rating: rating,
        comment: comment.trim(),
      );

      await ref.read(reviewsRepositoryProvider).addReview(review);
    });
  }
}
