import 'package:astshara/features/lawyers/data/models/lawyer_profile_model.dart';
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
      await SupabaseConfig.client.rpc(
        'admin_review_lawyer_verification',
        params: {
          'p_profile_id': profileId,
          'p_approved': true,
          'p_reason': null,
        },
      );

      ref.invalidate(lawyersListProvider);
      return build();
    });
  }

  Future<void> rejectLawyer(String profileId, {String? reason}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final normalizedReason = reason?.trim();
      if (normalizedReason == null || normalizedReason.isEmpty) {
        throw Exception('سبب إعادة الطلب للتعديل إلزامي');
      }

      await SupabaseConfig.client.rpc(
        'admin_review_lawyer_verification',
        params: {
          'p_profile_id': profileId,
          'p_approved': false,
          'p_reason': normalizedReason,
        },
      );

      ref.invalidate(lawyersListProvider);
      return build();
    });
  }
}
