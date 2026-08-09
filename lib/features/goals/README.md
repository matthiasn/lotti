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
- `GoalSpecValidator` (in `lib/classes/goal_spec_validator.dart`, beside
  the vocabulary it validates) — the decode-boundary gate, invoked from
  `AgentDomainEntity.fromJson` so every path (Matrix sync, storage reads)
  passes it: raw-JSON checks (fractional counts a decode would silently
  truncate) plus structural checks (empty composites, unsatisfiable
  quotas, blank identifiers, duplicate criterion ids).

The deterministic runtime RUNS (Phase A of ADR 0054): `runtime/` holds the
per-tick executor (`GoalAgentPhaseA`) and startup maintenance, `sync/` the
synced-signal dispatcher, `service/` transactional goal creation, and
`state/` the providers that plug the `goal_agent` kind into the shared
agent runtime (merged in `app_bootstrap.dart`). Persistence entities live
on `AgentDomainEntity` (`goalSpecVersion`/`goalSpecHead`/`goalProgress`/
`goalNudge`) with `GoalSpecValidator` gating every decode path.

The LLM tier (Phase B), the banner surface (procedural text banners,
ADR 0058), and the conversation UI follow in later increments; the plan of
record is `docs/implementation_plans/2026-08-08_goal_agents_design.md`.

Runtime map: [knowledge/features/goals.md](../../../knowledge/features/goals.md).

Decisions: ADRs
[0053](../../../docs/adr/0053-goal-driven-agents-per-goal-producers.md),
[0054](../../../docs/adr/0054-deterministic-first-two-tier-wakes.md),
[0055](../../../docs/adr/0055-banner-nudge-attention-channel.md),
[0056](../../../docs/adr/0056-need-to-know-visual-brief-boundary.md),
[0057](../../../docs/adr/0057-decade-scale-agent-memory.md),
[0058](../../../docs/adr/0058-procedural-text-banners-no-generative-imagery.md).
The runtime's knowledge concept is
[knowledge/features/goals.md](../../../knowledge/features/goals.md).
