import 'package:freezed_annotation/freezed_annotation.dart';

part 'evolution_chat_message.freezed.dart';

/// Lightweight message model for the evolution chat UI.
///
/// Each variant represents a distinct message type rendered differently in the
/// chat timeline.
@freezed
sealed class EvolutionChatMessage with _$EvolutionChatMessage {
  /// A message sent by the user.
  const factory EvolutionChatMessage.user({
    required String text,
    required DateTime timestamp,
  }) = EvolutionUserMessage;

  /// A response from the evolution agent.
  const factory EvolutionChatMessage.assistant({
    required String text,
    required DateTime timestamp,
  }) = EvolutionAssistantMessage;

  /// A system notification (session started, proposal rejected, etc.).
  const factory EvolutionChatMessage.system({
    required String text,
    required DateTime timestamp,
  }) = EvolutionSystemMessage;

  /// A GenUI surface rendered inline in the chat.
  const factory EvolutionChatMessage.surface({
    required String surfaceId,
    required DateTime timestamp,
  }) = EvolutionSurfaceMessage;
}
