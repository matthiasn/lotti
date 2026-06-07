# Long-Lived Daily OS Planner - Implementation Plan

- Status: Plan accepted; implementation pending
- Date: 2026-06-07
- Decision baseline: [ADR 0022](../adr/0022-long-lived-daily-os-planner.md)
- Scope: refactor Daily OS Next from one day-agent identity per date to one
  long-lived planner identity with explicit day workspaces.

## Goal

Make Daily OS planning useful by giving it durable cross-day memory while
preserving day-local safety. The planner should remember recent plans,
captures, observations, outcomes, category patterns, and user decisions across
days, but every day-specific wake and tool call must be scoped to a concrete
`dayId`.

This is a direct correction, not a compatibility bridge. Daily OS Next has low
current usage, so the implementation should target the correct steady-state
model and remove stale per-day identity assumptions as it goes.

## Current Problem

The current implementation uses the day as the agent identity:

- `dayAgentIdForDate(date)` returns the day-plan id.
- `DayAgentService.createDayAgent` creates one active `AgentIdentityEntity` per
  local calendar day and stores the day in `AgentSlots.activeDayId`.
- `DayAgentWorkflow.execute` reads the target day from the reconciled agent
  state slot.
- `DayAgentPlanService.summarizeRecentPatterns` reads recent plans by
  `agentId`.
- `DayAgentWorkflow` reads observations, captures, and compaction memory by
  `agentId`.

This makes each day a separate mind. It also hides day context in identity, so a
naive long-lived refactor would leak all captures and prompt context across
every day.

## Target Invariants

1. There is one active Daily OS planner identity.
2. A day is represented by `dayId`, not by `agentId`.
3. Day-scoped wakes always carry `planning_day:<dayId>` or resolve `dayId`
   through a workspace-bound capture.
4. The workflow never reads `AgentSlots.activeDayId`, and the projection stops
   deriving/persisting it for the planner (no per-day `AgentDayLink`).
5. Day-scoped tool calls are rejected when their `dayId` differs from the wake
   workspace.
6. Raw captures and parsed items are day-scoped. Cross-day learning enters the
   prompt only through deliberate summaries, observations, reports, recent-plan
   cards, or planner memory.
7. Wake queue and scheduling semantics distinguish day workspaces under the
   shared planner identity — across supersede, dedupe, token merge, and token
   extraction.
8. Provider-specific inference details stay behind provider-neutral tool-choice
   contracts.
9. User-stated knowledge persists in a durable, compaction-exempt store and is
   revisable by recency; agent-inferred observations reach durable knowledge only
   through the weekly gate or explicit user confirmation.
10. Nothing in the planner depends on a domain agent existing, but the planner
    remains the durable counterparty domain agents (ADR 0023) will negotiate
    with via attention claims.

## Target Data Model

```text
plannerAgentId
  AgentIdentityEntity.kind = day_agent (name may be cleaned up later)
  AgentStateEntity slots.activeDayId = ignored for planner execution

dayId
  dayplan-YYYY-MM-DD

DayPlanEntity
  id = day_agent_plan:<dayId>
  agentId = plannerAgentId
  dayId = dayId
  planDate = local date

CaptureEntity
  agentId = plannerAgentId
  dayId = dayId              // new required day workspace
  transcript, capturedAt, audioRef...

ParsedItemEntity
  agentId = plannerAgentId
  captureId = CaptureEntity.id
  day scope = capture.dayId

ChangeSetEntity
  agentId = plannerAgentId
  taskId or target id = day_agent_plan:<dayId>

PlannerKnowledgeEntity        // new AgentDomainEntity variant; durable, compaction-exempt
  id
  agentId = plannerAgentId
  key                         // stable slug, e.g. "deep-work-earliest-start"
  hook                        // one-line index entry (like memory `description`)
  value                       // structured or text, e.g. "10:00 local"
  statementText               // verbatim "never schedule deep work before 10am"
  source = userStated | agentInferred
  status = proposed | confirmed | retracted
  supersedesId?               // the prior entry this replaces (recency-wins)
  scope = global | category:<id> | project:<id>
  createdAt, confirmedAt?, retractedAt?, reviewAfter?
  vectorClock
```

`CaptureEntity.dayId` must be **sync-safe**: it has to be a defaulted or
derived-on-read field, not a `required` freezed field. A peer on an older build
emits captures with no `dayId`, and a required, non-defaulted field throws on
`fromJson`. Follow the existing forward-compatible pattern (e.g. the defaulted
`milestone` field). If adding `dayId` directly to `CaptureEntity` still creates
too much generated-code churn in one PR, an equivalent deterministic
`captureDay` link is acceptable only as a short step inside the same rollout.
The final model should make day scope cheap and explicit to query.

`PlannerKnowledgeEntity` is the durable, compaction-exempt store for
"memorize what I tell you" (ADR 0022 Decisions 9–10). It is detailed in the
"Durable Planner Knowledge" section below. Deep disposable analysis runs are
**out of scope** for this refactor (ADR 0022 Decision 13); if reintroduced
later they reuse the existing `AgentReportEntity` scope, not a new entity.

## Wake Contract

Introduce a small explicit context object near the day-agent workflow/domain
boundary:

```dart
class DailyOsPlannerWakeContext {
  DailyOsPlannerWakeContext({
    required this.plannerAgentId,
    required this.dayId,
    required this.reason,
    required this.runKey,
    required this.threadId,
    required this.triggerTokens,
    this.captureId,
    this.decidedTaskIds = const [],
    this.decidedCaptureItemIds = const [],
  });

  final String plannerAgentId;
  final String dayId;
  final String reason;
  final String runKey;
  final String threadId;
  final Set<String> triggerTokens;
  final String? captureId;
  final List<String> decidedTaskIds;
  final List<String> decidedCaptureItemIds;
}
```

Token rules:

- Every day-scoped wake includes `planning_day:<dayId>`.
- Drafting wakes include `drafting:<dayId>`.
- Refine wakes include `refine:<dayId>`.
- Capture parse wakes may resolve `dayId` from `capture_submitted:<captureId>`
  if the token set lacks `planning_day:<dayId>`, but enqueue sites should prefer
  including both.
- Workflow fails fast when a day-scoped wake has no resolvable `dayId`.
- Plan and capture tools validate `args.dayId == context.dayId` when a tool
  accepts `dayId`.

## Durable Planner Knowledge (memorize what the user tells you)

A long-lived planner is only useful if it durably remembers what the user tells
it. The current substrate cannot guarantee this: user instructions enter through
agent-inferred `record_observations`, land in the shared compaction fold
(ADR 0017), and are re-summarized lossily on every fold for the life of the
planner — so "never schedule deep work before 10am" slowly dissolves. The old
plan's `propose_preference` / `confirm_preference` / `retract_preference` tools
were specified but never built. This section closes that gap.

### Two memory loops

- **Fast loop (daily, unsupervised):** raw day-scoped inputs and agent-inferred
  observations accrue as episodic memory on the planner's log, compacted per
  ADR 0017. High volume, low trust, automatically aged.
- **Slow loop (weekly, supervised — the one-on-one):** the existing
  `TemplateEvolutionWorkflow` ritual, now bound to the single planner identity,
  consolidates recurring observations into durable knowledge and template
  directives, gated by the user. Wiring `day_agent` as a participating kind
  completes the old plan's unfinished step.

Promotion is the relationship between them: a day-scoped observation becomes
durable knowledge only when (a) the user confirms it directly, or (b) it recurs
across distinct days and passes the weekly gate. Episodic memory can be aged
aggressively *because* anything worth keeping is promoted.

### `PlannerKnowledgeEntity`

A new `AgentDomainEntity` variant persisted on the existing `agent_entities`
table (no new Drift table), modeled on the durable `Version` / `Head` snapshot
pattern already used by `AgentTemplateVersionEntity` and the soul document.
Fields are listed in Target Data Model above. Key properties:

1. **Keyed and supersedable.** A `Head` selects the active entry per `key` among
   non-retracted entries by recency. Monday's "X" is cleanly superseded by
   Friday's "not-X" via `supersedesId`; retraction is explicit, not LLM-guessed.
2. **Direct user-to-durable path.** Reintroduce the tool trio as real handlers:
   `propose_knowledge {key, value, statement, scope, source}` (writes
   `status = proposed`), and user-gated `confirm_knowledge` / `retract_knowledge`
   surfaced in the "What I've learned" panel. A `source = userStated` instruction
   may skip straight to `confirmed`. This is the path user instructions take
   instead of `record_observations`.
3. **Compaction-exempt, surfaced two-tier (Claude Code memory-index pattern).**
   `PlannerKnowledgeEntity` is its own kind, **excluded from
   `projectInputEvents`' fold substrate** and from the compaction tail, so it is
   never re-summarized. But injecting the *entire* confirmed `Head` set every
   wake re-creates unbounded prompt growth as the planner ages. Instead, mirror
   Claude Code's `MEMORY.md`: each entry carries a one-line `hook` (like the
   memory `description` field), and the prompt always carries only the **compact
   index of hooks**. The full `statementText` of an item is retrieved **on
   demand, scoped** to the active workspace — `scope = global` always present,
   `category:` / `project:` pulled when the wake touches that scope — using the
   same scoped-retrieval machinery as attention claims. A small set of always-on
   critical items may still be injected verbatim (cf. ADR 0014). The summarizer's
   soft "preserve preferences" instruction becomes a backstop, not the only
   defense.
4. **User-editable, with staleness re-confirm.** Borrowing Claude Code's
   editable-and-dated memory: the "What I've learned" panel lets the user **edit**
   a durable fact directly (not just confirm/retract), and each entry stamps
   `confirmedAt` / `reviewAfter`. A durable preference that has gone stale or
   unexercised re-surfaces for re-confirmation ("you told me 'no deep work before
   10' a while ago — still true?") rather than being treated as permanent truth.
   This closes the ADR 0022 stale-durable-memory risk.
5. **Reconciled with the weekly ritual.** The weekly `TemplateEvolutionWorkflow`
   folds confirmed knowledge into the next user-approved template version. Daily
   = fast capture into the durable store; weekly = consolidation into directives.
   The knowledge store is the single source of truth both read, eliminating
   drift between "the template says X" and "an observation says not-X".

### What we deliberately do NOT copy from Claude Code memory

- **Agent-writes-freely.** Claude Code lets the agent write memories directly;
  Lotti keeps the stricter `propose_knowledge` → user-`confirm_knowledge` gate,
  appropriate for the planner's longer-horizon autonomy.
- **The file/frontmatter format.** Lotti takes the *schema shape* (key, hook,
  type, supersedes, scope) into a synced freezed entity with vector clocks and
  conflict resolution (ADR 0016/0018), not single-machine Markdown files.

Deep disposable analysis runs are deferred (ADR 0022 Decision 13); most
questions they would answer ("why does this project keep displacing workouts?")
belong to a durable domain agent (ADR 0023) instead.

## PR Sequence

**Ordering principle — make the system workspace-safe before flipping identity.**
The earlier draft of this plan collapsed identity in PR1 but only fixed capture
day-scope (PR2) and the wake queue (PR3) afterward, leaving a window where every
day's Capture panel and drafting prompt leaked other days' captures and one day's
manual wake could cancel another day's queued work. The corrected sequence lands
all the workspace plumbing **additively under the existing per-day identity**
(PR1–PR3), then flips to one planner once the flip is provably safe (PR4). The
identity cutover (PR4) **must not ship to users without PR2 and PR3**.

### PR 1 - Day workspace contract (additive, identity unchanged)

Goal: introduce the workspace vocabulary and wake context without changing
identity creation. Per-day identities still exist, so existing behavior is
preserved and nothing leaks yet.

Touches:

- `day_agent_slots.dart`
- `day_agent_reconcile_models.dart`
- `day_agent_service.dart`
- `day_agent_workflow.dart`
- day-agent service/workflow tests

Work:

1. Add `planning_day:<dayId>` token helpers alongside the existing `drafting:` /
   `refine:` tokens.
2. Add `DailyOsPlannerWakeContext` and pure parsing/validation helpers.
3. **Make the token extraction helpers workspace-filtered.** Today
   `draftingDayIdFromTriggerTokens` / `refineDayIdFromTriggerTokens` return the
   *first* matching token from a `Set` (non-deterministic). They must instead
   return the token whose `dayId` matches the resolved workspace, so they are
   correct once one identity owns many days and a merged token set holds
   `drafting:dayA` + `drafting:dayB`.
4. Add `getOrCreatePlannerAgent()` to `DayAgentService` (no cutover path uses it
   yet).
5. Have the workflow resolve target day from wake context + trigger tokens, while
   still tolerating the current per-day slot as a fallback so behavior is
   unchanged this PR.

Done when:

- Wake context resolves day from tokens; extraction helpers are deterministic
  under a merged day-A + day-B token set (unit-tested).
- Existing per-day behavior is unchanged.

### PR 2 - Workspace-aware wake queue and scheduled wakes (additive)

Goal: make the queue safe for one planner with multiple outstanding day jobs,
before any identity flip. Still per-day identity, so this is a safe refactor of
the existing queue with its existing tests as a regression guard.

Touches:

- `wake_queue.dart`
- `wake_orchestrator.dart`
- `scheduled_wake_manager.dart`
- day-agent service enqueue paths
- wake queue/orchestrator/scheduled-wake tests

Work:

1. Add an optional workspace key to wake jobs. For Daily OS day-scoped wakes,
   use `day:<dayId>`.
2. Make superseding (`removeByAgent`), dedupe (`hasQueuedJobFor`), **and token
   merge (`mergeTokens`)** partition by `(agentId, workspaceKey, reason class)`.
   `mergeTokens` and `removeByAgent` are agentId-only today, so they must be
   taught the workspace/reason taxonomy or they will collide cross-day under one
   planner. Define the reason-class taxonomy (capture / draft / refine /
   creation) so same-day-different-reason work is not wrongly dropped.
3. Preserve the existing single-flight runner by `agentId`. Document that one
   planner therefore serializes day work across days (acceptable for planner
   judgment; revisit only with evidence).
4. Resolve `set_next_wake` semantics: either global-only planner wakes, or
   persisted scheduled-wake records carrying trigger tokens and a workspace key.
5. **Preserve the day-scoped morning pre-warm.** A single `scheduledWakeAt`
   cannot hold several day wakes, and a context-less scheduled wake cannot drive
   a day-scoped pre-warm. If `set_next_wake` stays global-only, the pre-warm must
   carry its day through a persisted record, not an empty-token wake.

Done when:

- A day-B capture wake cannot drop or merge into a day-A draft/refine wake
  (tested with two day workspaces under one agentId).
- Restored scheduled wakes either carry workspace context or are explicitly
  global; the morning pre-warm still resolves a concrete day.

### PR 3 - Day-scoped captures and providers (additive, sync-safe)

Goal: make day scope explicit on captures and queries before the identity flip
removes implicit per-day isolation. Still per-day identity, so `dayId` equals the
agent's only day and the new filters are correct no-ops until PR4.

Touches:

- `agent_domain_entity.dart` and generated files via build runner
- `day_agent_capture_service.dart`
- `day_capture_events.dart`
- `day_agent_context_builder.dart`
- `day_agent_provider.dart`
- capture/reconcile/provider tests

Work:

1. Add `dayId` to `CaptureEntity` as a **defaulted / derived-on-read** field, not
   `required` — a required freezed field throws on `fromJson` for captures synced
   from older peers. Thread it through `submitCapture`, `RealDayAgent`, and the
   `refine_capture:` build path.
2. Stamp `dayId` when submitting typed, voice, and refine captures.
3. Resolve parse wakes from `capture.dayId` when the token set lacks
   `planning_day:<dayId>` (e.g. only `capture_submitted:<captureId>` is present).
4. Filter capture lists, parse context, day capture events, and the workflow
   memory load by `dayId`.
5. Update `capturesForDateProvider` to query the day workspace, not all captures
   by agent id.

Done when:

- Captures synced from an older peer (no `dayId`) still deserialize and resolve a
  day on read.
- Capture lists and drafting context are day-filtered even when one agentId owns
  multiple days (tested under a shared agentId).
- The compacted day log excludes raw captures from unrelated days.

### PR 4 - Planner identity cutover (the flip)

Goal: collapse per-day identities into one long-lived planner. Safe **only
because** PR2 (workspace-aware queue) and PR3 (day-scoped captures) have landed.

Precondition: PR2 and PR3 merged. This PR must not ship to users without them.

Touches:

- `day_agent_service.dart`
- `derived_agent_state.dart` / `agent_sync_service.dart` (`activeDayId`
  projection)
- `day_agent_workflow.dart`
- day-agent service/workflow/state tests

Work:

1. Route creation/use through `getOrCreatePlannerAgent`; stop creating one
   identity per date. Enqueue paths target the planner and include
   `planning_day:<dayId>`.
2. **Fix the `activeDayId` projection, not just the read.** Stop creating one
   `AgentDayLink` per day for the planner (or exclude `activeDayId` from
   derivation, reconcile write-back, and the derived-field-mismatch
   diagnostics), so reconcile does not reconcile the slot to a single
   most-recent day and persist it on every wake.
3. Make the workflow derive day strictly from wake context; remove the per-day
   slot fallback added in PR1. The workflow MUST NOT read `AgentSlots.activeDayId`.
4. Reject day-scoped tool calls whose `args.dayId` differs from the wake
   workspace.
5. Keep `AgentIdentityEntity.kind == day_agent` (persisted-name churn deferred to
   PR7).

Done when:

- Two dates yield one planner identity (`getOrCreatePlannerAgent` idempotent).
- Reconcile no longer writes or derives a stale `activeDayId`; no permanent
  `activeDayId` derived-field mismatch.
- Interleaved day-A / day-B wakes neither cancel nor cross-contaminate
  (end-to-end test).

### PR 5 - Two-loop memory and durable knowledge

Goal: deliver durable cross-day learning and "memorize what I tell you" (see the
"Durable Planner Knowledge" section).

Touches:

- `day_agent_workflow.dart`
- `agent_domain_entity.dart` (new `PlannerKnowledgeEntity` variant, generated)
- `day_agent_tool_names.dart` + knowledge handlers
- compaction / projection (exempt knowledge from the fold; inject standing block)
- `template_evolution_workflow.dart` (register `day_agent` as a participating kind)
- observation persistence/extraction if scope fields are added
- workflow / memory / knowledge tests

Work:

1. Add `PlannerKnowledgeEntity` + `Head` selection by `key` (recency,
   non-retracted).
2. Add `propose_knowledge` / `confirm_knowledge` / `retract_knowledge` handlers;
   surface them in the "What I've learned" panel. `source = userStated` may go
   straight to `confirmed`.
3. Exempt knowledge from compaction; inject the confirmed `Head` set as a stable
   "Standing knowledge" prompt block (cf. ADR 0014).
4. Split memory: feed compacted episodic memory as cross-day context; feed raw
   captures, parsed items, baseline plan, refine transcript, and decided items
   only for the active `dayId`; keep `summarize_recent_patterns` cross-day.
5. Wire `day_agent` into `TemplateEvolutionWorkflow` as the weekly promotion
   gate; confirmed knowledge feeds the next template version.
6. Add observation scope (`global` | `day` + optional `dayId`) if needed.

Done when:

- A user instruction persists as confirmed knowledge, survives a compaction fold,
  and appears in the next wake's prompt.
- Contradicting knowledge supersedes by recency rather than both persisting.
- Recent-pattern cards see multiple days under one planner; raw captures from
  unrelated days are absent from the prompt.

### PR 6 - Plan, refine, commit, and UI adapter cleanup

Goal: remove remaining "agent for date" assumptions from user-facing flows.

Touches:

- `real_day_agent.dart`
- `day_agent_plan_service.dart`
- `day_agent_provider.dart`
- `drafting_controller.dart`
- `refine_controller.dart`
- `shutdown_controller.dart`
- Daily OS Next UI tests

Work:

1. Replace date-agent lookups with planner + day workspace calls.
2. Ensure `currentPlanForDate`, `draftDayPlan`, `proposePlanDiff`, `commitDay`,
   `uncommitDay`, and rename/mutation paths all pass explicit day context.
3. Keep `DayPlanEntity.id = day_agent_plan:<dayId>`.
4. Ensure `pendingPlanDiffsForDay` and plan diff application are scoped by
   planner plus day-plan target.
5. Update provider invalidation to watch planner id, day id, plan id, capture
   ids, and the broad agent notification where needed.

Done when:

- Capture -> parse -> reconcile -> draft -> refine -> commit works for one day.
- The same flow works interleaved across two selected days under one planner.
- UI updates for one day do not show another day's captures or pending diffs.

### PR 7 - Documentation and old-model removal

Goal: make the codebase describe the implemented model.

Touches:

- `lib/features/daily_os_next/README.md`
- stale implementation plans that mention one agent per day
- code comments and names
- tests that still assert old identity behavior

Work:

1. Update feature README architecture diagrams.
2. Mark the old per-day identity plan as superseded by ADR 0022.
3. Remove compatibility wrappers and unused day-agent lookup methods.
4. **Rename the non-persisted Dart symbols and file names off `day_agent_*`
   within this refactor** (zero sync cost): `dayAgentIdForDate` ->
   `dayIdForDate` / `dayWorkspaceIdForDate`, and the `day_agent_*` file tree
   toward planner-shaped names. Half-renaming entrenches the confusion this
   refactor exists to remove — and it becomes actively wrong once domain agents
   (ADR 0023) exist.
5. Keep the **persisted** `kind` string (`day_agent`) and
   `DayPlanEntity.id = day_agent_plan:<dayId>` deferred — those carry real
   multi-device migration cost (Open Decision 4).

Done when:

- No production path needs one `AgentIdentityEntity` per day.
- Docs, comments, and non-persisted symbol names no longer teach the obsolete
  model.

### Out of scope: domain agents and disposable analysis

Durable domain agents (fitness, sleep) that negotiate with this planner for
calendar time are specified in **ADR 0023** and implemented in a separate plan.
They are not part of this refactor; this refactor only makes the planner the
durable, learning counterparty they will negotiate with. Deep disposable analyst
runs are deferred (ADR 0022 Decision 13).

## Required Tests

Add or update focused tests before broad suite runs:

- `day_agent_service_test.dart`
  - `getOrCreatePlannerAgent` is idempotent.
  - Two dates use the same planner identity.
  - Draft/refine/capture wake tokens include `planning_day:<dayId>`.

- `day_agent_workflow_test.dart`
  - workflow never reads `AgentSlots.activeDayId`;
  - reconcile does not persist a stale `activeDayId` for a multi-day planner;
  - workflow derives day from wake context;
  - workflow rejects mismatched tool `dayId`;
  - forced `parse_capture_to_items` and `draft_day_plan` retries remain
    provider-neutral.

- wake queue / scheduled-wake tests
  - a day-B manual wake does not `removeByAgent`-drop a queued day-A draft/refine;
  - `mergeTokens` does not merge day-B tokens into a day-A job;
  - token extraction is deterministic under a merged day-A + day-B token set;
  - the day-scoped morning pre-warm resolves a concrete day after restore.

- `day_agent_capture_service_test.dart`
  - submitted captures persist `dayId`;
  - parse wake resolves day from capture;
  - parsed items inherit scope through capture.

- `day_agent_provider_test.dart`
  - `capturesForDateProvider` returns only captures for the selected date under
    one planner.

- `day_agent_plan_service_test.dart`
  - `summarizeRecentPatterns` sees multiple days owned by the same planner.
  - `draftPlanForDay`, diff, commit, and uncommit stay scoped by `dayId`.

- `real_day_agent_test.dart`
  - no "no day agent exists for date" behavior on normal paths;
  - adapter resolves planner once and passes day workspace explicitly.

- Focused end-to-end test:
  - submit capture for day A;
  - parse/reconcile/draft;
  - submit capture for day B;
  - verify day A context and day B context do not leak;
  - refine and commit day A.

- durable-knowledge tests (PR5):
  - `propose_knowledge` then `confirm_knowledge` persists a confirmed entry;
  - confirmed knowledge survives a compaction fold (not folded into the summary);
  - the prompt always carries the hook index; a `category:`-scoped item's full
    `statementText` is pulled in only on a wake touching that category;
  - contradicting knowledge supersedes by recency (`supersedesId`), not both;
  - `retract_knowledge` removes an entry from the active `Head` set;
  - a past-`reviewAfter` entry surfaces for re-confirmation rather than applying
    silently;
  - `summarizeRecentPatterns` still sees multiple days under one planner.

## Verification Strategy

Per PR:

1. Run `fvm dart format` on touched Dart files.
2. Run targeted tests for touched source files.
3. Run `dart-mcp.analyze_files` for touched Dart files when the analysis server
   is stable; otherwise document the analyzer failure and run the closest
   `fvm flutter analyze` fallback.
4. Run `git diff --check`.

Before merging the full refactor:

1. Run all Daily OS Next agent/service/state tests.
2. Run the focused end-to-end Daily OS Next flow.
3. Run `make analyze`.
4. Run broader tests only when the targeted suites are clean.

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Broken intermediate state from flipping identity too early | Land workspace plumbing additively (PR1–PR3) under per-day identity; flip in PR4 only after PR2+PR3 |
| Day context leak under one planner | Add `dayId` to captures, validate tool `dayId`, filter raw context by workspace |
| `activeDayId` corrupted by projection | Stop creating the per-day `AgentDayLink` for the planner (or exclude `activeDayId` from derivation/reconcile/diagnostics), not just "ignore the read" |
| One wake drops/merges another day's wake | Make `removeByAgent`, dedupe, **and `mergeTokens`** partition by `(agentId, workspaceKey, reason class)`; make token extractors workspace-filtered |
| Required `CaptureEntity.dayId` breaks sync deserialization | Make `dayId` defaulted/derived, never `required`; follow the existing forward-compatible default pattern |
| Scheduled wake restores without day context | Make scheduled wakes global-only or persist trigger tokens/workspace key; preserve the day-scoped morning pre-warm explicitly |
| Slow draft blocks parse/refine for another day | Keep single-flight initially for planner consistency; revisit only with evidence |
| Per-wake projection cost grows with planner lifetime | Track as a follow-up: projection snapshot / incremental fold once one identity replaces N tiny per-day logs |
| Durable memory becomes stale truth | Recency-wins supersession for confirmed knowledge; weekly gate for promotion; recency-weighted episodic memory |
| Provider-specific forced tool behavior regresses | Keep generic `ChatCompletionToolChoiceOption` tests for Gemini, Mistral, and cloud routing |
| Old docs/tests reintroduce per-day identity | Mark old plan superseded and remove compatibility wrappers after call sites move |

## Non-Goals

- Renaming the persisted `day_agent` kind everywhere in the same PR. The runtime
  semantics matter more than naming churn.
- Introducing autonomous plan mutation. Planner proposals still flow through
  existing validation and user/standing-agreement gates.
- Rewriting task agents. Task agents should stay one agent per task.
- Building a deterministic planner fallback. This refactor is about identity,
  workspace scope, and memory correctness.
- Building domain agents (fitness, sleep). They are specified separately in
  ADR 0023; this refactor only makes the planner the durable counterparty they
  negotiate with.
- Disposable analyst runs. Deferred per ADR 0022 Decision 13.

## Open Decisions

1. **(Resolved — must be decided in PR2, not left open.)** Day-scoped scheduled
   wakes cannot ride a single `scheduledWakeAt`. PR2 must pick: global-only
   planner wakes, or persisted scheduled-wake records with workspace key +
   trigger tokens. Either way the day-scoped morning pre-warm must survive.
2. Should observation scope be represented directly in `ObservationRecord`, or
   should scoped observations be modeled as message/link metadata?
3. Should wake queue workspace keys be generic across all agent kinds now, or
   introduced as optional metadata used only by Daily OS first?
4. When the implementation is complete, should the persisted kind be renamed
   from `day_agent` to `daily_os_planner`, or is that churn not worth the
   migration?
5. Should `PlannerKnowledgeEntity` be its own `AgentDomainEntity` variant
   (preferred, mirroring `Version`/`Head`), or can confirmed knowledge ride an
   `AgentReportEntity` scope?
6. What is the promotion threshold from agent-inferred observation to `proposed`
   knowledge — N recurrences across distinct days, the weekly gate only, or both?
7. Do domain agents (ADR 0023) reuse `PlannerKnowledgeEntity` for their own
   user-stated facts, or hold a per-agent variant? (Cross-ref ADR 0023.)

## Success Criteria

- A user can plan multiple dates with one planner identity.
- Recent-pattern cards and planner memory reflect previous days.
- Capture, reconcile, draft, refine, and commit remain isolated by selected day.
- Interleaved wakes for different days do not cancel or corrupt each other.
- The code no longer relies on `AgentSlots.activeDayId` to decide what day a
  planner wake is operating on.
- Gemini, Mistral, and OpenAI-compatible providers can all honor required
  planning tool calls through the generic tool-choice contract.
- A user instruction ("never schedule deep work before 10am") persists as
  confirmed knowledge, survives compaction, and shapes later wakes — i.e. the
  planner memorizes what the user tells it.
- The weekly one-on-one ritual consolidates recurring daily observations into
  durable, user-approved knowledge, completing the two-loop learning model.
