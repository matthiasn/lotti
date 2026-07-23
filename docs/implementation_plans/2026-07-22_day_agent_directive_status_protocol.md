# Day-Agent Directive + Status Protocol (ADR 0032 Phase 3) — Implementation Plan

Grounds ADR 0032 §2–§3 ("Communication protocol" and "Pushback is a capacity
reconciliation") in the code as it exists after phases 1–2 (PR #3538) and the
phase-1 follow-ups (durable `parseCapture`, tightened same-day guard). Written
2026-07-22.

## Goal

Give the coordinator (`daily_os_planner`) and per-day agents
(`day_agent:<dayId>`) a durable, synced, pull-based protocol:

- **Downward**: the coordinator issues one revisioned `DayDirectiveEntity` per
  day (commitments, capacity budget, carry-over, constraints, attention
  notes). The per-day agent reads the newest revision at wake start and is
  contractually bound to place, trade, or escalate every commitment.
- **Upward**: the per-day agent raises typed `DayStatusEventEntity` records
  (`onTrack | attentionNeeded(reasons) | dayClosed`); the coordinator consumes
  them at a new scheduled **digest wake**, alongside the day summaries it
  already reads.
- **Pushback**: capacity reconciliation becomes arithmetic-in-context (the
  directive carries the ledger), enforced by the drafting prompt contract.

No RPC; everything is a synced `AgentDomainEntity` consistent with
ADR 0016/0018/0019.

## What the code audit changed relative to the ADR text

These deviations should land as ADR 0032 amendments alongside the final slice:

1. **Upward channel 1 (agentReportHead) is replaced by day summaries.**
   `DayAgentWorkflow` writes no `AgentReportEntity` (only project/event/task
   agents do), and the coordinator's `<recent_days>` week context already
   consumes `DaySummaryEntity` per day (`day_agent_week_context_service.dart`).
   Adding a parallel report chain would duplicate that artifact. The distilled
   upward channel is: day summary (existing) + status events (new).
2. **Upward channel 3 (promotable observations) largely already exists.**
   Durable knowledge is coordinator-keyed regardless of the waking agent
   (`day_agent_tool_handlers.dart` forces `dailyOsPlannerAgentId` for
   `propose_knowledge`), so a per-day agent already "promotes" directly into
   the coordinator's proposed-knowledge queue, throttled by user confirmation
   in the What-I've-learned panel. No `promotionCandidate` tagging is needed
   in phase 3.
3. **`DayDirectiveEntity` needs no projection table.** Its id is the
   deterministic `day_directive:<dayId>` — a PK read
   (`getEntity`/`getEntitiesByIds`), exactly like `DayPlanEntity`. The
   attention-claim projection pattern is only required for windowed/filtered
   scans; status events need at most one new drift named query.
4. **"Coordinator stops assembling per-day mode blocks"** cannot be absolute
   while the coordinator still owns pre-cutover days (day-forward cutover,
   `getOrCreateDayAgentForDate`). Phase 3 scopes it to: digest wakes assemble
   the digest block *instead of* mode blocks; per-day mode blocks continue for
   coordinator-owned pre-cutover days until those age out.

## Data model summary

**`DayDirectiveEntity`** — new `AgentDomainEntity` variant, type
`day_directive`, id `dayDirectiveEntityId(dayId)` = `day_directive:<dayId>`,
`agentId` = coordinator. Revision-in-place (LWW; newest `issuedAt` wins via
the default resolver — no `agent_concurrent_resolver` branch needed):

```text
DayDirectiveEntity {
  id, agentId, dayId, planDate, directiveRevisionId (uuid), issuedAt,
  commitments: [ DayDirectiveCommitment { id, source
      (attentionAward | standingAgreement | userCommitment | carryOver),
      title, windowStart?, windowEnd?, minutes?, evidenceRefs } ],
  capacityBudget: DayCapacityBudget { availableMinutes,
      alreadyScheduledMinutes, energyBands },
  carryOver: [ DayCarryOverItem { taskId?, itemId?, title, reason } ],
  constraints: [String],       // bounded freeform, e.g. protected windows
  attentionNotes: [String],    // distilled cross-day context
  createdAt, updatedAt, deletedAt, vectorClock
}
```

**`DayStatusEventEntity`** — new `AgentDomainEntity` variant, type
`day_status_event`, id `day_status:<dayId>:<uuid>`, `agentId` = the day-owner
agent that raised it. Append-only, never revised:

```text
DayStatusEventEntity {
  id, agentId, dayId, status: DayStatusKind (onTrack | attentionNeeded |
  dayClosed), reasons: [DayStatusReason (overCommitted |
  directiveUnsatisfiable | userDivergence | processingBlocked)],
  note (bounded, ≤ 500 chars like day summaries), raisedAt,
  createdAt, updatedAt, deletedAt, vectorClock
}
```

A new entity variant (not an `AgentMessageKind`) keeps status events out of
the compaction/log-projection fold semantics and gives the coordinator a
cheap typed scan. Sub-models live beside the union in
`agent_domain_entity.dart` (precedent: `DayAgentEnergyBand` on
`DayPlanEntity`).

## Slice 1 — Entities + persistence

Mechanical, following the audited recipe:

- `lib/features/agents/model/agent_domain_entity.dart`: two new `const
  factory` variants + sub-model freezed classes; regenerate.
- `lib/features/agents/model/agent_constants.dart`: `AgentEntityTypes.dayDirective
  = 'day_directive'`, `dayStatusEvent = 'day_status_event'`.
- `lib/features/agents/model/agent_enums.dart`: `DayStatusKind`,
  `DayStatusReason`, `DayCommitmentSource` enums (forward-compatible unknown
  handling like existing enums).
- Compile-forced maps: `agent_db_conversions.dart` (deletedAt / entityType /
  entityCreatedAt / entityUpdatedAt; subtype for `day_status_event` = the
  `DayStatusKind.name` so the existing type+subtype index serves filtered
  reads), `sync/agent_lww_timestamp.dart`.
- Id helpers in `lib/features/daily_os_next/agents/domain/day_agent_identity.dart`:
  `dayDirectiveEntityId(dayId)`, `dayStatusEventId(dayId)` (uuid-suffixed).
- Repository reads (no schema migration expected):
  - Directive: existing `getEntity` by deterministic id — no new method.
  - Status events: one new drift named query + repo method
    `getDayStatusEventsSince(DateTime since, {int limit})` filtering
    `type = 'day_status_event' AND created_at > ?` ordered ascending. If the
    existing indexes don't cover it acceptably, add an expression index in a
    `schemaVersion 17` migration — decide by looking at the query plan, not
    up front.
- Tests: `entity_factories.dart` builders, round-trip serialization tests,
  repo query test, fallbacks if passed via `any()`.

## Slice 2 — Downward: issue + consume the directive

**Coordinator write path**
- New tool `issue_day_directive` in `day_agent_tool_names.dart`, dispatched in
  `day_agent_tool_handlers.dart`. Handler validates: waking agent is the
  coordinator (`agentId == dailyOsPlannerAgentId`) — per-day agents get a
  tool-failure; `dayId` parses; commitments/minutes/energy bands parse with
  the same strictness style as `day_agent_plan_parser.dart`; bounded list
  sizes (e.g. ≤ 12 commitments, ≤ 8 notes/constraints — reject beyond).
  Writes via `syncService.upsertEntity` with a fresh `directiveRevisionId`,
  preserving `createdAt` on revision.
- Deterministic assembly helper `DayDirectiveAssembler` (new,
  `lib/features/daily_os_next/agents/service/`): builds the *proposed*
  commitments/capacity scaffold from `getAttentionPlanningInputsForWindow`
  (day window), committed blocks of the target day's `DayPlanEntity`, and
  surrounding days' plans (the week-context batch-read pattern). Rendered
  into the digest prompt so the model edits/annotates rather than inventing
  the ledger — "deterministic input plus judgment call, in that order"
  (ADR §3).

**Per-day read path**
- `day_agent_context_builder.dart`: load `getEntity(dayDirectiveEntityId(dayId))`
  and render a new `<day_directive>` JSON section **between
  `<knowledge_index>` and `<day_log>`** — the ADR §4 slot, keeping it inside
  the byte-stable prefix (stable within a revision).
- `day_agent_prompt_sections.dart`: add the tag to `DayAgentPromptTags` and
  `DayAgentPromptTags.all` (so `neutralizePromptTags` strips forged
  boundaries).

**Pushback contract (prompt, not code)**
- `day_agent_prompt_builder.dart` drafting/refine rules: every directive
  commitment must be (a) represented in the drafted plan, (b) explicitly
  traded away in a proposed diff whose `reason` names the colliding
  commitment, or (c) escalated via `raise_day_status(attentionNeeded,
  directiveUnsatisfiable)`. Before drafting/refining, reconcile requested
  minutes against `capacityBudget.availableMinutes −
  alreadyScheduledMinutes`; if the request does not fit, surface the
  conflict instead of overpacking.
- `seeded_directives.dart`: dated changelog entry describing the new
  contract (pattern: the 2026-07-22 guard entry).
- Trade-off surfacing in the diff UI (`DiffRow`) stays out of scope — the
  colliding-commitment name travels in the existing freeform `reason` field;
  a structured conflict UI is a phase-4 visibility follow-up.

## Slice 3 — Upward: raise + consume status

- New tool `raise_day_status` (per-day *and* coordinator-owned-day wakes):
  args `dayId`, `status`, `reasons[]`, `note`. Validation mirrors
  `write_day_summary` bounds; `dayClosed` is accepted but nothing automates
  it yet (dormancy is phase 5+). Persists `DayStatusEventEntity` under the
  waking agent's id. Rate-cap per wake (1 event) via the strategy's tool
  bookkeeping to stop status spam.
- Prompt rules: raise `attentionNeeded` only for the typed reasons; `onTrack`
  only when explicitly asked (the digest infers silence = fine) — keeps event
  volume near zero in the happy path.
- Coordinator consumption: digest context (slice 4) renders events since the
  last digest. "Since" = the newest `AgentMilestone.dailyWakeCompleted`
  milestone on the coordinator's log (existing enum value, currently unused
  by the day workflow) — written at digest completion; falls back to −48 h on
  first digest.

## Slice 4 — Coordinator digest wake

- New wake reason `digest` + trigger token `digest:<date>` in
  `day_agent_trigger_tokens.dart` (registered in `resolvePlannerWakeDay`'s
  day-prefix list is *not* needed — digest is coordinator-scoped, workspace
  key `coordinator:digest`).
- `DayAgentWorkflow`: when the wake carries the digest token (coordinator
  only), assemble a `<digest>` mode block instead of capture/drafting/refine:
  - status events since last digest (slice 3),
  - the existing week context (`<recent_days>`/`<week_ahead>` already carry
    summaries, planned/recorded minutes, deadlines),
  - the `DayDirectiveAssembler` scaffold for today and tomorrow,
  - current directives (today + tomorrow) for revision awareness.
  Digest-mode tools: `issue_day_directive`, `raise-agenda` tools it already
  has (`propose_knowledge`, `record_observations`, `write_day_summary` for
  yesterday), `set_next_wake`. Completion writes the
  `dailyWakeCompleted` milestone.
- Scheduling bootstrap: `DayAgentService.restoreSubscriptions` (runs at
  startup) ensures a pending `ScheduledWakeEntity` exists for the coordinator
  with workspace `coordinator:digest` at the next 06:00 local if none is
  pending — `ScheduledWakeManager` already enqueues due records generically.
  The digest itself re-schedules the next one via `set_next_wake` (cap logic
  exists); the bootstrap only covers the cold start.
- `attentionNeeded` same-day reaction (ADR open question 1): **deferred**.
  Phase 3 ships digest-cadence consumption only; a throttled
  attention-subscription is a separate follow-up once event volume is
  observed.

## Slice 5 — Wire into the harness + live eval, docs

- Extend `DayAgentPipelineHarness` + the durable-jobs smoke test: a scripted
  digest wake issues a directive; a subsequent scripted draft wake for that
  day must see `<day_directive>` in its prompt (assert via the captured
  prompt payload) and a scripted `raise_day_status` round-trips into
  `getDayStatusEventsSince`.
- Optionally extend `day_agent_draft_live_eval_test.dart`: seed a directive
  with one commitment + tight capacity and assert the live model either
  places it or raises status — a directive-quality eval (ADR: "directive
  quality becomes a first-class testable artifact").
- Docs: feature README (protocol section + mermaid sequence diagram for
  directive/status/digest flow), ADR 0032 amendments (the four deviations
  above), CHANGELOG only if user-visible behavior ships (digest wake +
  pushback wording likely qualifies).

## Testing and quality gates (every slice)

- Analyzer zero warnings; `fvm dart format .`.
- Unit tests colocated one-per-source-file; centralized mocks/fallbacks;
  meaningful assertions (tool-failure paths, validation bounds, LWW revision
  behavior, since-query ordering).
- `test/features/daily_os_next` + `test/features/agents` suites green before
  each slice's commit; Codecov patch ≥ 99%.
- Smoke/harness test updated in the same PR as the behavior it covers.

## Open questions (decide before the affected slice)

1. **Digest hour** (slice 4): fixed 06:00 local to start, or read the
   category/profile settings? Proposal: constant first
   (`AgentSchedules.dayAgentDigestHour = 6`), settings later.
2. **Keep `<attention_planning>` in the per-day prompt** once the directive
   carries commitments (slice 2)? Proposal: keep both through phase 3 (the
   directive may be missing for days the coordinator never digested);
   removing the direct read is phase-6 coordinator slimming.
3. **Directive for coordinator-owned pre-cutover days**: the coordinator
   would "issue itself" a directive. Proposal: yes — uniform read path;
   the entity is keyed by day, not by consumer, and the prompt section
   renders identically.
4. **`dayClosed` semantics** (slice 3): accepted and stored but not acted
   on until the dormancy lifecycle (ADR phase 5+ / amendment "no dormancy
   automation"). Confirm that's acceptable or pull minimal day-close into
   scope.
