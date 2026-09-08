import 'dart:async';
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

final chatAccessProvider = FutureProvider.family<bool, String>((ref, conversationId) async {
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
  final authState = ref.watch(authStateChangesProvider).value;
  if (authState == null) return null;
  final conversation = await SupabaseConfig.client
      .from('conversations')
      .select('user_id,lawyer_id')
      .eq('id', conversationId)
      .maybeSingle();
  if (conversation == null) return null;

  final current = await SupabaseConfig.client
      .from('profiles')
      .select('id')
      .eq('auth_id', authState.id)
      .maybeSingle();
  final currentId = current?['id']?.toString();
  if (currentId == null) return null;

  final userId = conversation['user_id']?.toString();
  final lawyerId = conversation['lawyer_id']?.toString();
  if (currentId == userId) return lawyerId;
  if (currentId == lawyerId) return userId;
  return null;
});

/// Chat is available only after a real booking is confirmed/in progress/completed.
final chatAvailabilityForLawyerProvider =
    FutureProvider.family<String?, String>((ref, lawyerProfileId) async {
  final authUser = SupabaseConfig.client.auth.currentUser;
  if (authUser == null) return null;

  final profile = await SupabaseConfig.client
      .from('profiles')
      .select('id,role')
      .eq('auth_id', authUser.id)
      .maybeSingle();
  final currentProfileId = profile?['id']?.toString();
  if (currentProfileId == null || profile?['role'] == 'lawyer') return null;

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

  final conversation = await SupabaseConfig.client
      .from('conversations')
      .select('id')
      .eq('user_id', currentProfileId)
      .eq('lawyer_id', lawyerProfileId)
      .limit(1)
      .maybeSingle();
  return conversation?['id']?.toString();
});

@riverpod
class ChatController extends _$ChatController {
  @override
  FutureOr<void> build() {}

  Future<String?> _profileId() async {
    final user = ref.read(authStateChangesProvider).value;
    if (user == null) return null;
    final row = await SupabaseConfig.client
        .from('profiles')
        .select('id')
        .eq('auth_id', user.id)
        .maybeSingle();
    return row?['id'] as String?;
  }

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
  }
}
