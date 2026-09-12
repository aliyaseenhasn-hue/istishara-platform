import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:astshara/core/config/supabase_config.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/chat_repository.dart';
part 'chat_provider.g.dart';

@riverpod
ChatRepository chatRepository(ChatRepositoryRef ref) =>
    ChatRepositoryImpl(SupabaseConfig.client);

@riverpod
Stream<List<Message>> chatMessages(
  ChatMessagesRef ref,
  String conversationId,
) =>
    ref.watch(chatRepositoryProvider).subscribeToMessages(conversationId);

/// Cached conversation list used by the inbox. The RPC returns the counterpart
/// name with the conversation in one round-trip, avoiding N+1 profile lookups.
/// The provider is intentionally not autoDispose so returning to the inbox can
/// paint the last value immediately; send/push events explicitly invalidate it.
final conversationsListProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final profileId = await ref.watch(currentProfileIdProvider.future);
  if (profileId == null || profileId.isEmpty) return const [];

  final response =
      await SupabaseConfig.client.rpc('get_my_conversations_summary');
  if (response is! List) return const [];
  return response
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList(growable: false);
});

final chatAccessProvider =
    FutureProvider.family<bool, String>((ref, conversationId) async {
  final authState = ref.watch(authStateChangesProvider).value;
  if (authState == null) return false;
  final result = await SupabaseConfig.client.rpc(
    'can_access_conversation',
    params: {'p_conversation_id': conversationId},
  );
  return result == true;
});

final chatOtherPartyNameProvider =
    FutureProvider.family<String?, String>((ref, conversationId) async {
  final authState = ref.watch(authStateChangesProvider).value;
  if (authState == null) return null;
  return ref
      .read(chatRepositoryProvider)
      .getOtherPartyName(conversationId, authState.id);
});

final chatOtherPartyProfileIdProvider =
    FutureProvider.family<String?, String>((ref, conversationId) async {
  final currentId = await ref.watch(currentProfileIdProvider.future);
  if (currentId == null || currentId.isEmpty) return null;

  final conversation = await SupabaseConfig.client
      .from('conversations')
      .select('user_id,lawyer_id')
      .eq('id', conversationId)
      .maybeSingle();
  if (conversation == null) return null;

  final userId = conversation['user_id']?.toString();
  final lawyerId = conversation['lawyer_id']?.toString();
  if (currentId == userId) return lawyerId;
  if (currentId == lawyerId) return userId;
  return null;
});

/// Chat is available only after a real booking is confirmed/in progress/completed.
/// New conversations are scoped to the booking. A legacy pair conversation is
/// used only as a fallback for bookings created before per-booking chat existed.
final chatAvailabilityForLawyerProvider =
    FutureProvider.family<String?, String>((ref, lawyerProfileId) async {
  final authUser = ref.watch(authStateChangesProvider).value;
  if (authUser == null || authUser.role == 'lawyer') return null;

  final currentProfileId = await ref.watch(currentProfileIdProvider.future);
  if (currentProfileId == null || currentProfileId.isEmpty) return null;

  final booking = await SupabaseConfig.client
      .from('bookings')
      .select('id,user_id,lawyer_id,status,scheduled_at')
      .eq('user_id', currentProfileId)
      .eq('lawyer_id', lawyerProfileId)
      .inFilter('status', const ['مؤكد', 'قيد التنفيذ', 'مكتمل'])
      .order('scheduled_at', ascending: false)
      .limit(1)
      .maybeSingle();
  if (booking == null) return null;

  final bookingId = booking['id']?.toString();
  if (bookingId == null) return null;

  final exact = await SupabaseConfig.client
      .from('conversations')
      .select('id')
      .eq('booking_id', bookingId)
      .maybeSingle();
  final exactId = exact?['id']?.toString();
  if (exactId != null) return exactId;

  final legacy = await SupabaseConfig.client
      .from('conversations')
      .select('id')
      .eq('user_id', currentProfileId)
      .eq('lawyer_id', lawyerProfileId)
      .isFilter('booking_id', null)
      .order('created_at', ascending: false)
      .limit(1)
      .maybeSingle();
  return legacy?['id']?.toString();
});

@riverpod
class ChatController extends _$ChatController {
  @override
  FutureOr<void> build() {}

  Future<String?> _profileId() =>
      ref.read(currentProfileIdProvider.future);

  Future<void> markRead(String conversationId) async {
    final id = await _profileId();
    if (id == null) return;
    await ref
        .read(chatRepositoryProvider)
        .markConversationRead(conversationId, id);
  }

  Future<void> send(String conversationId, String content) async {
    final id = await _profileId();
    if (id == null) {
      throw Exception('تعذر تحديد حساب المستخدم');
    }
    final allowed = await ref.read(chatAccessProvider(conversationId).future);
    if (!allowed) {
      throw Exception('المحادثة متاحة فقط بعد تأكيد الحجز');
    }
    await ref
        .read(chatRepositoryProvider)
        .sendMessage(conversationId, id, content);
    ref.invalidate(conversationsListProvider);
  }
}
