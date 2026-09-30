import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';

/// What the maintenance pass does for one live person's agent.
enum RelationshipAgentReconciliation {
  /// The agent is where the user left it.
  none,

  /// Create the missing agent.
  create,

  /// Set the agent active.
  activate,

  /// Set the agent dormant: the user's last word was a pause.
  pause,

  /// Destroy the agent: the user's last word was a destroy or a delete.
  destroy,
}

/// Where the user's latest word puts a live [person]'s agent (ADR 0111;
/// `specs/tla/RelationshipAgentLifecycle.tla`, `CanReconcile` and
/// `Target`).
///
/// The user asks for the agent by marking the person important
/// (`importantSince`) or by resuming the agent (`userResumedAt`), and stops
/// it from the agent controls (`userStoppedAt`, with the lifecycle that stop
/// set). The later of the two decides:
///
/// - a stop newer than every ask keeps the agent stopped;
/// - otherwise an important person's agent is active;
/// - an unimportant person's agent is left as it is (Phase A keeps it quiet).
///
/// [identity] is the agent this device holds, or null for none. [deletedAt]
/// is when this device deleted it (`deleted_agents`), and the agent is
/// created again only for a mark newer than that. [conflicting] are the
/// person's versions held as open sync conflicts: while there are any, the
/// pass only ever stops the agent, judging the newest mark among them.
///
/// A mark or resume from before these stamps existed reads as the oldest
/// possible ask, and a destroy from before them as no stop at all, so an
/// important person's agent that an earlier build lost is brought back.
RelationshipAgentReconciliation reconcileRelationshipAgent({
  required RelationshipData person,
  required AgentIdentityEntity? identity,
  required DateTime? deletedAt,
  Iterable<RelationshipData> conflicting = const [],
}) {
  final openConflict = conflicting.isNotEmpty;
  if (identity == null) {
    if (openConflict || !person.important) {
      return RelationshipAgentReconciliation.none;
    }
    final markedAt = person.importantSince;
    final deletedAfterMark =
        deletedAt != null && (markedAt == null || !markedAt.isAfter(deletedAt));
    return deletedAfterMark
        ? RelationshipAgentReconciliation.none
        : RelationshipAgentReconciliation.create;
  }

  final asked = _latest([
    person.importantSince,
    identity.userResumedAt,
    for (final version in conflicting) version.importantSince,
  ]);
  final stoppedAt = identity.userStoppedAt;
  final stopWins =
      stoppedAt != null && (asked == null || stoppedAt.isAfter(asked));
  final AgentLifecycle target;
  if (stopWins) {
    target = identity.userStopLifecycle ?? AgentLifecycle.destroyed;
  } else if (person.important) {
    target = AgentLifecycle.active;
  } else {
    return RelationshipAgentReconciliation.none;
  }
  if (target == identity.lifecycle) return RelationshipAgentReconciliation.none;
  return switch (target) {
    AgentLifecycle.active when openConflict =>
      RelationshipAgentReconciliation.none,
    AgentLifecycle.active => RelationshipAgentReconciliation.activate,
    AgentLifecycle.dormant => RelationshipAgentReconciliation.pause,
    AgentLifecycle.destroyed => RelationshipAgentReconciliation.destroy,
    AgentLifecycle.created => RelationshipAgentReconciliation.none,
  };
}

DateTime? _latest(Iterable<DateTime?> stamps) {
  DateTime? latest;
  for (final stamp in stamps) {
    if (stamp != null && (latest == null || stamp.isAfter(latest))) {
      latest = stamp;
    }
  }
  return latest;
}
