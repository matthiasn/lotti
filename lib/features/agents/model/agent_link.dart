import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/features/sync/vector_clock.dart';

part 'agent_link.freezed.dart';
part 'agent_link.g.dart';

@Freezed(fallbackUnion: 'basic')
abstract class AgentLink with _$AgentLink {
  const factory AgentLink.basic({
    required String id,
    required String fromId,
    required String toId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
  }) = BasicAgentLink;

  const factory AgentLink.agentState({
    required String id,
    required String fromId,
    required String toId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
  }) = AgentStateLink;

  const factory AgentLink.messagePrev({
    required String id,
    required String fromId,
    required String toId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
  }) = MessagePrevLink;

  const factory AgentLink.messagePayload({
    required String id,
    required String fromId,
    required String toId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
  }) = MessagePayloadLink;

  const factory AgentLink.toolEffect({
    required String id,
    required String fromId,
    required String toId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
  }) = ToolEffectLink;

  const factory AgentLink.agentTask({
    required String id,
    required String fromId,
    required String toId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
  }) = AgentTaskLink;

  factory AgentLink.fromJson(Map<String, dynamic> json) =>
      _$AgentLinkFromJson(json);
}
