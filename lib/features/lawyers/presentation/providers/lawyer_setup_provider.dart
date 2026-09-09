import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/legal_specializations.dart';
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
      state = AsyncValue.error(Exception('البيانات المطلوبة غير كاملة'), StackTrace.current);
      return;
    }

    if (idCardBytes == null || idCardBytes.isEmpty) {
      state = AsyncValue.error(Exception('صورة هوية النقابة إلزامية'), StackTrace.current);
      return;
    }

    final normalizedSpecializations = (specializations ?? const <String>[])
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty && LegalSpecializations.all.contains(value))
        .toSet()
        .take(LegalSpecializations.maxLawyerSpecializations)
        .toList(growable: false);

    if (normalizedSpecializations.isEmpty) {
      state = AsyncValue.error(
        Exception('اختر تخصصاً رئيسياً واحداً على الأقل'),
        StackTrace.current,
      );
      return;
    }

    final requestedPrice = consultationPrice ?? 20000;
    final normalizedPrice = requestedPrice.clamp(20000, 50000).toDouble();

    ref.read(globalLoadingProvider.notifier).setLoading(true);
    state = const AsyncLoading();

    try {
      final lawyersRepo = ref.read(lawyersRepositoryProvider);
      final authRepo = ref.read(authRepositoryProvider);

      await authRepo.updateProfile(
        fullName: fullName,
        email: email,
        role: 'lawyer',
        onboardingCompleted: false,
      );

      await SupabaseConfig.client.rpc('register_self_as_lawyer');

      final profileRow = await SupabaseConfig.client
          .from('profiles')
          .select('id')
          .eq('auth_id', authUid)
          .maybeSingle();

      if (profileRow == null) {
        throw Exception('لم يتم العثور على سجل المستخدم');
      }
      final profileId = profileRow['id'] as String;

      String? avatarUrl;
      if (profilePhotoBytes != null && profilePhotoBytes.isNotEmpty) {
        try {
          final fileName = 'avatar_${profileId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          avatarUrl = await lawyersRepo.uploadFile(profilePhotoBytes, fileName, 'avatars');
        } catch (e) {
          debugPrint('فشل رفع الصورة الشخصية الاختيارية: $e');
        }
      }

      final idFileName = 'id_${profileId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final idCardUrl = await lawyersRepo.uploadFile(idCardBytes, idFileName, 'lawyer_documents');
      if (idCardUrl.trim().isEmpty) {
        throw Exception('تعذر حفظ وثيقة التحقق. حاول رفعها مرة أخرى.');
      }

      final lawyerProfile = LawyerProfile(
        id: '',
        profileId: profileId,
        fullName: fullName,
        whatsapp: null,
        idCardUrl: idCardUrl,
        verified: false,
        licenseNumber: licenseNumber ?? 'PENDING',
        specializations: normalizedSpecializations,
        bio: bio ?? 'طلب انضمام جديد',
        yearsExperience: yearsExperience ?? 0,
        consultationPrice: normalizedPrice,
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
