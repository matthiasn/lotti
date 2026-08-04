/// What the agent store may forget, and after how long.
///
/// The store holds two very different kinds of row under one table. **User
/// authored** rows are the user's own material — captures, day plans, day
/// summaries, directives, knowledge, reports and the identities that own them.
/// **Derived** rows are the machine's working residue: observations it wrote
/// about itself, status events it raised.
class AgentRetentionPolicy {
  const AgentRetentionPolicy({
    this.dayStatusEvents = const Duration(days: 90),
    this.observations = const Duration(days: 180),
    this.agentsPerSweep = 25,
    this.maxAgentsPerSweep = 500,
    this.maxAgentMessages = 20000,
    this.batchSize = 500,
    this.maxBatchesPerSweep = 20,
  });

  /// How long raised day-status events are kept.
  ///
  /// The digest reads them from its watermark (plus 12h sync-lag slack), so a
  /// window measured in months is far beyond any read that exists.
  final Duration dayStatusEvents;

  /// How long an agent's own observations are kept.
  ///
  /// Twice the status-event window: observations are the agent's working notes
  /// about itself, and a wake may still summarise several months back. Nothing
  /// reads them by age after that, but the cost of keeping them a while longer
  /// is one row, whereas deleting one early loses context permanently.
  final Duration observations;

  /// Agents fetched per page while walking toward the delete budget.
  final int agentsPerSweep;

  /// Hard ceiling on agents examined in one sweep, so a store where nothing is
  /// prunable still ends in bounded time rather than walking every agent.
  final int maxAgentsPerSweep;

  /// An agent whose message log is longer than this is skipped rather than
  /// partially pruned — ancestor-closure needs the chain from its root, and a
  /// truncated view would hide the parents that block a delete.
  final int maxAgentMessages;

  /// Rows deleted per statement. Each batch commits on its own.
  final int batchSize;

  /// Batches per type per sweep, so one start-up pass on a very large store
  /// stays bounded and the remainder is collected on the next start.
  final int maxBatchesPerSweep;
}
