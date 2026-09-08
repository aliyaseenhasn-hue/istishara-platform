import 'package:astshara/features/lawyers/data/models/lawyer_profile_model.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/services/private_storage_reference.dart';
import '../../../lawyers/domain/entities/lawyer_profile.dart';
import '../../../lawyers/presentation/providers/lawyers_provider.dart';

part 'lawyer_verification_provider.g.dart';

@riverpod
class LawyerVerification extends _$LawyerVerification {
  @override
  FutureOr<List<LawyerProfile>> build() async {
    final lawyerResponse = await SupabaseConfig.client
        .from('lawyer_profiles')
        .select()
        .eq('verified', false)
        .eq('verification_status', 'pending');

    final List<LawyerProfile> lawyers = [];

    for (var json in (lawyerResponse as List)) {
      var lawyer = LawyerProfileModel.fromJson(json).toEntity();

      final profileResponse = await SupabaseConfig.client
          .from('profiles')
          .select('full_name')
          .eq('id', lawyer.profileId)
          .maybeSingle();

      final fullName = profileResponse != null
          ? profileResponse['full_name']
          : 'محامي مجهول';
      final resolvedIdCardUrl = await PrivateStorageReference.resolve(
        SupabaseConfig.client,
        lawyer.idCardUrl,
      );
      lawyer = lawyer.copyWith(
        fullName: fullName,
        idCardUrl: resolvedIdCardUrl,
      );
      lawyers.add(lawyer);
    }

    return lawyers;
  }

  Future<void> approveLawyer(String profileId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await SupabaseConfig.client
          .from('lawyer_profiles')
          .update({
            'verified': true,
            'verification_status': 'approved',
            'rejection_reason': null,
          })
          .eq('profile_id', profileId)
          .eq('verification_status', 'pending');

      await _sendNotification(
        profileId: profileId,
        title: 'تم توثيق حسابك بنجاح',
        body: 'تمت الموافقة على ملفك المهني، ويمكنك الآن استقبال الاستشارات وإدارة ملفك.',
      );

      ref.invalidate(lawyersListProvider);
      return build();
    });
  }

  Future<void> rejectLawyer(String profileId, {String? reason}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final normalizedReason = reason?.trim();
      await SupabaseConfig.client
          .from('lawyer_profiles')
          .update({
            'verified': false,
            'verification_status': 'rejected',
            'rejection_reason': normalizedReason == null || normalizedReason.isEmpty
                ? 'تحتاج بيانات أو وثائق الملف إلى تعديل قبل إعادة الإرسال.'
                : normalizedReason,
          })
          .eq('profile_id', profileId)
          .eq('verification_status', 'pending');

      await _sendNotification(
        profileId: profileId,
        title: 'يحتاج طلب التوثيق إلى تعديل',
        body: normalizedReason == null || normalizedReason.isEmpty
            ? 'راجع بياناتك ووثائقك المهنية وعدّلها ثم أعد إرسال الطلب للمراجعة.'
            : 'سبب المراجعة: $normalizedReason. عدّل بياناتك ثم أعد إرسال الطلب.',
      );

      return build();
    });
  }

  Future<void> _sendNotification({
    required String profileId,
    required String title,
    required String body,
  }) async {
    try {
      await SupabaseConfig.client.from('notifications').insert({
        'user_id': profileId,
        'title': title,
        'body': body,
        'type': 'system',
      });
    } catch (e) {
      debugPrint('Error sending verification notification: $e');
    }
  }
}
