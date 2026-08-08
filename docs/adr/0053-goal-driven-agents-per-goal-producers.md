# ADR 0053: Goal-Driven Agents — Per-Goal Durable Producers

- Status: Proposed
- Date: 2026-08-08

## Context

The product wants long-running coaches for long-term personal goals — "average 10,000 steps a
day", "gym 3×/week", composite fitness goals — viable over a ten-year horizon. Each is mostly
dormant, wakes on time- and data-triggers, nudges the user visually when off-track (ADR 0055),
holds an ongoing voice-capable conversation, and revises its goal through that dialogue while
always being able to state the current goal and success criteria.

ADR 0023 already specifies the closest ancestor: durable, self-scheduled *domain agents*
(fitness, sleep) that produce attention claims and standing agreements for the day planner to
arbitrate. It is Proposed and unimplemented. Its Decision 1 picks one agent per
`StandingAgreementScope`; its Open Question 1 explicitly leaves granularity open.

### What already exists (verified in code)

- `StandingAgreementEntity` (`lib/features/agents/model/agent_domain_entity.dart:516`) fully
  models "exercise 3×/week" — scope (`fitness`, `sleep`, …), cadence, `minCount`/`minMinutes`
  quotas, enforcement (`preference`/`target`/`nonNegotiable`), approval mode, evidence refs —
  and has **no writer and no UI**. The day-planner context builder reads agreements for its
  planning window (`day_agent_context_builder.dart`).
- `AutoCompleteRule` (`lib/classes/entity_definitions.dart:68-114`) models health/measurable
  thresholds with `and`/`or`/`multiple` composition — and has **no evaluator anywhere**.
- Versioned configuration with head pointers and `authoredBy` provenance exists twice (agent
  templates, souls) and is battle-tested with sync and vector clocks.
- `AgentKinds` are free strings (`agent_constants.dart:5`) — a new kind is non-breaking.
  `AgentTemplateKind` is a closed enum whose decode has no fallback
  (`agent_domain_entity.g.dart`); v1 goal agents sidestep it by using no template at all.
- The runtime plug-in seam (`agentWakeRunnersProvider` + `AgentRuntimeMaintenance`,
  `agent_runtime_registry.dart`) was built for new agent kinds and is exercised by Daily OS.

## Decision

1. **A new agent kind, one durable identity per goal.** `AgentKinds.goalAgent = 'goal_agent'`;
   the agent *is* the goal's surrogate. This deliberately refines ADR 0023's per-scope
   granularity, using 0023's own principle — "memory coherence, not claim volume, sets the
   granularity": a goal is one narrative thread (one conversation, one evolving spec, one
   attainment series) over a decade. Per-scope agents would interleave several narratives in one
   message log, making compaction summaries mushy and "state your current goal" plural. Goals
   also end individually: per-goal identity retires cleanly via `AgentLifecycle` with history
   intact. The arbitration side is unaffected — claims and agreements carry scope on themselves.

2. **The goal is versioned structured state, not prose.** Two new `AgentDomainEntity` variants:
   `goalSpecVersion` (immutable: `title`, a speakable `statement`, a `GoalCriterion` criteria
   tree, `authoredBy`, provenance, optional start/target dates, rationale) and `goalSpecHead`
   (deterministic id `goal_spec_head:<agentId>`, LWW). "State your current goal and success
   criteria" is a head read — zero inference, immune to context drift. Version history is the
   ten-year story: every revision is a new version; nothing is edited in place.

3. **Criteria are a purpose-built tree, not a reuse of `AutoCompleteRule`.** A new freezed union
   `GoalCriterion` with leaves `metric{dataType, window, aggregation, target, direction}`,
   `habit{habitId, window, targetCount}`, `measurable{…}`, and composites
   `allOf`/`anyOf`/`atLeastCount{successes}`, every node carrying a stable `criterionId`.
   `AutoCompleteRule` leaves are point-in-time, same-day thresholds owned by habit
   autocompletion; goals need rolling windows, aggregation, direction, and per-window quotas.
   Grafting those onto the habit feature's class would couple two features' evolution
   permanently. A `GoalCriterion.fromAutoCompleteRule` importer seeds a goal from an existing
   habit rule in one tap; the goal evaluator is the codebase's first rule-tree evaluator, making
   a later `AutoCompleteRule` adapter trivial.

4. **Deterministic attainment is a keyed register.** `goalProgress` rows keyed
   `goal_progress:<agentId>:<periodKey>`, recomputed from source and never accumulated (the
   `weekRollup` convergence pattern), carrying `trackStatus`
   (`onTrack | atRisk | offTrack | achieved | insufficientData`, mirrored into `subtype` for
   indexed scans), `attainment 0..1`, per-criterion results, and the `specVersionId` the numbers
   were computed against — so a decade of charts stays honest across goal revisions. The register
   is retention-exempt: it is both the chartable history and the agent's cheap wake context.

5. **Goal revision is proposal-only.** The single mutation path is a `propose_goal_revision`
   tool call producing a ChangeSet (ADR 0006) with a human-readable old-vs-new diff; on user
   approval a new `goalSpecVersion` (authoredBy `goal_agent`, `sourceSessionId` provenance) is
   written and the head moves. There is **no auto-accept tier**: a ten-year coach must never
   quietly move its own goalposts. User-authored versions (creation, direct edits) write
   directly.

6. **The goal agent is `StandingAgreementEntity`'s first writer — as a derived projection.**
   When the head spec contains a quota criterion implying calendar time (gym 3×/week), the agent
   proposes `upsert_standing_agreement` (ChangeSet-gated, deterministic id
   `standing_agreement:goal:<agentId>`, `targetKind: 'goal'`, evidence refs pointing at
   `goalProgress` rows). The spec remains the source of truth; the agreement is planner-facing
   output. Metric-only goals imply no agreement. Attention *claims* and planner arbitration
   remain ADR 0023's future seam — deliberately not built here.

7. **v1 goal agents use no template.** The goal constitution (role, wake contract, tool
   protocol, grounding and no-op rules) is fully code-owned — the ADR 0052 posture; goal agents
   are the first kind born under it. This also avoids extending the frozen `AgentTemplateKind`
   enum. Persona arrives via soul documents attached through agent links (link types are free
   strings — non-breaking) in a later increment.

## Consequences

- The feature lands as ADR 0023's producer side at finer granularity; 0023 is amended (granularity
  note referencing this ADR), not superseded. If scope-level coaching is ever wanted, it composes
  over goal agents through the claim/agreement log — the interface 0023 already defines.
- Four new entity variants ride the existing single-table union with `fallbackUnion: 'unknown'`
  forward compatibility and no schema-version bump. Mixed-version fleets are not a supported
  configuration — the project assumes all of a user's devices stay current, so no
  store-and-forward compatibility work is done for peers running older builds.
- An orphaned, fully-modeled entity (`StandingAgreementEntity`) gains its first producer, and the
  never-evaluated criteria idea (`AutoCompleteRule`) gains a working evaluator lineage.
- One agent per goal multiplies agent instances; wake cost is bounded by ADR 0054's
  deterministic-first design, and memory cost by ADR 0057.

## Non-Goals

- Mutating the calendar or negotiating with the planner (ADR 0023's arbitration path stays
  future work).
- Per-scope "domain coach" agents.
- Auto-accepted goal revisions of any size.
- Push notifications (ADR 0055 is banner-only).

## Related

- [ADR 0006: Change Set — Deferred Tool Confirmation Workflow](./0006-change-set-deferred-tool-confirmation.md)
- [ADR 0023: Durable Domain Agents and Time Negotiation](./0023-durable-domain-agents-and-time-negotiation.md) — amended by this ADR (granularity)
- [ADR 0052: Agent Directive Constitution](./0052-agent-directive-constitution.md)
- [ADR 0054: Deterministic-First Two-Tier Wakes](./0054-deterministic-first-two-tier-wakes.md)
- [ADR 0055: Banner-Nudge Attention Channel](./0055-banner-nudge-attention-channel.md)
- [ADR 0057: Decade-Scale Agent Memory](./0057-decade-scale-agent-memory.md)
- Assessment: `docs/implementation_plans/2026-08-08_goal_agents_phase1_assessment.md`
