---
type: Feature Module
title: Goal Agents — Deterministic Runtime
description: The Phase A tier of goal-driven agents — evidence- and cadence-triggered evaluation of goal criteria into convergent daily progress registers, with escalation wakes armed only on status transitions.
resource: ../../lib/features/goals
tags: [goals, agents, runtime, wake, evaluation]
status: draft
generated: { by: claude-code/fable-5, at: 2026-08-09T02:30:00Z }
stale_after: 2026-10-12
sources:
  - id: goals-src
    resource: ../../lib/features/goals
    title: Goals feature source
    last_modified: 2026-08-09
  - id: phase-a
    resource: ../../lib/features/goals/runtime/goal_agent_phase_a.dart
    title: GoalAgentPhaseA — the deterministic tick
    last_modified: 2026-08-09
  - id: signal-reader
    resource: ../../lib/features/goals/evaluation/goal_signal_reader.dart
    title: GoalSignalReader — journal-backed daily aggregates
    last_modified: 2026-08-09
  - id: evaluator
    resource: ../../lib/features/goals/evaluation/goal_progress_evaluator.dart
    title: GoalProgressEvaluator — pure criteria-tree fold
    last_modified: 2026-08-09
  - id: policy
    resource: ../../lib/features/goals/evaluation/goal_track_policy.dart
    title: GoalTrackPolicy — status derivation rules
    last_modified: 2026-08-09
  - id: vocabulary
    resource: ../../lib/classes/goal_criterion.dart
    title: GoalCriterion tree (shared vocabulary in lib/classes)
    last_modified: 2026-08-09
  - id: sync-dispatcher
    resource: ../../lib/features/goals/sync/goal_signal_sync_dispatcher.dart
    title: GoalSignalSyncDispatcher — the sync blind-spot bridge
    last_modified: 2026-08-09
  - id: adr-0054
    resource: ../../docs/adr/0054-deterministic-first-two-tier-wakes.md
    title: "ADR 0054: Deterministic-First Two-Tier Wakes"
    last_modified: 2026-08-08
---

# Goal Agents — Deterministic Runtime

One long-lived agent per user goal (ADR 0053), built deterministic-first
(ADR 0054): the invariant is that **a tick that changes nothing costs €0
and writes no messages**. What runs today is Phase A — the model-free
tier; the LLM tier (Phase B) consumes the escalation wakes this tier arms
and is a later increment, as are the banner surface (ADR 0058) and the
goal chat.

## Runtime flow

```mermaid
flowchart TD
    subgraph triggers [Triggers — every device]
        SIG[localUpdateStream signals\nleaf dataTypes, habitIds,\nmeasurable ids] --> ORCH[WakeOrchestrator\nsubscription match]
        SYNC[syncUpdateStream] --> DISP[GoalSignalSyncDispatcher]
        CAD[cadence ScheduledWakeEntity\nworkspace goal-cadence,\ndaily at 06:00 local] --> MGR[ScheduledWakeManager]
    end
    ORCH --> PA[GoalAgentPhaseA.execute]
    DISP --> PA
    MGR --> PA
    PA --> HEAD[spec head → active version\nno head = clean no-op]
    HEAD --> REARM[re-arm cadence\nrecurrence by re-arm]
    REARM --> READ[GoalSignalReader\njournal → GoalSignalWindow]
    READ --> EVAL[GoalProgressEvaluator\n+ GoalTrackPolicy]
    EVAL --> REG[upsert goalProgress register\ngoal_progress:agent:evaluation-day\nrecompute, never accumulate]
    REG --> TRANS{status transitioned vs\nlast persisted status?}
    TRANS -- no --> DONE[return — the €0 no-op]
    TRANS -- yes --> ESC[arm escalation wake\ngoal-escalation:periodKey,\nUTC deadline, lease-elected]
    ESC --> NUDGE[nudge ScheduledWakeManager\nrequestCheck on arming device]
```

## Invariants

- **Convergence over coordination.** The register row id is deterministic
  per `(agentId, evaluation-day)`; every device recomputes the same
  content from the same journal, so concurrent Phase A runs converge
  instead of duplicating. A recompute over a synced row carries that
  row's vector clock forward — dropping it would make the write causally
  concurrent with its own input.
- **Transitions compare against the last persisted status** — today's own
  earlier row first, yesterday's otherwise — so an escalation wake that
  re-runs Phase A is a no-op, not a self-re-arming loop.
- **Grace history is a consecutive, same-spec-version streak**: prior-row
  collection stops at the first missing day and at the first row computed
  under a superseded spec version.
- **Borrowed data semantics.** Quantitative day totals follow the health
  charts' per-type aggregation (`cumulative_step_count` day total is the
  daily max), point-sample types keep the day's latest sample, habit days
  follow the habits UI's latest-completion-per-day collapse with
  success-only counting, and day keys re-stamp the local calendar date as
  midnight UTC. The goal agent must never disagree with the chart the
  user is looking at.
- **Phase B is reachable only through the lease.** Sync-received signals
  run Phase A directly (the orchestrator deliberately listens local-only);
  anything LLM-worthy becomes a `goal-escalation:<periodKey>` scheduled
  wake whose lease election picks exactly one device.
- **Calendar arithmetic is component-based** (`DateTime(y, m, d ± n)`),
  never `Duration` math, so DST transitions cannot shift the cadence hour,
  skip a prior-day register key, or truncate a 25-hour day's query range.

## Gotchas

- `agent_wiring.dart` silently routes unregistered kinds to the
  task-agent workflow; the bootstrap merges the Daily OS and Goals runner
  maps, and `test/app_bootstrap_test.dart` pins both registrations — do
  not turn that merge back into a replacement.
- Subscriptions are in-memory: `GoalRuntimeMaintenance.restoreSubscriptions`
  rebuilds them at startup. A goal agent synced in mid-session is not
  subscribed until restart (known limitation, tracked for the Phase B
  increment).
- Imported workout rules currently produce metric leaves whose dataTypes
  only match `QuantitativeEntry` rows; workout-entry signals are a
  documented follow-up.

## Related

- [Agents](agents/) — the shared runtime this plugs into.
- [Daily OS](daily_os_next/) — the reference plug-in implementation.
- ADRs 0053–0058 in `docs/adr/` — the decision record for this feature.
