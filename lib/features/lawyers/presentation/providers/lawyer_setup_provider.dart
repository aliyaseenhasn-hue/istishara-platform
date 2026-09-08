import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../shared/providers/global_loading_provider.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../domain/entities/lawyer_profile.dart';
import 'lawyers_provider.dart';

part 'lawyer_setup_provider.g.dart';

@riverpod
class LawyerSetupController extends _$LawyerSetupController {
  @override
  FutureOr<void> build() {}

  Future<void> completeProfile({
    required String authUid,
    required String fullName,
    String? email,
    String? licenseNumber,
    String? bio,
    List<String>? specializations,
    int? yearsExperience,
    double? consultationPrice,
    Uint8List? profilePhotoBytes,
    Uint8List? idCardBytes,
  }) async {
    if (fullName.isEmpty) {
      throw Exception('البيانات المطلوبة غير كاملة');
    }

    ref.read(globalLoadingProvider.notifier).setLoading(true);
    state = const AsyncLoading();

    try {
      final lawyersRepo = ref.read(lawyersRepositoryProvider);
      final authRepo = ref.read(authRepositoryProvider);

      debugPrint('--- بدء عملية إكمال الملف للمحامي ---');

      await authRepo.updateProfile(
        fullName: fullName,
        email: email,
        role: 'lawyer',
        onboardingCompleted: false,
      );

      // Phone/OTP accounts can already have a safe default `user` profile from
      // the auth trigger. Promote only through the guarded server RPC so the
      // client never writes security-sensitive role fields directly.
      await SupabaseConfig.client.rpc('register_self_as_lawyer');

      final profileRow = await SupabaseConfig.client
          .from('profiles')
          .select('id')
          .eq('auth_id', authUid)
          .maybeSingle();

      if (profileRow == null) {
        throw Exception('لم يتم العثور على سجل Profile للمستخدم');
      }
      final profileId = profileRow['id'] as String;

      String? avatarUrl;
      String? idCardUrl;

      if (profilePhotoBytes != null && profilePhotoBytes.isNotEmpty) {
        try {
          final fileName = 'avatar_${profileId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          avatarUrl = await lawyersRepo.uploadFile(profilePhotoBytes, fileName, 'avatars');
        } catch (e) {
          debugPrint('فشل رفع الصورة الشخصية: $e');
        }
      }

      if (idCardBytes != null && idCardBytes.isNotEmpty) {
        try {
          final fileName = 'id_${profileId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          idCardUrl = await lawyersRepo.uploadFile(idCardBytes, fileName, 'lawyer_documents');
        } catch (e) {
          debugPrint('فشل رفع صورة الهوية: $e');
        }
      }

      final lawyerProfile = LawyerProfile(
        id: '',
        profileId: profileId,
        fullName: fullName,
        whatsapp: null,
        idCardUrl: idCardUrl,
        verified: false,
        licenseNumber: licenseNumber ?? 'PENDING',
        specializations: specializations ?? [],
        bio: bio ?? 'طلب انضمام جديد',
        yearsExperience: yearsExperience ?? 0,
        consultationPrice: consultationPrice ?? 0,
      );

      await lawyersRepo.updateLawyerProfile(lawyerProfile);

      await authRepo.updateProfile(
        avatarUrl: avatarUrl,
        onboardingCompleted: true,
      );

      state = const AsyncData(null);
    } catch (e, st) {
      debugPrint('خطأ في إكمال الملف: $e');
      state = AsyncValue.error(e, st);
    } finally {
      ref.read(globalLoadingProvider.notifier).setLoading(false);
    }
  }
}
