import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';
import 'package:uuid/uuid.dart';

part 'chat_session.freezed.dart';
part 'chat_session.g.dart';

@freezed
class ChatSession with _$ChatSession {
  const factory ChatSession({
    required String id,
    required String title,
    required DateTime createdAt,
    required DateTime lastMessageAt,
    required List<ChatMessage> messages,
    String? categoryId,
    Map<String, dynamic>? metadata,
  }) = _ChatSession;

  factory ChatSession.fromJson(Map<String, dynamic> json) =>
      _$ChatSessionFromJson(json);

  factory ChatSession.create({
    String? categoryId,
    String? title,
  }) =>
      ChatSession(
        id: const Uuid().v4(),
        title: title ?? 'New Chat',
        createdAt: DateTime.now(),
        lastMessageAt: DateTime.now(),
        messages: [],
        categoryId: categoryId,
      );
}

extension ChatSessionX on ChatSession {
  ChatSession addMessage(ChatMessage message) => copyWith(
        messages: [...messages, message],
        lastMessageAt: DateTime.now(),
      );

  ChatSession updateMessage(String messageId, ChatMessage updatedMessage) =>
      copyWith(
        messages: messages
            .map((msg) => msg.id == messageId ? updatedMessage : msg)
            .toList(),
        lastMessageAt: DateTime.now(),
      );

  ChatMessage? get lastMessage => messages.isEmpty ? null : messages.last;

  List<ChatMessage> get conversationHistory =>
      messages.where((msg) => msg.role != ChatMessageRole.system).toList();

  int get messageCount => messages.length;

  bool get isEmpty => messages.isEmpty;

  bool get hasCategory => categoryId != null;
}
