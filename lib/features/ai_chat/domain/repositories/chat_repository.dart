import 'package:lotti/features/ai_chat/domain/models/chat_session.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';

abstract class ChatRepository {
  Stream<String> sendMessage({
    required String message,
    required List<ChatMessage> conversationHistory,
    String? categoryId,
    bool enableThinking = false,
  });

  Future<ChatSession> createSession({
    String? categoryId,
    String? title,
  });

  Future<ChatSession> saveSession(ChatSession session);

  Future<ChatSession?> getSession(String sessionId);

  Future<List<ChatSession>> getSessions({
    String? categoryId,
    int limit = 20,
  });

  Future<void> deleteSession(String sessionId);

  Future<ChatMessage> saveMessage(ChatMessage message);

  Future<void> deleteMessage(String messageId);
}
