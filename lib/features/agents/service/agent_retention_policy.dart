import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';

/// What the agent store may forget, and after how long.
///
/// The store holds two very different kinds of row under one table. **User
/// authored** rows are the user's own material — captures, day plans, day
/// summaries, directives, knowledge, reports and the identities that own them.
/// **Derived** rows are the machine's working residue: observations it wrote
/// about itself, status events it raised, run logs. Only derived rows are
/// retention-eligible, and the split is spelled out here rather than left to a
/// sweep's SQL, so adding an entity type forces a decision instead of silently
/// inheriting one.
///
/// Deliberately NOT eligible, with reasons, because "we didn't get to it" and
/// "we decided against it" must not look the same from the outside:
///
/// * `weekRollup` — one register per ISO week (~52 rows/year) and the digest's
///   only month-scale trend source. Bounded and load-bearing.
/// * `wakeTokenUsage` — the template detail page aggregates it over **all
///   time**. Pruning would silently rewrite a number the user can read off the
///   screen. Compacting old rows into per-month aggregates is the way to bound
///   it; that is a follow-up, not a silent deletion.
/// * `changeSet` / `changeDecision` / `attentionRequest` and its dispositions —
///   the audit trail behind proposals the user accepted or rejected.
/// * `saga_log` — the table has no writer anywhere in the app today. Sweeping
///   it would mean inventing a terminal-status vocabulary for rows that never
///   arrive; it earns a policy when it earns a writer.
/// * Everything user-authored (see [userAuthoredTypes]).
class AgentRetentionPolicy {
  const AgentRetentionPolicy({
    this.dayStatusEvents = const Duration(days: 90),
    this.wakeRunLog = const Duration(days: 90),
    this.observationsPerAgent = 200,
    this.batchSize = 500,
    this.maxBatchesPerSweep = 20,
  });

  /// How long raised day-status events are kept.
  ///
  /// The digest reads them from its watermark (plus 12h sync-lag slack), so a
  /// window measured in months is far beyond any read that exists. They are
  /// kept longer than the run log because they carry the coordinator's
  /// reasoning about a day, which is worth having when a user asks why.
  final Duration dayStatusEvents;

  /// How long wake-run log rows are kept. Read by evaluation surfaces over
  /// windows of at most 30 days.
  final Duration wakeRunLog;

  /// Observations retained per agent, newest first.
  ///
  /// Count-based rather than age-based on purpose: the bound this needs to
  /// hold is "the coordinator's observation history does not grow without
  /// limit", and a count says that directly regardless of how heavily the app
  /// is used. The prompt replays at most 20 and the wake reads at most 40, so
  /// this leaves an order of magnitude of headroom over any read.
  final int observationsPerAgent;

  /// Rows deleted per statement. Each batch commits on its own.
  final int batchSize;

  /// Batches per type per sweep, so one start-up pass on a very large store
  /// stays bounded and the remainder is collected on the next start.
  final int maxBatchesPerSweep;

  /// Entity types that are the user's own material and are never deleted by
  /// retention, whatever their age.
  static const Set<String> userAuthoredTypes = {
    AgentEntityTypes.capture,
    AgentEntityTypes.parsedItem,
    AgentEntityTypes.dayPlan,
    AgentEntityTypes.daySummary,
    AgentEntityTypes.dayDirective,
    AgentEntityTypes.plannerKnowledge,
    AgentEntityTypes.agentReport,
    AgentEntityTypes.agentReportHead,
    AgentEntityTypes.soulDocument,
    AgentEntityTypes.soulDocumentVersion,
    AgentEntityTypes.soulDocumentHead,
  };

  /// The age horizon for [type], or null when the type is not age-eligible.
  ///
  /// Observations are absent here on purpose: they are bounded by count
  /// ([observationsPerAgent]), not by age.
  Duration? horizonFor(String type) => switch (type) {
    AgentEntityTypes.dayStatusEvent => dayStatusEvents,
    _ => null,
  };

  /// Whether an inbound synced [type] created at [createdAt] is already past
  /// this device's horizon, and so should not be materialized at all.
  ///
  /// Retention is a hard local delete with no tombstone, so without this a
  /// peer returning from a long absence would re-insert exactly what every
  /// device had agreed to forget, only for the next sweep to remove it again.
  bool isBeyondHorizon({
    required String type,
    required DateTime createdAt,
    required DateTime now,
  }) {
    final horizon = horizonFor(type);
    if (horizon == null) return false;
    return createdAt.isBefore(now.subtract(horizon));
  }
}

/// Subtype under which observation messages are stored (`AgentMessageKind`
/// serializes to the `subtype` column).
final String observationSubtype = AgentMessageKind.observation.name;
