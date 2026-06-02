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

  /// Reference from a consuming message ([fromId]) to a content-addressed
  /// payload ([toId] = the payload's `contentDigest`), per ADR 0020.
  ///
  /// Provenance and canonical-ordering metadata live **on the reference, not
  /// the payload**, so one shared payload can be pointed at by many references
  /// with distinct provenance:
  /// - [contentEntryId] — the originating journal entity (provenance);
  /// - [sourceCreatedAt] — the source's chronological position, snapshotted at
  ///   capture time so the canonical assembly order is a pure function of the
  ///   log and never a live read of the (mutable) journal.
  ///
  /// Both are nullable: links written before ADR 0020 — and non-input payload
  /// references — simply carry neither.
  const factory AgentLink.messagePayload({
    required String id,
    required String fromId,
    required String toId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    String? contentEntryId,
    DateTime? sourceCreatedAt,
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

  /// Links a submitted Daily OS capture to one parsed item.
  /// [fromId] = capture ID, [toId] = parsed item ID.
  const factory AgentLink.captureToParsedItem({
    required String id,
    required String fromId,
    required String toId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
  }) = CaptureToParsedItemLink;

  /// Links one parsed Daily OS capture item to its matched task.
  /// [fromId] = parsed item ID, [toId] = task ID.
  const factory AgentLink.parsedItemToTask({
    required String id,
    required String fromId,
    required String toId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
  }) = ParsedItemToTaskLink;

  /// Links a submitted Daily OS capture to its drafted plan.
  /// [fromId] = capture ID, [toId] = day-plan entity ID.
  const factory AgentLink.captureToPlan({
    required String id,
    required String fromId,
    required String toId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
  }) = CaptureToPlanLink;

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

  /// Links a day agent to the day it plans.
  /// [fromId] = agent ID, [toId] = day ID. Lets `slots.activeDayId` be derived
  /// from the synced log like the other active-slot links (State-as-Projection).
  const factory AgentLink.agentDay({
    required String id,
    required String fromId,
    required String toId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
  }) = AgentDayLink;

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

/// Soft-delete helper for [AgentLink] union variants.
///
/// Freezed unions require exhaustive `.map()` calls even when every case does
/// the same thing. This extension centralizes the boilerplate.
extension AgentLinkSoftDelete on AgentLink {
  /// Returns a copy with [deletedAt] and [updatedAt] set to [at].
  AgentLink softDeleted(DateTime at) => map(
    basic: (l) => l.copyWith(deletedAt: at, updatedAt: at),
    agentState: (l) => l.copyWith(deletedAt: at, updatedAt: at),
    messagePrev: (l) => l.copyWith(deletedAt: at, updatedAt: at),
    messagePayload: (l) => l.copyWith(deletedAt: at, updatedAt: at),
    toolEffect: (l) => l.copyWith(deletedAt: at, updatedAt: at),
    agentTask: (l) => l.copyWith(deletedAt: at, updatedAt: at),
    captureToParsedItem: (l) => l.copyWith(deletedAt: at, updatedAt: at),
    parsedItemToTask: (l) => l.copyWith(deletedAt: at, updatedAt: at),
    captureToPlan: (l) => l.copyWith(deletedAt: at, updatedAt: at),
    templateAssignment: (l) => l.copyWith(deletedAt: at, updatedAt: at),
    improverTarget: (l) => l.copyWith(deletedAt: at, updatedAt: at),
    agentProject: (l) => l.copyWith(deletedAt: at, updatedAt: at),
    agentDay: (l) => l.copyWith(deletedAt: at, updatedAt: at),
    soulAssignment: (l) => l.copyWith(deletedAt: at, updatedAt: at),
  );
}
