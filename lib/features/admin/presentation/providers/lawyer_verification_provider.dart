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
    try {
      final lawyerResponse = await SupabaseConfig.client
          .from('lawyer_profiles')
          .select()
          .eq('verified', false);

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
    } catch (e) {
      debugPrint('Critical Error in LawyerVerification: $e');
      return [];
    }
  }

  Future<void> approveLawyer(String profileId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await SupabaseConfig.client
          .from('lawyer_profiles')
          .update({'verified': true}).eq('profile_id', profileId);

      await _sendNotification(
        profileId: profileId,
        title: 'تم توثيق حسابك بنجاح ✅',
        body:
            'مرحباً بك! لقد تمت الموافقة على انضمامك، يمكنك الآن البدء في استقبال الاستشارات وتعديل ملفك المهني.',
      );

      ref.invalidate(lawyersListProvider);
      return build();
    });
  }

  Future<void> rejectLawyer(String profileId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _sendNotification(
        profileId: profileId,
        title: 'بخصوص طلب الانضمام ⚖️',
        body:
            'نعتذر منك، لم نتمكن من توثيق حسابك حالياً. يرجى التأكد من صحة الوثائق المرفوعة والمحاولة مرة أخرى.',
      );

      await SupabaseConfig.client
          .from('lawyer_profiles')
          .delete()
          .eq('profile_id', profileId);

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
