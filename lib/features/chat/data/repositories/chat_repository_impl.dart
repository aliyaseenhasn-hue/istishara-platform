import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../models/message_model.dart';

class ChatRepositoryImpl implements ChatRepository {
  final SupabaseClient _supabase;
  ChatRepositoryImpl(this._supabase);

  @override
  Future<List<Message>> getMessages(String conversationId) async {
    final response = await _supabase
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);
    return (response as List)
        .map((json) => MessageModel.fromJson(json).toEntity())
        .toList();
  }

  @override
  Future<void> sendMessage(
    String conversationId,
    String senderId,
    String content,
  ) async {
    final text = content.trim();
    if (text.isEmpty) throw Exception('لا يمكن إرسال رسالة فارغة');
    if (text.length > 4000) throw Exception('الرسالة طويلة جدًا');

    try {
      await _supabase.rpc(
        'send_chat_message',
        params: {
          'p_conversation_id': conversationId,
          'p_content': text,
        },
      );
    } on PostgrestException catch (e) {
      final message = e.message.trim();
      if (message.isNotEmpty && !message.contains('PGRST')) {
        throw Exception(message);
      }
      throw Exception('تعذر إرسال الرسالة. تحقق من أن الحجز مؤكد ثم حاول مجددًا.');
    } catch (_) {
      throw Exception('تعذر إرسال الرسالة. حاول مرة أخرى.');
    }
  }

  @override
  Stream<List<Message>> subscribeToMessages(String conversationId) {
    late final StreamController<List<Message>> controller;
    RealtimeChannel? channel;

    Future<void> fetchAndEmit() async {
      try {
        final data = await _supabase
            .from('messages')
            .select()
            .eq('conversation_id', conversationId)
            .order('created_at', ascending: true);
        final messages = (data as List)
            .map((json) => MessageModel.fromJson(json).toEntity())
            .toList();
        if (!controller.isClosed) controller.add(messages);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    controller = StreamController<List<Message>>(
      onListen: () async {
        await fetchAndEmit();
        channel = _supabase
            .channel('messages:$conversationId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'messages',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'conversation_id',
                value: conversationId,
              ),
              callback: (_) => fetchAndEmit(),
            )
            .subscribe();
      },
      onCancel: () async {
        await channel?.unsubscribe();
        await controller.close();
      },
    );
    return controller.stream;
  }

  @override
  Future<void> markConversationRead(
    String conversationId,
    String readerId,
  ) async {
    try {
      await _supabase.rpc(
        'mark_chat_read',
        params: {'p_conversation_id': conversationId},
      );
    } catch (_) {
      // Read receipts must never block opening the conversation.
    }
  }

  @override
  Future<String?> getOtherPartyName(
    String conversationId,
    String currentAuthId,
  ) async {
    try {
      final conversation = await _supabase
          .from('conversations')
          .select('user_id,lawyer_id')
          .eq('id', conversationId)
          .maybeSingle();
      if (conversation == null) return null;
      final currentProfileRow = await _supabase
          .from('profiles')
          .select('id')
          .eq('auth_id', currentAuthId)
          .maybeSingle();
      if (currentProfileRow == null) return null;
      final currentProfileId = currentProfileRow['id'] as String;
      final userId = conversation['user_id'] as String?;
      final lawyerId = conversation['lawyer_id'] as String?;
      String? otherPartyId;
      bool otherPartyIsLawyer = false;
      if (currentProfileId == userId) {
        otherPartyId = lawyerId;
        otherPartyIsLawyer = true;
      } else if (currentProfileId == lawyerId) {
        otherPartyId = userId;
      } else {
        return null;
      }
      if (otherPartyId == null) return null;

      if (otherPartyIsLawyer) {
        final row = await _supabase
            .from('lawyer_profiles')
            .select('full_name')
            .eq('profile_id', otherPartyId)
            .maybeSingle();
        final name = (row?['full_name'] as String?) ??
            (await _supabase
                    .from('profiles')
                    .select('full_name')
                    .eq('id', otherPartyId)
                    .maybeSingle())?['full_name']
                as String?;
        return name == null ? null : 'المحامي / $name';
      }

      final row = await _supabase
          .from('profiles')
          .select('full_name')
          .eq('id', otherPartyId)
          .maybeSingle();
      final name = row?['full_name'] as String?;
      return name == null ? null : 'طالب الاستشارة / $name';
    } catch (_) {
      return null;
    }
  }
}
