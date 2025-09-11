import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';
import 'package:uuid/uuid.dart';

part 'chat_session.freezed.dart';
part 'chat_session.g.dart';

// Reuse single UUID instance for efficiency
const _uuid = Uuid();

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
        id: _uuid.v4(),
        title: title ?? 'New Chat',
        createdAt: DateTime.now(),
        lastMessageAt: DateTime.now(),
        messages: [],
        categoryId: categoryId,
      );
}
