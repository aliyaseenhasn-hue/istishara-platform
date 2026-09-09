import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:astshara/core/config/supabase_config.dart';
import '../../data/repositories/lawyers_repository_impl.dart';
import '../../domain/entities/lawyer_profile.dart';
import '../../domain/repositories/lawyers_repository.dart';
part 'lawyers_provider.g.dart';

@riverpod
LawyersRepository lawyersRepository(LawyersRepositoryRef ref) => LawyersRepositoryImpl(SupabaseConfig.client);

final searchQueryProvider = StateProvider<String>((ref) => '');

String _normalizeSpecialization(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'[إأآ]'), 'ا').replaceAll('ة', 'ه').replaceAll(RegExp(r'[\u064B-\u065F]'), '').replaceAll(RegExp(r'\s+'), ' ');
}

bool _matchesCategory(LawyerProfile lawyer, String category) {
  final wanted = _normalizeSpecialization(category);
  if (wanted.isEmpty) return true;
  return lawyer.specializations.any((specialization) {
    final actual = _normalizeSpecialization(specialization);
    if (actual == wanted) return true;
    final wantedTokens = wanted.split(' ').where((e) => e.isNotEmpty).toSet();
    final actualTokens = actual.split(' ').where((e) => e.isNotEmpty).toSet();
    return wantedTokens.isNotEmpty && wantedTokens.every(actualTokens.contains);
  });
}

bool _matchesSearch(LawyerProfile lawyer, String query) {
  final q = _normalizeSpecialization(query);
  if (q.isEmpty) return true;
  final name = _normalizeSpecialization(lawyer.fullName ?? '');
  if (name == q || name.split(' ').contains(q)) return true;
  return lawyer.specializations.any((specialization) {
    final value = _normalizeSpecialization(specialization);
    return value == q || value.split(' ').contains(q);
  });
}

@Riverpod(keepAlive: true)
Future<List<LawyerProfile>> lawyersList(LawyersListRef ref) async {
  // هذه القائمة تستخدمها الصفحة الرئيسية والصفحات العامة لعرض المحامين.
  // لا نربطها بحالة البحث أو التصنيف حتى لا تختفي الاقتراحات بسبب فلتر
  // بقي محفوظاً من صفحة دليل المحامين. صفحة الدليل تملك فلترها المحلي المستقل.
  final lawyers = await ref.watch(lawyersRepositoryProvider).getLawyers();
  final list = lawyers.toList()..sort((a, b) {
    if (a.availability && !b.availability) return -1;
    if (!a.availability && b.availability) return 1;
    final r = b.rating.compareTo(a.rating);
    return r != 0 ? r : b.reviewCount.compareTo(a.reviewCount);
  });
  return list;
}

@riverpod
class SelectedCategory extends _$SelectedCategory {
  @override
  String? build() => null;
  void setCategory(String? category) => state == category ? state = null : state = category;
}

@Riverpod(keepAlive: true)
Future<LawyerProfile?> lawyerProfile(LawyerProfileRef ref, String profileId) => ref.watch(lawyersRepositoryProvider).getLawyerProfile(profileId);

final ownLawyerProfileProvider = FutureProvider.family<LawyerProfile?, String>((ref, profileId) async {
  return ref.read(lawyersRepositoryProvider).getOwnLawyerProfile(profileId);
});

final userNameProvider = FutureProvider.family<String?, String>((ref, profileId) async {
  final profile = await SupabaseConfig.client.from('profiles').select('full_name').eq('id', profileId).maybeSingle();
  final profileName = profile?['full_name'] as String?;
  if (profileName != null && profileName.trim().isNotEmpty) return profileName;
  final lawyer = await SupabaseConfig.client.from('lawyer_profiles').select('full_name').eq('profile_id', profileId).maybeSingle();
  return lawyer?['full_name'] as String?;
});
