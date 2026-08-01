import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';

/// How long a row may stay in the agent store.
enum AgentRetentionClass {
  /// The user's own material. Never deleted by retention, at any age.
  userAuthored,

  /// Derived, but kept anyway — each for a stated reason, so "we decided
  /// against it" never looks like "we didn't get to it".
  keptDerived,

  /// Derived and bounded by age.
  ageBounded,

  /// Derived, and *intended* to be bounded — but not yet swept.
  ///
  /// Observations sit inside the agent's causal message DAG: `message_prev`
  /// edges, agent-state heads, and content-addressed payloads shared through
  /// `messagePayload` links (which are user content, and referenced by link
  /// rather than by `contentEntryId`). Deleting one safely means answering
  /// what happens to each of those. That is a subsystem's worth of invariants
  /// and gets its own change; classifying them here records the intent without
  /// pretending the sweep exists.
  observation,
}

/// What the agent store may forget, and after how long.
///
/// The store holds two very different kinds of row under one table. **User
/// authored** rows are the user's own material — captures, day plans, day
/// summaries, directives, knowledge, reports and the identities that own them.
/// **Derived** rows are the machine's working residue: observations it wrote
/// about itself, status events it raised.
///
/// [classify] is **exhaustive over the entity union**, so a new
/// `AgentDomainEntity` variant does not compile until someone decides what
/// happens to it. That is deliberate: a wildcard would let a new machine-derived
/// row start accumulating forever with no test and no compiler failure.
class AgentRetentionPolicy {
  const AgentRetentionPolicy({
    this.dayStatusEvents = const Duration(days: 90),
    this.batchSize = 500,
    this.maxBatchesPerSweep = 20,
  });

  /// How long raised day-status events are kept.
  ///
  /// The digest reads them from its watermark (plus 12h sync-lag slack), so a
  /// window measured in months is far beyond any read that exists.
  final Duration dayStatusEvents;

  /// Rows deleted per statement. Each batch commits on its own.
  final int batchSize;

  /// Batches per type per sweep, so one start-up pass on a very large store
  /// stays bounded and the remainder is collected on the next start.
  final int maxBatchesPerSweep;

  /// What retention may do with [entity].
  ///
  /// Exhaustive by construction — `map` has no fallback branch, so adding a
  /// variant is a compile error until it is classified here.
  AgentRetentionClass classify(AgentDomainEntity entity) => entity.map(
    // ── The user's own material ──────────────────────────────────────────
    capture: (_) => AgentRetentionClass.userAuthored,
    parsedItem: (_) => AgentRetentionClass.userAuthored,
    dayPlan: (_) => AgentRetentionClass.userAuthored,
    daySummary: (_) => AgentRetentionClass.userAuthored,
    dayDirective: (_) => AgentRetentionClass.userAuthored,
    plannerKnowledge: (_) => AgentRetentionClass.userAuthored,
    agentReport: (_) => AgentRetentionClass.userAuthored,
    agentReportHead: (_) => AgentRetentionClass.userAuthored,
    soulDocument: (_) => AgentRetentionClass.userAuthored,
    soulDocumentVersion: (_) => AgentRetentionClass.userAuthored,
    soulDocumentHead: (_) => AgentRetentionClass.userAuthored,
    agentTemplate: (_) => AgentRetentionClass.userAuthored,
    agentTemplateVersion: (_) => AgentRetentionClass.userAuthored,
    agentTemplateHead: (_) => AgentRetentionClass.userAuthored,
    evolutionSession: (_) => AgentRetentionClass.userAuthored,
    evolutionSessionRecap: (_) => AgentRetentionClass.userAuthored,
    evolutionNote: (_) => AgentRetentionClass.userAuthored,

    // ── Identity and live state: deleting these breaks the agent ─────────
    agent: (_) => AgentRetentionClass.keptDerived,
    agentState: (_) => AgentRetentionClass.keptDerived,
    scheduledWake: (_) => AgentRetentionClass.keptDerived,
    unknown: (_) => AgentRetentionClass.keptDerived,

    // ── Derived, kept deliberately ───────────────────────────────────────
    // weekRollup: one register per ISO week (~52 rows/year) and the digest's
    // only month-scale trend source. Bounded and load-bearing.
    weekRollup: (_) => AgentRetentionClass.keptDerived,
    // wakeTokenUsage: the template detail page aggregates it over ALL TIME.
    // Pruning would silently rewrite a number the user can read off the
    // screen; compacting into per-month aggregates is the way to bound it.
    wakeTokenUsage: (_) => AgentRetentionClass.keptDerived,
    // The audit trail behind proposals the user accepted or rejected.
    changeSet: (_) => AgentRetentionClass.keptDerived,
    changeDecision: (_) => AgentRetentionClass.keptDerived,
    attentionRequest: (_) => AgentRetentionClass.keptDerived,
    attentionClaimDisposition: (_) => AgentRetentionClass.keptDerived,
    attentionAward: (_) => AgentRetentionClass.keptDerived,
    standingAgreement: (_) => AgentRetentionClass.keptDerived,
    projectRecommendation: (_) => AgentRetentionClass.keptDerived,

    // ── Derived and bounded ──────────────────────────────────────────────
    dayStatusEvent: (_) => AgentRetentionClass.ageBounded,
    // Only observations are bounded; summaries and every other message kind
    // are the agent's durable memory and stay.
    agentMessage: (e) => e.kind == AgentMessageKind.observation
        ? AgentRetentionClass.observation
        : AgentRetentionClass.keptDerived,
    // A payload's fate follows the message that owns it, which the sweep
    // resolves by id — never by age of its own.
    agentMessagePayload: (_) => AgentRetentionClass.keptDerived,
  );

  /// The age horizon for [entity], or null when nothing bounds it by age
  /// today.
  ///
  /// `observation` yields null deliberately: until the sweep exists, dropping
  /// inbound observations at the horizon would delete rows this device never
  /// prunes locally, which is divergence for no gain.
  Duration? horizonFor(AgentDomainEntity entity) => switch (classify(entity)) {
    AgentRetentionClass.ageBounded => dayStatusEvents,
    AgentRetentionClass.observation ||
    AgentRetentionClass.userAuthored ||
    AgentRetentionClass.keptDerived => null,
  };

  /// Whether an inbound synced [entity] is already past this device's horizon,
  /// and so should not be materialized at all.
  ///
  /// Retention is a hard local delete with no tombstone, so without this a peer
  /// returning from a long absence would re-insert exactly what every device
  /// had agreed to forget, only for the next sweep to remove it again.
  ///
  /// Age is the only bound that exists today; see [horizonFor] for what is and
  /// is not swept.
  bool isBeyondHorizon({
    required AgentDomainEntity entity,
    required DateTime createdAt,
    required DateTime now,
  }) {
    final horizon = horizonFor(entity);
    if (horizon == null) return false;
    return createdAt.isBefore(now.subtract(horizon));
  }
}
