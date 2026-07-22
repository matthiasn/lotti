# ADR 0032: Hierarchical Day-Agent Coordination

## Status

Accepted (phases 1–5 implemented; phase 6 — coordinator slimming, gated on
measured token stats — remains proposed). See Amendments below for where the
implementation diverged from this ADR's original text.

## Date

2026-07-20

## Context

### The problems, grounded in the current implementation

The Daily OS planner is a single durable agent identity,
`daily_os_planner` (`day_agent_service.dart`), that owns every day
workspace under one `AgentIdentityEntity`, one state chain, one execution
lease, and one memory/compaction substrate. ADR 0022 created this shape
deliberately: the earlier one-agent-per-day model reset all learning at
midnight because observations, captures, and compaction memory were keyed by
`agentId`. The collapse fixed learning but reintroduced four structural
problems:

1. **Unbounded context and serialized execution.** State reconstruction folds
   the planner's full observation set on every wake (ADR 0016), and the log
   grows for the lifetime of the identity — ADR 0022's own Consequences
   section flags that collapsing N per-day logs removed the bound the old
   model accidentally had. Worse, all days share one execution lease: a slow
   draft for Tuesday blocks the drain of Wednesday's queued wake.
2. **No per-day visibility.** The full visibility stack exists — durable
   `wake_run_log` rows, synced `WakeTokenUsageEntity` per wake, the
   append-only dialogue log, and the five-tab `AgentInternalsBody` UI
   (Stats / Reports / Conversations / Observations / Activity). But it is all
   keyed by `agentId`, so the planner's per-day work is indistinguishable
   inside one aggregate. There is no per-day wake history, token cost, or
   dialogue view, and no "inspect this day's agent" affordance on the Day
   page.
3. **Volatile processing intent.** `WakeQueue` is in-memory only. A queued
   draft/refine/parse wake dies with the process. ADR 0031's device-local
   processing outbox currently carries only the `transcribeAudio` job kind;
   `parseCapture`, `draftPlan`, and `refinePlan` need the same durability.
4. **Polling UX.** Draft/refine callers poll for a result with a timeout
   (`real_day_agent.dart`); a dropped queue or slow wake surfaces only as a
   timeout error. There is no async "your plan is ready" path, although a
   `dayPlanNotification` notification id already exists.

Additionally, ADR 0022 D12 documents that a single
`AgentState.scheduledWakeAt` cannot hold multiple outstanding day-scoped
wakes — a second day's `set_next_wake` clobbers the first. Per-day identities
dissolve this restriction.

### What the performance data actually says

With hosted models, input token throughput is not the bottleneck: a measured
wake processed ~41K input tokens and generated ~3.2K output tokens in ~16 s.
Shrinking input alone does not make a 16-second call feel snappy. The
levers that matter, in order:

1. **Perceived latency**: async completion with notification instead of a
   blocking wait (problem 4), plus pre-warmed per-day wakes.
2. **Output budget**: focused agents with narrow briefs produce shorter,
   more decisive output; output tokens dominate wall clock.
3. **Cache stability**: byte-stable prompt prefixes per agent. A per-day
   agent's prefix is stable within its day; the monolith's prefix churns as
   other days' state moves.
4. **Parallelism**: per-day leases let two days' wakes run concurrently
   under the existing bounded drain engine (device concurrency 1–8).
5. **Fold cost**: bounded per-day logs keep the ADR 0016 projection fold and
   compaction cheap forever, instead of degrading with planner age.

### What already exists that the hierarchy can reuse

- **Agent kind**: `AgentKinds.day_agent` exists; the wake executor routes by
  kind (`agent_workflow_providers.dart`).
- **Per-day partitioning**: `WakeJob.workspaceKey` = `day:<dayId>` already
  partitions queueing, coalescing, and cancellation per day — half of the
  sharding exists inside the monolith.
- **Day identity**: `dayPlanId(date)` = `dayplan-YYYY-MM-DD`
  (`lib/classes/day_plan.dart`) is a deterministic, date-keyed identity.
- **Scoped compaction**: planner memory already splits into
  `globalObservations | dayCaptures(dayId)` checkpoint scopes, and capture
  events are filtered to the wake's day. The `dayCaptures(dayId)` scope is
  exactly a per-day agent's native log content.
- **Report consumption**: ADR 0003's linked-context contract (distilled
  `agentReportHead` reports, pull-based at the consumer's next wake) is a
  working upward-communication protocol between agents.
- **Commitment substrate**: ADR 0019/0021 attention negotiation
  (`AttentionRequestEntity`, `AttentionAwardEntity`,
  `StandingAgreementEntity`, indexed window projections) is a working
  commitments ledger.
- **User approval gate**: ADR 0006 ChangeSets already make the user the
  final validator of plan mutations.
- **Durable knowledge**: the two-tier, compaction-exempt planner knowledge
  (ADR 0022 D10) and the weekly template-evolution loop are the cross-day
  learning assets that must not be lost.
- **Resilient capture**: ADR 0031's batch-first commit ordering and
  processing outbox guarantee recordings survive offline and are
  rediscoverable by day (`day_entries` section,
  `DayAudioEntryContextService` keyed by `dayId`).

### Constraint from concurrent direction decisions

Two product-direction decisions shape this ADR: realtime transcription has
been removed in favor of batch transcription with glossary/lexicon context
(ADR 0031/0024), and the day is moving toward being a first-class entity
with its own timeline, task-like. This ADR assumes both: per-day agents
consume batch transcripts from the durable outbox, and a day's context is
assembled from day-scoped entries, mirroring the task-agent linked-entry
pattern.

## Decision

### 1. Two roles: a coordinator and per-day agents

The single planner splits into:

- **Coordinator** — the existing `daily_os_planner` identity, retained and
  re-scoped. It keeps cross-day learning (two-tier durable knowledge, weekly
  one-on-one evolution loop), owns the commitments/capacity ledger, issues
  day directives, and consumes per-day reports. It stops executing per-day
  drafting/refining/capture wakes and stops accumulating capture events on
  its log.
- **Per-day agents** — one `AgentKinds.day_agent` instance per day, with the
  deterministic agent id `day_agent:<dayId>` (derived from
  `dayPlanId(date)`), created lazily on first day activity (first check-in,
  first plan request, or coordinator pre-warm). A per-day agent executes
  capture parsing, plan drafting, refinement, and day-status reporting for
  exactly one day. It is a full log-projected agent (ADR 0016): it gets
  wake runs, token usage, dialogue, and the internals UI for free under its
  own id.

Per-day agents are *bounded*, not ephemeral: they are durable identities
whose useful lifetime is naturally capped by the day. After day close and
summary, the agent goes `dormant`. Its distilled value survives it: the
`DaySummaryEntity`, its final report, and observations promoted into
coordinator knowledge. Dormant day agents are retained for
inspection/audit; they are never woken by subscriptions again.

This amends ADR 0022: Decisions 1 and 3 (single identity executes all day
workspaces) are superseded; Decisions 6, 9, 10, 12 (cross-day learning
loops, durable knowledge) carry over to the coordinator unchanged. The
midnight-reset failure that motivated ADR 0022 does not return, because
learning never lived in the per-day agents in this model.

### 2. Communication protocol: events on the synced log, pull-based

No RPC between agents. All coordination flows through durable, synced agent
entities, consistent with ADR 0016/0018/0019.

**Downward — `DayDirectiveEntity`** (new `AgentDomainEntity` variant), keyed
`day_directive:<dayId>`, revisioned (`directiveRevisionId`), written only by
the coordinator:

```text
DayDirectiveEntity {
  dayId / planDate / directiveRevisionId / issuedAt
  commitments: [ { id, source (attentionAward | standingAgreement |
                   userCommitment | carryOver), title, window?,
                   minutes?, evidenceRefs } ]
  capacityBudget: { availableMinutes, energyBands, alreadyScheduledMinutes }
  carryOver: [ { taskId | itemId, reason } ]
  constraints: [ freeform bounded directives, e.g. protected windows ]
  attentionNotes: [ distilled cross-day context relevant to this day ]
}
```

The directive is assembled by the coordinator from the attention-claim
index, standing agreements, committed plan blocks of surrounding days, and
its durable knowledge. It contains **no capture transcripts and no other
day's log content** — only distilled, bounded facts. A per-day agent reads
the newest directive revision at wake start via an indexed projection
(same pattern as `getAttentionClaimsForTarget`).

**Directive bindingness.** Directives are binding constraints, not hints:
the per-day agent's prompt contract requires each commitment in the
directive to be either (a) represented in the plan, (b) explicitly traded
away in a proposed ChangeSet the user must approve, or (c) escalated. It
may not silently drop a commitment. The user remains the final validator of
whether work actually happened — agents validate plans, humans validate
reality.

**Upward — three channels, all existing patterns:**

1. **Distilled report** via the existing `agentReportHead` mechanism
   (ADR 0003): one-liner + tldr, consumed by the coordinator pull-based at
   its next wake (ADR 0027 propagation).
2. **`DayStatusEvent`** appended to the per-day agent's log with a
   coordinator-indexed projection: `onTrack | attentionNeeded(reasons) |
   dayClosed`. `attentionNeeded` carries typed reasons
   (overCommitted, directiveUnsatisfiable, userDivergence,
   processingBlocked).
3. **Promotable observations**: the per-day agent tags observations
   `promotionCandidate`; the coordinator's daily digest wake reviews the
   day's candidates and folds accepted ones into its own observation log
   (feeding the existing weekly knowledge-promotion loop). Promotion is a
   coordinator decision, not an automatic copy — this is the throttle that
   keeps the coordinator log bounded.

### 3. Pushback is a capacity reconciliation, not a personality trait

Pushback ("you already committed to X; adding Y is not realistic") becomes a
deterministic input plus a judgment call, in that order:

- The directive gives the per-day agent the commitments ledger and capacity
  budget as structured data.
- On any request that adds work (new capture item, refine instruction), the
  agent's contract requires reconciling requested minutes against
  `capacityBudget` minus committed minutes before drafting. The arithmetic
  is in context; the model does not need to remember cross-day history —
  the coordinator already distilled it.
- If the request does not fit, the agent must respond with the conflict made
  explicit (which commitments collide, what trade would make it fit) and
  propose the trade as a ChangeSet rather than silently overpacking the
  plan.
- Cross-day pushback ("that's Thursday's third big commitment this week")
  is the coordinator's job, expressed in `attentionNotes` of the directive
  ahead of time, or raised at digest time as a next-day directive change.

The coordinator maintains the ledger from: attention awards and standing
agreements (ADR 0019/0021), committed `PlannedBlockState.committed` blocks
across the week's `DayPlanEntity` heads, and explicit user commitments it
observed in reports. No new bookkeeping agent state is invented; the ledger
is a projection over existing entities plus directive persistence.

### 4. Context budgets and caching

**Per-day agent prompt** (target ≤ ~12K input tokens, byte-stable prefix
first):

1. System prompt (soul + operational directives) — stable
2. `day_id` / `plan_date` — stable
3. `knowledge_index` (coordinator-published Tier-1 hook index) — stable
4. `day_directive` (newest revision, bounded) — stable within revision
5. `day_log` — this day's captures + own observations only (the
   `dayCaptures(dayId)` scope becomes the agent's native log; no scope
   machinery needed for foreign days because foreign days are other agents)
6. `day_entries` — ADR 0031 §15 provenance/status index (32 items / 4 KiB)
7. Mode block (`capture` | `drafting` | `refine`) — per-wake
8. Trigger tokens, current local time — volatile tail

Compaction hysteresis budgets shrink accordingly (a day's log rarely needs
50K/20K; concrete values fixed in the implementation plan). Tier-2
`knowledge_statements` are included scope-filtered exactly as today.

**Coordinator prompt**: knowledge index and statements, compacted
global-observations log, the report index of recent per-day agents
(one-liner/tldr, not dialogues), `week_ahead`, the commitments ledger, and
day-status events since its last wake. Never a capture transcript. The
coordinator's log growth rate drops to distilled-events-only, which is the
structural fix for its unbounded fold cost.

**Pre-warming**: the coordinator's morning routine (or a fixed schedule)
issues the day's directive and a scheduled pre-warm wake for that day's
agent before the user's typical check-in time, using per-agent
`ScheduledWakeEntity` records. Because each day agent has its own
`scheduledWakeAt`, the ADR 0022 D12 clobbering constraint disappears.

### 5. Durable processing intent and async UX

- `parseCapture`, `draftPlan`, and `refinePlan` become durable jobs in the
  device-local processing outbox (with AgentDb-side effect claims for
  agent-owned outputs), extending ADR 0031's transcription-only job model.
  The in-memory `WakeQueue` remains what it is: an execution scheduler, not
  an intent store. A process kill loses no requested plan work.
- Draft/refine polling in `real_day_agent.dart` is replaced by an
  event-driven completion path: wake completion milestone → provider
  invalidation → Activity timeline card state change → local notification
  (`dayPlanNotification`) when the app is backgrounded. The Day Activity
  timeline (ADR 0031 §14) is the progress surface: "drafting your plan"
  cards with durable status, never a modal spinner with a timeout.
- Batch transcription (with correction-lexicon/glossary context per
  ADR 0024) feeds the same pipeline: transcript receipt → per-day agent
  wake. Recordings remain discoverable by day through ADR 0031's provenance
  columns regardless of any downstream failure.

### 6. Visibility

Per-day agents inherit the complete existing stack keyed by their own id:
`wake_run_log`, `WakeTokenUsageEntity`, dialogue log, `AgentInternalsBody`,
pending-wakes UI. Additions are thin:

- An "Inspect day agent" affordance on the Day page routing to
  `AgentDetailPage(day_agent:<dayId>)`.
- Day-page badge summarizing the day agent's last wake status and per-day
  token spend (query by agent id — no new storage).
- The coordinator remains inspectable as today under `daily_os_planner`;
  its Conversations tab becomes readable again because per-day noise no
  longer lands there.

### 7. Persona mapping

The coordinator carries the persistent persona — the stable face, soul, and
voice the user builds a relationship with. Per-day agents run under the same
soul/template (the same character doing focused work on a specific day), so
the product surface presents one assistant delegating, not a cast of
strangers. Character animation states map to observable runtime facts:
idle (no pending wakes), working (running wake for the visible day),
attention (newest `DayStatusEvent` is `attentionNeeded`), celebrating
(day closed on-track). Distinct visual personas per day agent are
explicitly out of scope until the two-role model has proven itself.

### 8. Migration

Proof-based, following ADR 0031 §15/§17 discipline:

- Existing `dayCaptures(dayId)` checkpoints and day-scoped capture events
  seed the corresponding new per-day agent's log for recent/open days;
  older days get agents only on demand (user opens the day) — never a bulk
  backfill of years of days.
- `globalObservations` checkpoints, durable knowledge, and the evolution
  loop stay with the coordinator untouched.
- Legacy mixed/unscoped checkpoints remain excluded from new day wakes.
- `DayPlanEntity`/`DaySummaryEntity` ids are already day-keyed and remain
  valid; the writing agent changes, the entities do not.
- Existing wake-run history under `daily_os_planner` stays where it is;
  history is not rewritten.

## Consequences

### Positive

- Per-day context is bounded forever; the coordinator's log grows at
  distilled-event rate instead of transcript rate. Projection folds and
  compaction stay cheap regardless of app age.
- Per-day execution leases unlock concurrent wakes across days and remove
  cross-day head-of-line blocking.
- Per-day visibility (wakes, tokens, dialogue) falls out of the identity
  model with near-zero new infrastructure.
- Plan-processing intent becomes durable; the recording-loss class of bugs
  stays closed end-to-end (capture already durable via ADR 0031).
- Pushback becomes grounded in a structured ledger rather than the model's
  recollection, making it consistent and auditable.
- The pre-warm/scheduling model is simpler and per-day (D12 constraint
  gone).

### Negative and trade-offs

- **Distillation risk**: the per-day agent knows only what the directive
  and its own day contain. A weak coordinator digest produces weak
  directives and the day agent cannot compensate. Directive quality becomes
  a first-class testable artifact.
- **Coordination lag**: the coordinator learns of a day's outcome at its
  next wake, not instantly. Same-day cross-day reactions (e.g. "move
  tomorrow's commitment because today collapsed") arrive on the digest
  cadence unless a `DayStatusEvent(attentionNeeded)` triggers a coordinator
  subscription wake.
- **More identities**: agent-instance proliferation (365/year). Mitigated
  by lazy creation, dormancy, and on-demand instantiation for old days —
  but instance listing UIs need day-agent grouping/filtering.
- **Potentially more total token spend**: two-role coordination adds
  coordinator digest wakes. Expected to be offset by smaller per-wake
  contexts and rarer monolith mega-wakes; must be measured via the existing
  per-template token stats.
- **Two-hop information flow** adds protocol surface (directive +
  status/report) that must be versioned and tested like any API.

## Rejected alternatives

### Keep the monolith, compact harder

Scoped compaction (ADR 0031 §15) already exists and the fold/lease/
visibility problems persist structurally. Compaction cannot shard an
execution lease or un-mix a token-usage aggregate.

### Stateless per-wake day workers (no identity)

Cheapest contexts, but no durable log means no wake history, no dialogue
visibility, no per-day token attribution, and no place for the day's own
observations — it re-creates the debugging blindness this ADR exists to
fix.

### Direct agent-to-agent messaging (RPC)

Contradicts the log-projection architecture (ADR 0016/0018): un-synced,
un-replayable, race-prone. Bids/reports as durable events already proved
out in ADR 0019/0021.

### Per-day agents with their own learning (the pre-ADR-0022 model)

Already failed: learning keyed to a day-scoped identity resets daily. The
coordinator exists precisely to give learning a durable home.

### Matrix sync outbox as the job queue

Already rejected in ADR 0031: the sync outbox transports durable entities;
it does not represent pending inference.

## Open questions

1. **Coordinator wake cadence** — pure digest (morning directive + evening
   review) vs. also subscribing to `DayStatusEvent(attentionNeeded)` for
   same-day reaction. Proposed: digest + attention-subscription, throttled.
2. **Multi-day queries** ("how was my week?") — coordinator answers from
   reports/summaries, or a transient fan-out reader. Proposed: coordinator
   answers; it owns cross-day state.
3. **Journal `DayPlanEntry` vs agent `DayPlanEntity`** — both exist in the
   codebase; the exact runtime split (which surfaces read which) needs a
   focused exploration before the implementation plan fixes the write path.
4. **Day-as-entity convergence** — if the day becomes a first-class
   task-like entity with a linked-entry timeline, the per-day agent should
   consume the generic linked-entry context contract (ADR 0003) instead of
   Daily-OS-specific projections. Sequencing between that migration and
   this ADR must be decided in the implementation plan.
5. **Retention/pruning** of dormant day agents' full dialogue logs (keep
   forever vs. compact-to-summary after N days). Token-usage rows are small
   and synced; dialogues are the bulk.
6. **Directive authorship boundaries** — whether the user can edit a
   directive directly (making it a shared contract document) or only
   influence it through commitments/agreements.

## Implementation roadmap (high level)

Phased so every phase ships value alone; new code takes no dependency on
code it is scheduled to replace.

1. **Durable agent jobs** — implement `parseCapture` / `draftPlan` /
   `refinePlan` outbox job kinds with AgentDb-side effect claims; replace
   draft/refine polling with completion events + `dayPlanNotification`.
   Pure resilience/UX win, independent of the agent split.
2. **Per-day agent kind** — `day_agent:<dayId>` identity creation, workflow
   executing capture/draft/refine against the day-scoped log; seed from
   `dayCaptures(dayId)` scopes; wire wake routing by kind. Coordinator
   untouched; the monolith stops receiving new per-day wakes day-forward.
3. **Directive + status protocol** — `DayDirectiveEntity`,
   `DayStatusEvent`, report consumption in the coordinator digest wake;
   pushback contract in the per-day prompt; coordinator stops assembling
   per-day mode blocks entirely.
4. **Visibility surface** — Day page "Inspect day agent" + status badge;
   instance grouping in Settings > Agents.
5. **Pre-warm + persona** — morning directive/pre-warm schedule per day
   agent; map character states to wake/status facts.
6. **Coordinator slimming + migration cleanup** — remove per-day sections
   from the coordinator prompt, verify its log growth is distilled-only,
   and measure token spend before/after via template token stats.

## Amendments (phases 1–2 implementation)

Recorded where the shipped implementation diverged from this ADR's original
text, discovered while implementing rather than corrected by rewriting the
Decision section in place.

- **No `globalObservations` / `dayCaptures(dayId)` checkpoint scopes exist.**
  §"What already exists" claimed scoped compaction checkpoints as reusable
  substrate; the codebase only ever had one checkpoint chain per `agentId`
  plus a runtime day-filter over `CaptureEntity` rows. There was nothing to
  seed a new per-day agent's log *from* — see the next point.
- **Migration is day-forward cutover, not seeding.** §8 proposed seeding a
  new per-day agent's log from existing checkpoints/capture events for
  recent/open days. Since no such checkpoints exist, and re-parenting
  captures/observations onto a new identity is itself risky, the shipped
  rule is simpler: `DayAgentService.getOrCreateDayAgentForDate` creates a
  fresh `day_agent:<dayId>` identity only for days the coordinator does not
  already own (no existing plan or capture under the coordinator for that
  day). Every day the coordinator already touched — all history up to the
  cutover — stays under the coordinator's identity permanently. No data
  migrates.
- **`day_agent` kind is shared, not new.** §"What already exists" undersold
  this: `AgentKinds.dayAgent` was already the *only* kind the monolithic
  planner ran under. Per-day agents reuse the identical kind and workflow
  (`DayAgentWorkflow`); the coordinator and per-day agents are distinguished
  by id shape (`daily_os_planner` vs. `day_agent:<dayId>`, see
  `day_agent_identity.dart`), not by kind.
- **Knowledge stays coordinator-keyed, always.** §4 said the per-day prompt's
  knowledge index is "coordinator-published"; implemented literally: durable
  knowledge is read under `dailyOsPlannerAgentId` on every wake (coordinator
  or per-day), and a per-day agent's `propose_knowledge` tool calls persist
  under the coordinator's id too — there is no per-day knowledge store.
- **Directive/status protocol (phase 3) shipped with four deviations from
  this ADR's text.** (1) Upward channel 1 is day summaries, not
  `agentReportHead`: day agents never wrote `AgentReportEntity`, and the
  coordinator's `<recent_days>` week context already consumes
  `DaySummaryEntity` per day — a parallel report chain would duplicate that
  artifact. (2) Upward channel 3 (`promotionCandidate` observations) was
  unnecessary: `propose_knowledge` is coordinator-keyed even on per-day
  wakes, so promotion-with-user-throttle already exists. (3)
  `DayDirectiveEntity` needs no indexed projection — `day_directive:<dayId>`
  is a deterministic PK read like `DayPlanEntity`; only `DayStatusEventEntity`
  gets a query (`getDayStatusEventsSince`, served by an existing index).
  (4) The digest cadence is re-armed deterministically by code (completion
  re-arm + startup bootstrap), not by the model's `set_next_wake` — a digest
  that forgets to self-schedule cannot break the cadence. The
  `attentionNeeded` same-day subscription (open question 1) is deferred:
  phase 3 ships digest-cadence consumption only.
- **Phase 4 shipped thinner than proposed.** The Day page's "Inspect agent"
  menu entry and Settings > Agents Type-based instance filtering/grouping
  already existed before this phase. Net-new: the day-header status chip
  (`DayAgentStatusChip`) surfacing the persona state with the per-day token
  spend in its tooltip (per-day identities only — a coordinator-owned day
  shows no spend, since the coordinator's lifetime aggregate would
  misattribute other days), tappable straight into the agent internals.
- **Phase 5 is a mapping, not a scheduler or renderer.** Pre-warm is the
  deterministic digest re-arm plus the per-day agent's self-scheduled
  `set_next_wake` (both existed after phase 3); no separate pre-warm
  scheduler was added. Persona is `dayAgentPersonaStateProvider`, deriving
  §7's states (idle | working | attention | celebrating) from runtime facts
  (running wake, newest `DayStatusEventEntity`); the `character` feature has
  no Daily OS consumer yet, so the provider is the contract the animation
  binds to when it lands. Distinct visual personas stay out of scope.
- **No dormancy automation.** §1 described bounded-not-ephemeral per-day
  agents going `dormant` after day close. No day-close lifecycle exists yet
  (shutdown/reflection tools are still mocked in `RealDayAgent`), so per-day
  agents simply stay `active` indefinitely once created — an accepted
  follow-up, not a regression, since nothing today would trigger dormancy
  correctly.
- **Phase 1 durable jobs initially covered `draftPlan`/`refinePlan`, not
  `parseCapture`.** The `DayProcessingJobKind.parseCapture` job kind,
  `DayProcessingOutboxRepository.enqueueParseCapture`, and the executor's
  dispatch for it shipped implemented and tested in the first slice, but
  `DayAgentCaptureService`'s capture-submit path still enqueued a volatile
  wake directly via `WakeOrchestrator.enqueueManualWake`. This was closed in
  the follow-up slice: `submitCapture` and `retryCapture` now enqueue the
  durable `parseCapture` job (plus a deferred runtime nudge), and
  `enqueueParseCapture` re-arms a stuck or terminal job with fresh attempts
  while attaching to a queued/running one — which is what makes
  `retryCapture` restart-safe without a separate retry API.

## Related

- ADR 0022 (long-lived planner — amended by this ADR)
- ADR 0023 (durable domain agents — coordinator remains the negotiation
  counterparty)
- ADR 0031 (batch-first capture/processing — extended, not changed)
- ADR 0003 (linked-context/report contract), ADR 0006 (ChangeSet gate),
  ADR 0016/0017/0018 (log projection, compaction, convergence),
  ADR 0019/0021 (attention negotiation), ADR 0024 (correction lexicon),
  ADR 0027 (wake propagation), ADR 0028 (day summaries)
- Closed PR #3525 (spool-based predecessor, unmerged reference)
