# ADR 0057: Decade-Scale Agent Memory

- Status: Proposed
- Date: 2026-08-08

## Context

Goal agents live for up to ten years. The existing memory substrate is genuinely good — content-
addressed capture (ADR 0020), never-destructive prefix-coverage compaction (ADR 0017), keyed
durable knowledge (`PlannerKnowledgeEntity`), author-time memory links (ADR 0026) — but several
of its *policies* were tuned for task agents that live weeks, and are actively hostile to a
decade-long identity (verified in code, 2026-08-08):

- Every task-agent wake loads **all** observations then keeps the newest 20; the critical-
  observation self-review scans only those 20 (`task_agent_execute.dart`,
  `task_agent_context_builder.dart`).
- Observations are pruned raw at 180 days (`agent_retention_policy.dart`) — "you always stall in
  November" is precisely the observation that dies.
- `maxAgentMessages: 20000` makes the retention sweep **skip the agent entirely**; a daily-waking
  agent crosses the threshold around year eight and then grows unbounded *and* unpruned.
- Compaction is a single rolling prose summary; `AgentMessageEntity.summaryDepth` exists and
  nothing builds a hierarchy — a decade compresses into one blob of unbounded lossiness.
- The 50k/20k compaction watermarks assume a warm provider prefix cache; a once-daily goal agent
  is almost always a cold prefill.
- Memory is write-only in practice for non-day agents: `search_memory` is wired only for the day
  agent, planner knowledge is read only by the day agent (ADR 0052: "Task agents do not read
  it"), memory links are never traversed.

## Decision

1. **Fix the read side first — by generalization, not new entities.** Goal agents get
   `search_memory` via a shared helper extracted from the day-agent tool handlers, and read
   `PlannerKnowledgeEntity` scoped to their own `agentId` (hooks ≤120 chars always injected;
   compaction-exempt — unchanged semantics). A `remember` tool writes user-stated facts straight
   to `confirmed`, agent-inferred facts to `proposed`.

2. **Observation reads are bounded and priority-aware.** Never read-all: a repository method
   returns "recent N plus all critical-priority", and the context builder passes an explicit
   limit from day one. (The task-agent read-all site receives the same one-line fix as an
   unrelated cleanup.)

3. **Epoch summaries make the hierarchy real.** Quarterly, the agent's raw quarter (observations,
   dialogue, report evolution) is folded into one depth-1 epoch summary message; yearly, depth-1
   epochs fold into a depth-2 year summary — using the existing `summaryDepth` field and the
   ADR 0017 checkpoint machinery unchanged underneath. This ADR **amends 0017** by adding a
   hierarchy above its rolling summary; the rolling mechanism itself is untouched. Epochs are
   collapsible dividers in history UI and retrievable via `search_memory`.

4. **Retention becomes distill-then-prune.** Raw observations older than 180 days become
   prunable **only after** their quarter has been distilled (epoch summary written, durable
   facts promoted to keyed knowledge). Pruning without distillation is a policy violation, not a
   space optimization. The `goalProgress` register (ADR 0053) is retention-exempt — at ~1 MB per
   goal-decade it *is* the quantitative history.

5. **The 20000-message skip becomes a bounded prune.** Instead of skipping oversized agents, the
   sweep prunes only the summary-covered prefix (checkpoint-frontier aware, ancestor-closed,
   protected heads untouched) — turning the deadlock into the intended steady state: a bounded
   raw tail behind a summary chain.

6. **Cold-prefill-sized context.** Goal-agent Phase B wakes pass per-call compaction budgets
   (`budget: 12000, retainTokens: 4000` — the parameters already exist on
   `compactAndAssemble`) and target ≤8K input tokens: spec head render, the last ~8
   `goalProgress` periods as a table, active-nudge state, knowledge hooks, compacted tail. The
   50k/20k defaults remain for task agents, whose warm-cache assumption holds.

## Consequences

- A ten-year goal agent's log stays bounded (raw tail + epoch chain + keyed facts + register),
  queryable ("what did I conclude last January?" is a search over epochs and knowledge, not a
  prayer), and honest — lossiness happens only at explicit fold boundaries, never by silent
  deletion.
- Memory stops being write-only for non-day agents; ADR 0026 memory links become traversable in
  practice through search.
- Quarterly/yearly distillation adds a scheduled Phase B wake four or five times a year per goal
  — negligible cost, and it doubles as the agent's own retrospective ("your year in this goal").
- The day agent keeps its existing behavior; extractions are shared code, not semantic changes.

## Related

- [ADR 0017: Deterministic Log Compaction](./0017-deterministic-log-compaction.md) — amended (hierarchy above the rolling summary)
- [ADR 0020: Agent Input Capture](./0020-agent-input-capture.md)
- [ADR 0022: Long-Lived Daily OS Planner](./0022-long-lived-daily-os-planner.md) — the two-loop memory model and knowledge store this reuses
- [ADR 0026: Author-Time Memory Links](./0026-author-time-memory-links.md)
- [ADR 0052: Agent Directive Constitution](./0052-agent-directive-constitution.md)
- [ADR 0053: Goal-Driven Agents — Per-Goal Durable Producers](./0053-goal-driven-agents-per-goal-producers.md)
