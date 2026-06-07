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
4. The workflow never uses `AgentSlots.activeDayId` as authoritative day
   context.
5. Day-scoped tool calls are rejected when their `dayId` differs from the wake
   workspace.
6. Raw captures and parsed items are day-scoped. Cross-day learning enters the
   prompt only through deliberate summaries, observations, reports, recent-plan
   cards, or planner memory.
7. Wake queue and scheduling semantics distinguish day workspaces under the
   shared planner identity.
8. Provider-specific inference details stay behind provider-neutral tool-choice
   contracts.

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

AnalysisBriefEntity (or equivalent report artifact)
  id
  plannerAgentId
  workspaceKey = day:<dayId> | week:<isoWeek> | project:<id> | category:<id>
  horizonStart / horizonEnd
  sourceRefs[]
  findings[]
  recommendations[]
  confidence
  validUntil
```

If adding `dayId` directly to `CaptureEntity` creates too much generated-code
churn in one PR, an equivalent deterministic `captureDay` link is acceptable
only as a short step inside the same rollout. The final model should make day
scope cheap and explicit to query.

Analysis briefs do not have to be a new entity in the first planner refactor if
an existing report/message shape can carry the artifact cleanly. The important
contract is that disposable analyst runs write a compact, evidence-linked
artifact and then close; the planner never imports their raw transcript as main
context.

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

## Disposable Analyst Runs

The long-lived planner may need deeper investigations than a normal day wake
should carry in context. Examples:

- Analyze why planned work spilled over during the last seven days.
- Compare planned capacity with actual tracked time by category.
- Inspect a project and explain why it repeatedly displaces health blocks.
- Summarize unresolved capture phrases across a week.

These should be modeled as one-off analyst conversations:

1. The planner or UI starts an analyst run with a bounded question, workspace
   key, horizon, and source set.
2. The analyst run may call read tools and inspect a larger local corpus than a
   normal planner wake.
3. The analyst run writes one compact artifact: findings, evidence refs,
   confidence, recommendations, and optional proposed follow-up questions.
4. The analyst run is closed. It is not a durable agent identity.
5. The planner reads the artifact and decides whether it becomes an
   observation, attention claim, plan diff, or just background context.

This keeps the planner long-running without turning every planning wake into a
large analysis context.

## PR Sequence

### PR 1 - Planner identity and day workspace contract

Goal: introduce the new contract without changing every persistence path.

Touches:

- `day_agent_slots.dart`
- `day_agent_reconcile_models.dart`
- `day_agent_service.dart`
- `day_agent_workflow.dart`
- day-agent service/workflow tests

Work:

1. Add `planning_day:<dayId>` token helpers.
2. Add `DailyOsPlannerWakeContext` and pure parsing/validation helpers.
3. Add `getOrCreatePlannerAgent()` to `DayAgentService`.
4. Keep `AgentIdentityEntity.kind == day_agent` for now.
5. Stop creating one agent per date in new day-agent service paths.
6. Make enqueue methods target the planner and include `planning_day:<dayId>`.
7. Update workflow prompt wording from "one agent for exactly one local
   calendar day" to "one planner operating on the current day workspace".
8. Keep old methods only as thin compatibility wrappers if still needed by UI
   call sites, and delete them once callers are moved.

Done when:

- Creating/using two dates yields one planner identity.
- Draft/refine enqueue tokens include the correct `planning_day:<dayId>`.
- Workflow can resolve day context without `AgentSlots.activeDayId`.
- Workflow rejects a mismatched model `dayId` in plan tools.

### PR 2 - Day-scoped captures and providers

Goal: prevent cross-day capture leaks under one planner.

Touches:

- `agent_domain_entity.dart` and generated files via build runner
- `day_agent_capture_service.dart`
- `day_capture_events.dart`
- `day_agent_context_builder.dart`
- `day_agent_provider.dart`
- capture/reconcile/provider tests

Work:

1. Add required `dayId` to `CaptureEntity`.
2. Stamp `dayId` when submitting typed, voice, and refine captures.
3. Resolve parse wakes from `capture.dayId` when needed.
4. Filter capture lists, parse context, and day capture events by `dayId`.
5. Update `capturesForDateProvider` to query planner captures for one
   workspace, not all captures by date-agent id.

Done when:

- Captures created for two dates under one planner do not appear in each
  other's Capture panel.
- Capture parse wake with only `capture_submitted:<captureId>` resolves the
  correct day workspace.
- Compacted day log excludes raw captures from unrelated days.

### PR 3 - Workspace-aware wake queue and scheduled wakes

Goal: make one planner safe with multiple outstanding day jobs.

Touches:

- `wake_queue.dart`
- `wake_orchestrator.dart`
- `scheduled_wake_manager.dart`
- day-agent service enqueue paths
- wake queue/orchestrator tests

Work:

1. Add an optional workspace key to wake jobs. For Daily OS day-scoped wakes,
   use `day:<dayId>`.
2. Change manual wake superseding so it removes/merges only matching
   `(agentId, workspaceKey, reason class)` work where appropriate.
3. Preserve the existing single-flight runner by `agentId` unless there is a
   demonstrated need for concurrent planner runs. Serialization is acceptable
   for planner judgment.
4. Decide `set_next_wake` semantics:
   - global-only planner wake, or
   - persisted scheduled wake records with trigger tokens and workspace key.
5. Do not restore day-specific scheduled wakes with empty trigger tokens.

Done when:

- A draft wake for one day cannot drop a parse/refine wake for another day.
- Restored scheduled wakes either have workspace context or are explicitly
  global planner wakes.

### PR 4 - Planner memory split

Goal: use the long-lived planner memory intentionally without polluting day
workspace prompts.

Touches:

- `day_agent_workflow.dart`
- `day_capture_events.dart`
- `AgentWakeMemory` call sites
- observation persistence/extraction if scope fields are added
- workflow/memory tests

Work:

1. Treat planner observations as global unless explicitly day-scoped.
2. Add observation scope if needed: `global`, `day`, plus optional `dayId`.
3. Feed compacted planner memory as global context.
4. Feed raw captures, parsed items, baseline plan, refine transcript, and
   decided items only for the active `dayId`.
5. Keep `summarize_recent_patterns` cross-day, because that is intentional
   learning.

Done when:

- Recent-pattern cards can see multiple days owned by one planner.
- Raw captures from unrelated days are absent from the prompt.
- Global observations remain available across days.

### PR 5 - Plan, refine, commit, and UI adapter cleanup

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

### PR 6 - Documentation and old-model removal

Goal: make the codebase describe the implemented model.

Touches:

- `lib/features/daily_os_next/README.md`
- stale implementation plans that mention one agent per day
- code comments and names where practical
- tests that still assert old identity behavior

Work:

1. Update feature README architecture diagrams.
2. Mark the old per-day identity plan as superseded by ADR 0022.
3. Remove compatibility wrappers and unused day-agent lookup methods.
4. Rename helpers where useful:
   - `dayAgentIdForDate` should not imply agent identity.
   - prefer `dayIdForDate` or `dayWorkspaceIdForDate`.
5. Keep persisted kind/name churn for a separate cleanup only if it does not
   obscure the core refactor.

Done when:

- No production path needs one `AgentIdentityEntity` per day.
- Docs and comments no longer teach the obsolete model.

### PR 7 - Disposable analyst runs and analysis artifacts

Goal: let the planner delegate bounded investigations without polluting its main
context.

Touches:

- planner workflow / service boundary
- analysis artifact model or report-message convention
- read-only analyst tools
- prompt reconstruction / inspectability surfaces
- analyst-run tests

Work:

1. Define the analysis artifact shape. Prefer a first-class
   `AnalysisBriefEntity` only if existing report/message entities cannot carry
   workspace, horizon, evidence refs, and validity cleanly.
2. Add a `startAnalysisRun` service path that accepts a bounded question,
   workspace key, horizon, and allowed source refs.
3. Restrict analyst tools to read-only corpus/context tools at first.
4. Persist exactly one compact brief per completed analysis run.
5. Ensure the planner consumes briefs as summarized inputs, not raw analyst
   transcripts.
6. Add retention/expiry semantics via `validUntil` or equivalent metadata so
   stale analysis does not become permanent truth.

Done when:

- A week-analysis run can inspect several day plans and actuals, write a brief,
  and close.
- The planner prompt includes the brief summary and evidence refs without the
  analyst transcript.
- Failed or abandoned analyst runs do not affect planner memory.

## Required Tests

Add or update focused tests before broad suite runs:

- `day_agent_service_test.dart`
  - `getOrCreatePlannerAgent` is idempotent.
  - Two dates use the same planner identity.
  - Draft/refine/capture wake tokens include `planning_day:<dayId>`.

- `day_agent_workflow_test.dart`
  - workflow ignores stale `AgentSlots.activeDayId`;
  - workflow derives day from wake context;
  - workflow rejects mismatched tool `dayId`;
  - forced `parse_capture_to_items` and `draft_day_plan` retries remain
    provider-neutral.

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

- Analyst-run tests:
  - analysis run writes one compact artifact and then closes;
  - planner context includes the artifact, not the raw transcript;
  - analyst tool access is read-only in the first implementation;
  - stale `validUntil` briefs are excluded or marked stale.

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
| Day context leak under one planner | Add `dayId` to captures, validate tool `dayId`, filter raw context by workspace |
| One wake drops another day's wake | Add workspace key to wake queue dedupe/superseding |
| Scheduled wake restores without day context | Make scheduled wakes global-only or persist trigger tokens/workspace key |
| Slow draft blocks parse/refine for another day | Keep single-flight initially for planner consistency; revisit only with evidence |
| Provider-specific forced tool behavior regresses | Keep generic `ChatCompletionToolChoiceOption` tests for Gemini, Mistral, and cloud routing |
| Old docs/tests reintroduce per-day identity | Mark old plan superseded and remove compatibility wrappers after call sites move |
| Analyst runs bloat planner context | Persist compact artifacts with evidence refs; exclude raw analyst transcripts from planner prompt |
| Analyst findings become stale truth | Add horizon and `validUntil`; planner treats briefs as dated evidence |

## Non-Goals

- Renaming the persisted `day_agent` kind everywhere in the same PR. The runtime
  semantics matter more than naming churn.
- Introducing autonomous plan mutation. Planner proposals still flow through
  existing validation and user/standing-agreement gates.
- Rewriting task agents. Task agents should stay one agent per task.
- Building a deterministic planner fallback. This refactor is about identity,
  workspace scope, and memory correctness.
- Making analyst runs durable agents by default. They are one-off scoped
  conversations unless a future domain proves it needs its own durable identity.

## Open Decisions

1. Should day-specific scheduled wakes become first-class synced entities, or
   should `set_next_wake` remain global-only until a concrete per-day need is
   proven?
2. Should observation scope be represented directly in `ObservationRecord`, or
   should scoped observations be modeled as message/link metadata?
3. Should wake queue workspace keys be generic across all agent kinds now, or
   introduced as optional metadata used only by Daily OS first?
4. When the implementation is complete, should the persisted kind be renamed
   from `day_agent` to `daily_os_planner`, or is that churn not worth the
   migration?
5. Should analysis briefs be a new `AgentDomainEntity` variant, an
   `AgentReportEntity` scope, or a structured message payload linked from the
   planner log?
6. Which read tools should analyst runs get first: day plans and actuals only,
   or also task/project/capture corpus search?

## Success Criteria

- A user can plan multiple dates with one planner identity.
- Recent-pattern cards and planner memory reflect previous days.
- Capture, reconcile, draft, refine, and commit remain isolated by selected day.
- Interleaved wakes for different days do not cancel or corrupt each other.
- The code no longer relies on `AgentSlots.activeDayId` to decide what day a
  planner wake is operating on.
- Gemini, Mistral, and OpenAI-compatible providers can all honor required
  planning tool calls through the generic tool-choice contract.
- Scoped analyst runs can answer bounded week/day/project questions, persist a
  compact brief, and close without expanding the planner's raw context.
