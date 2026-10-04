import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/agents/sync/agent_concurrent_resolver.dart';

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

/// The stamp of a mark made at [now] on a device that holds [identity] as
/// the person's agent, deleted it at [deletedAt] (`deleted_agents`) and
/// stored [previousMark] as the person's last mark: [now], or a microsecond
/// past the latest of those decisions when [now] is not later
/// ([decisionStampAfter]). The identity's stamps came from other devices'
/// clocks too. A stop a peer's clock put ahead of this one, which the user
/// has since seen and overruled by marking the person again, must lose to
/// that mark; stamped plainly [now], the mark would read as older than the
/// stop, and the pass would keep the agent stopped until this clock caught
/// up (ADR 0111).
DateTime markStampAfter(
  DateTime now, {
  required AgentIdentityEntity? identity,
  required DateTime? deletedAt,
  DateTime? previousMark,
}) => decisionStampAfter(now, [
  previousMark,
  deletedAt,
  if (identity != null) ...[
    identityLifecycleAt(identity),
    identity.userStoppedAt,
    identity.userResumedAt,
  ],
]);

DateTime? _latest(Iterable<DateTime?> stamps) {
  DateTime? latest;
  for (final stamp in stamps) {
    if (stamp != null && (latest == null || stamp.isAfter(latest))) {
      latest = stamp;
    }
  }
  return latest;
}
