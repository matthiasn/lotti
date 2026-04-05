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

  const factory AgentLink.templateAssignment({
    required String id,
    required String fromId,
    required String toId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
  }) = TemplateAssignmentLink;

  const factory AgentLink.improverTarget({
    required String id,
    required String fromId,
    required String toId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
  }) = ImproverTargetLink;

  const factory AgentLink.agentProject({
    required String id,
    required String fromId,
    required String toId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
  }) = AgentProjectLink;

  /// Links a template to its assigned soul document.
  /// [fromId] = template ID, [toId] = soul document ID.
  const factory AgentLink.soulAssignment({
    required String id,
    required String fromId,
    required String toId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
  }) = SoulAssignmentLink;

  factory AgentLink.fromJson(Map<String, dynamic> json) =>
      _$AgentLinkFromJson(json);
}

/// Shared selection helper for resolving the "primary" link when multiple
/// links of the same type point at the same target.
///
/// Sorts by `createdAt` descending, then `id` descending, and returns the
/// first element. This is the canonical tie-breaking strategy used by task
/// agent services, project agent services, and the activity monitor.
extension AgentLinkSelection on List<AgentLink> {
  /// Returns a new list ordered by selection priority.
  ///
  /// Links are sorted by `createdAt` descending, then `id` descending.
  List<AgentLink> orderedPrimaryFirst() {
    final sorted = toList()
      ..sort((a, b) {
        final byCreatedAt = b.createdAt.compareTo(a.createdAt);
        if (byCreatedAt != 0) return byCreatedAt;
        return b.id.compareTo(a.id);
      });
    return sorted;
  }

  /// Returns the most recently created link, breaking ties by ID.
  ///
  /// Throws [StateError] if the list is empty.
  AgentLink selectPrimary() {
    if (isEmpty) {
      throw StateError('Cannot select a primary link from an empty list.');
    }
    final sorted = orderedPrimaryFirst();
    return sorted.first;
  }
}
