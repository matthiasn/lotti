# Planning Agent Architecture — Overview

- Status: Direction accepted; implementation pending
- Date: 2026-06-07
- Branch: `doc/planning_agent_architecture`

This is the orientation doc that ties together the Daily OS planning-agent
direction. It connects three pillars and points at the canonical decision
documents. Read this first, then the linked ADRs and the detailed implementation
plan.

## The three pillars

### 1. Long-lived planner identity

[ADR 0022](../adr/0022-long-lived-daily-os-planner.md) replaces one `day_agent`
identity per calendar date with **one durable planner** that owns explicit
`dayId` workspaces. The per-day model was amnesia: each day was a separate mind
with no memory of the last. The planner now learns across days while every
day-specific wake and tool call stays scoped to a concrete `dayId`.

### 2. Durable knowledge + two-loop learning

The detailed plan
([2026-06-07_long_lived_daily_os_planner.md](./2026-06-07_long_lived_daily_os_planner.md),
"Durable Planner Knowledge" section) adds a compaction-exempt
`PlannerKnowledgeEntity` — keyed, supersedable, user-confirmed — so the planner
**memorizes what the user tells it** instead of dissolving it in LLM log
compaction. Learning runs on two loops:

- **Fast loop (daily, unsupervised):** raw day inputs and observations accrue as
  episodic memory, aggressively compacted.
- **Slow loop (weekly, the one-on-one):** `TemplateEvolutionWorkflow` — not yet
  wired for `day_agent` — consolidates recurring observations into durable,
  user-approved knowledge.

The user wants both daily learning and the weekly one-on-one; promotion (daily →
durable) is the relationship between the loops, gated by the user.

### 3. Domain agents negotiating for time

[ADR 0023](../adr/0023-durable-domain-agents-and-time-negotiation.md) introduces
durable fitness/sleep agents that ask the planner for **calendar time** — a core
part of the vision. The negotiation substrate already exists in
`lib/features/agents/` (ADR 0019/0021):

- `AttentionRequestEntity` — a claim carrying `requestedMinutes`, a schedulable
  window, `cadence`, and evidence.
- `AttentionAwardEntity` — a concrete block proposal that still flows through the
  ChangeSet gate (ADR 0006).
- `StandingAgreementEntity` — already enumerates `fitness` and `sleep` scopes,
  with enforcement, approval mode, and pre-emption.

The gap is the **producer side**: there is no `domain_agent` kind,
`request_attention` is task-only (`_taskTargetKind`), there are no self-scheduled
producer wakes, and the planner's claim → weigh → award → ChangeSet arbitration
path is unbuilt. This is the *inverse* of a "disposable analyst run" (planner
spawns a throwaway investigator) — and disposable analyst runs were deliberately
struck from ADR 0022.

## Correctness landmines (found by adversarial review)

These are now reflected in the implementation plan:

- `activeDayId` is *derived* from `AgentDayLink` and written back every wake — it
  must stop being derived/persisted for the planner, not merely "ignored".
- Single-flight, `removeByAgent`, and `mergeTokens` are keyed by `agentId` only —
  cross-day unsafe once one planner owns many days. The wake queue must become
  workspace-aware across supersede, dedupe, merge, and token extraction.
- `CaptureEntity.dayId` must be defaulted/derived, not `required`, or captures
  synced from older peers throw on deserialization.
- PR order must land the workspace plumbing **additively** under the existing
  per-day identity, then flip to one planner only once the flip is provably safe.

## Canonical documents

- [ADR 0022 — Long-Lived Daily OS Planner](../adr/0022-long-lived-daily-os-planner.md)
- [ADR 0023 — Durable Domain Agents and Time Negotiation](../adr/0023-durable-domain-agents-and-time-negotiation.md)
- [Long-Lived Daily OS Planner — implementation plan](./2026-06-07_long_lived_daily_os_planner.md)
- Supersedes the per-day identity decision in
  [Day Agent Layer — implementation plan](./2026-05-25_day_agent_layer.md)
