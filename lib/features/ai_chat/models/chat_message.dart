import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part 'chat_message.freezed.dart';
part 'chat_message.g.dart';

// Reuse single UUID instance for efficiency
const _uuid = Uuid();

@freezed
abstract class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    required String id,
    required String content,
    required ChatMessageRole role,
    required DateTime timestamp,
    @Default(false) bool isStreaming,
    Map<String, dynamic>? metadata,
  }) = _ChatMessage;

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);

  factory ChatMessage.user(String content) => ChatMessage(
        id: _uuid.v4(),
        content: content,
        role: ChatMessageRole.user,
        timestamp: DateTime.now(),
      );

  factory ChatMessage.assistant(String content, {bool isStreaming = false}) =>
      ChatMessage(
        id: _uuid.v4(),
        content: content,
        role: ChatMessageRole.assistant,
        timestamp: DateTime.now(),
        isStreaming: isStreaming,
      );

  factory ChatMessage.system(String content) => ChatMessage(
        id: _uuid.v4(),
        content: content,
        role: ChatMessageRole.system,
        timestamp: DateTime.now(),
      );
}

enum ChatMessageRole {
  user,
  assistant,
  system,
}
