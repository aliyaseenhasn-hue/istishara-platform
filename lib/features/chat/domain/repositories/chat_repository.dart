import '../entities/message.dart';

abstract class ChatRepository {
  Future<List<Message>> getMessages(String conversationId);
  Future<void> sendMessage(String conversationId, String senderId, String content);
  Stream<List<Message>> subscribeToMessages(String conversationId);
  Future<String?> getOtherPartyName(String conversationId, String currentAuthId);
  Future<void> markConversationRead(String conversationId, String readerId);
}
