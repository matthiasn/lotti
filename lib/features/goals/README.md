# Goals

The deterministic core of **goal-driven agents**: the vocabulary a long-term
personal goal is written in, and the pure-Dart evaluation that decides — at
zero inference cost — whether the user is on track.

This feature is landing in phases (see the ADR cluster below). What exists
today:

- The **vocabulary lives in `lib/classes/`** (`goal_criterion.dart`,
  `goal_window.dart`, `goal_enums.dart`, `goal_nudge_models.dart`,
  `goal_progress_models.dart`) — the shared-vocabulary rule that lets the
  agent entity union embed these types without `features/agents` depending
  on a feature (the `day_plan.dart` precedent).
  `GoalCriterion.fromAutoCompleteRule` imports an existing habit rule as a
  goal seed.
- `evaluation/` — `GoalProgressEvaluator`, a pure fold over a
  `GoalSignalWindow` of daily aggregates, and `GoalTrackPolicy`, which turns
  attainment, pace, grace, and data coverage into a `GoalTrackStatus`.
- `validation/` — `GoalSpecValidator`, the persistence-path gate: raw-JSON
  checks (fractional counts a decode would silently truncate) plus
  structural checks (empty composites, unsatisfiable quotas), applied
  before a criteria tree is stored or evaluated.

Nothing here touches the database, the network, or the agent runtime: the
evaluator is the Phase A of the two-tier wake design (ADR 0054) and is
consumed today by its unit tests and by the goal-agent evaluation harness
(`test/features/agents/eval/goal/`), which cross-checks its fixture
arithmetic against this evaluator.

The runtime (agent kind, wake wiring, entities), the banner surface, and the
conversation UI follow in later increments; the plan of record is
`docs/implementation_plans/2026-08-08_goal_agents_design.md`.

Decisions: ADRs
[0053](../../../docs/adr/0053-goal-driven-agents-per-goal-producers.md),
[0054](../../../docs/adr/0054-deterministic-first-two-tier-wakes.md),
[0055](../../../docs/adr/0055-banner-nudge-attention-channel.md),
[0056](../../../docs/adr/0056-need-to-know-visual-brief-boundary.md),
[0057](../../../docs/adr/0057-decade-scale-agent-memory.md).
A `knowledge/` concept will be added when the runtime ships and there is
running behavior to document.
