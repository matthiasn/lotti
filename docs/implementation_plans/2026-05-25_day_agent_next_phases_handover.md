# Day Agent — Next Phases Handover (non-UI backend work)

**Date:** 2026-05-25
**Audience:** Whoever picks up agent-side phases 3 → 8.
**Scope:** What backend tools, services, providers, and seeded directives still need to land so the Daily OS Next UI can graduate from `MockDayAgent` to a fully real surface.

---

## Branch / commit

- **UI integration branch:** `feat/day_agent_layer`
- **Latest commit:** `e81fd4b33 feat: wire agent logic (partial)`
- **Rebase base:** `4c031cde2 feat: day planning agentic layer tooling (#3209)` (main)

---

## Real backend already wired

Six methods on `DayAgentInterface` now call the real agent layer through `RealDayAgent`
(`lib/features/daily_os_next/logic/real_day_agent.dart`):

| UI method | Backend route |
|---|---|
| `submitCapture(transcript, capturedAt)` | `DayAgentService.createDayAgent(date)` → `DayAgentCaptureService.submitCapture(...)`. Persists `CaptureEntity` + enqueues a parse wake. |
| `parseCaptureToItems(captureId)` | `DayAgentCaptureService.parsedItemsForCapture(captureId)`. Stream-driven via `parsedItemsForCaptureProvider(captureId)`. |
| `surfacePendingDecisions(forDate)` | `DayAgentCaptureService.surfacePendingDecisions(agentId, dayId)`. Adapter does `dayId = dayAgentIdForDate(date)`. |
| `applyTriage(taskId, action, deferTo)` | `DayAgentCaptureService.applyTriage(taskId, action.name, deferTo)`. Writes back via `JournalRepository.updateJournalEntity`. |
| `linkCapturePhraseToTask(parsedItemId, taskId)` | `DayAgentCaptureService.linkCapturePhraseToTask(...)`. (Not in `DayAgentInterface` — exposed as an adapter-only method for the "did you mean…" overflow menu.) |
| `breakCaptureLink(parsedItemId)` | `DayAgentCaptureService.breakCaptureLink(...)`. |

Adapter translations performed:
- `DayAgentPendingKind` → UI's `PendingItemReason` (one-to-one after the `missedRecurring` rename).
- `ParsedItemEntity.categoryId` → UI's `DayAgentCategory` via `JournalDb.getCategoryById` with an in-memory cache.
- `Task` → `matchedTaskTitle` for parsed items via `JournalDb.journalEntityById`.
- UI's `TriageAction` enum → backend's expected action string (`.name`).

Riverpod providers added in `lib/features/daily_os_next/agents/state/day_agent_providers.dart`:
- `dayAgentCaptureServiceProvider`
- `parsedItemsForCaptureProvider(captureId)`
- `pendingDecisionsForDateProvider(date)`

The legacy `agent_workflow_providers.dart` was refactored to consume the new
`dayAgentCaptureServiceProvider` instead of inlining the construction — one shared instance now.

---

## Still mocked

Twelve methods on `DayAgentInterface` delegate to `MockDayAgent` until their phases ship.
Each entry below tells the backend implementer what the UI sends, what it expects back,
and where the data should ultimately live.

### Drafting (phase 3 — screens 3 + 5)

#### `draftDayPlan({captureId, decidedTaskIds, dayDate, calendarBlocks})` → `DraftPlan`
- **Expected behavior:** LLM-driven inference. Reads the user's task corpus, energy bands, capacity config, and the parsed-capture decisions; emits a list of `TimeBlock`s (each AI-placed block carries a mandatory `reason` string), plus energy bands and capacity totals.
- **Source of truth:** Agent inference inside `DayAgentWorkflow`. New tool name `draft_day_plan`; new strategy dispatch.
- **Persistence target:** New `AgentDomainEntity.dayPlan` variant + `AgentLink.captureToPlan` (capture → plan). Each `TimeBlock` becomes a `PlannedBlock` row on the existing `DayPlanData` aggregate (`lib/classes/day_plan.dart`) **plus** a `reason: String?` field which currently does not exist on `PlannedBlock` — see Known gaps.

#### `summarizeRecentPatterns({asOf, lookbackDays})` → `List<LearningCard>`
- **Expected behavior:** Inference reads last N days of completed/carryover/observation data; emits three cards (`yesterday`, `weekSoFar`, gentle `nudge`). Gentle-nudge card carries a single `summary` + two pill labels.
- **Source of truth:** Inference inside the same drafting wake. Tool name `summarize_recent_patterns`.
- **Persistence target:** Transient — emit as part of the wake's tool output; the UI reads via the new Drafting provider. No durable persistence required (regenerated per draft).

### Refine (phase 4 — screen 6)

#### `proposePlanDiff({currentPlan, voiceTranscript})` → `PlanDiff`
- **Expected behavior:** Inference takes the current plan + a refinement transcript, emits a structured diff (`moved`, `added`, `dropped`), each change carrying `reason` and from→to times.
- **Source of truth:** Inference tool `propose_plan_diff`.
- **Persistence target:** **`ChangeSetEntity`** — existing structure. Parent plan §A locks this. Survives refresh; gives replay + audit.

#### `acceptDiff(diff)` → `DraftPlan`
- **Expected behavior:** Applies the diff's changes to the plan (move/add/drop blocks). Returns the resulting plan.
- **Source of truth:** Direct mutation tool `accept_diff` (no inference needed).
- **Persistence target:** Updates the existing `dayPlan` entity from §Drafting; marks the `ChangeSetEntity` resolved.

#### `revertDiff({diff, originalPlan})` → `DraftPlan`
- **Expected behavior:** Discards the proposed diff; returns the original plan unchanged.
- **Source of truth:** Direct mutation tool `revert_diff`.
- **Persistence target:** Marks `ChangeSetEntity` retracted; no plan mutation.

### Commit (phase 5 — screen 7)

#### `commitDay(plan)` → `DraftPlan`
- **Expected behavior:** Flips the day's `state` from `drafted` → `committed`; every drafted `TimeBlock.state` flips to `committed`. After this, the agent's role shifts from drafting to shepherding (no more re-proposals unless Refine is invoked).
- **Source of truth:** Direct mutation tool `commit_day`.
- **Persistence target:** Mutates the `dayPlan` entity's state field. The existing `DayPlanStatus` (draft / agreed / needsReview) already exists — extend with `committed` or repurpose `agreed`. The `Day` aggregate needs a `state` field added per parent plan §C.

### Shutdown (phase 6 — screen 8)

#### `surfaceShutdownData({forDate})` → `({completed, carryover, metrics})`
- **Expected behavior:** Direct read. `completed` is tasks whose `status` flipped to `done` today, with duration totals. `carryover` is tasks left over from today's drafted set that weren't completed, each with a `reason` string ("Ran out of time — started, 40m in") and a `suggestedTarget` label ("→ tomorrow morning"). `metrics` aggregates focus time, flow sessions, context switches, energy.
- **Source of truth:** Mostly DB query + small inference for `suggestedTarget` and `reason` strings (could be heuristic).
- **Persistence target:** Pure read. Carryover decisions persist separately via `recordCarryoverDecision`.

#### `recordReflection({forDate, text, source})` → `void`
- **Expected behavior:** Appends the user's end-of-day reflection to the Logbook journal entry for the day. Source is `typed` or `voice` (the voice path uses STT).
- **Source of truth:** Direct mutation. Tool name `record_reflection`.
- **Persistence target:** Existing Logbook entry; or a new `AgentDomainEntity.reflection` variant if scoping it to the agent feedback stream is preferred. Parent plan §D treats it as feedback for `TemplateEvolutionWorkflow`.

#### `recordCarryoverDecision({taskId, action, when?})` → `void`
- **Expected behavior:** Records what the user chose for a carryover task — `tomorrow` (default re-place suggestion), `pickDate` (with `when`), or `drop`.
- **Source of truth:** Direct mutation tool `record_carryover_decision`.
- **Persistence target:** Mutates the task: due date for re-placement, or archived flag with the `user_declined_during_shutdown` reason. Writes via `JournalRepository.updateJournalEntity`. **Tomorrow's draft must consume these decisions** — see Known gaps.

#### `generateTomorrowNote({forDate})` → `TomorrowNote`
- **Expected behavior:** Inference produces a one-paragraph for-tomorrow note ("You started the Onboarding doc and stopped 40m in. I'll start the draft with it placed in your morning…"). Maturity-aware: Day-1 / Month-3 / Year-1 copy varies per the prototype's `closing.jsx → maturityCopy`.
- **Source of truth:** Inference tool `generate_tomorrow_note`. The `maturity` projection (`template_version_count + confirmed_observation_count + days_active`) is parent plan §D.5 work.
- **Persistence target:** Persist as an `AgentDomainEntity.tomorrowNote` variant linked to the day. Tomorrow's drafting wake reads it.

### Tasks corpus (phase 7 — screen 9)

#### `surfaceTaskCorpus({stateFilter, categoryId, query})` → `List<TaskCorpusItem>`
- **Expected behavior:** Pure read. Browse the user's task corpus with state + category filters and a text search. Per parent plan §H this is "agent-free" — no inference, no agent involvement.
- **Source of truth:** `JournalDb` queries + `Fts5Db.watchFullTextMatches` for the text search. Same primitives `match_to_corpus` already uses.
- **Persistence target:** None (pure read). Wire via a new Riverpod stream provider.

### Reconcile follow-up (already-partial)

#### `matchToCorpus({phrase, categoryHint})` → `List<CorpusMatch>`
- **Status:** Agent-side service method exists (`DayAgentCaptureService.matchToCorpus`) but is **not yet exposed in the UI adapter** — the "did you mean…" overflow menu it powers isn't built. Wire when the menu lands; trivial graduation.

#### `create_task_from_phrase` (deferred per parent plan §A.2)
- **Status:** Agent-side persists a `ChangeSetEntity` proposal but no UI surfaces the resolution. Build the proposal-approval flow once Refine's `ChangeSetEntity` pattern is established (it's shared).

---

## Known gaps

### Manual UI not tested
- **Capture → Reconcile end-to-end against the real agent has never been pumped in the actual app.** The adapter compiles and unit tests pass with the mock fallback; the live path (real STT off, agent identity creation, parse-wake firing, parsed items arriving via the Riverpod stream) has not been walked through manually. **First-tap might surface edge cases:** missing template assignment for fresh day agents, profile-resolution failure if no AI provider is configured, permission prompts on the audio recorder.

### Missing templates / seeding
- The day-agent template's `generalDirective` currently constrains the model to only `record_observations` + `set_next_wake` ("In this foundation phase, only private observations and scheduled wakes are available. Do not invent unavailable tools." — see `seeded_directives.dart:319–320`). **Phase 2's tools landed but the directive was NOT updated** — so day agents on phase-2 template versions can't actually use the new capture/reconcile tools yet. **The directive bump is required for the live path to work.** See parent plan §D — bump the template head version + update existing identities' `currentVersionId` pointer.
- New phases need their tool names added to that directive whitelist and matching guidance (matching thresholds, capacity reasoning, refine etiquette, commit guard rails, shutdown maturity scaling).

### Error states surfaced in UI
- **None yet.** The adapter throws Dart exceptions on agent-side failure; the UI screens have no error handlers around them. Reconcile renders `CircularProgressIndicator` indefinitely if the parse wake fails or times out. Capture has no permission-denied feedback path.
- **Recommended:** Each `DayAgentInterface` method should have a typed error type the UI can render. At minimum, `submitCapture` and `parseCaptureToItems` need timeout + retry UX.

### Model / tool prompt changes needed
- Bump the day-agent template version with the phase-2 tool whitelist + thresholds (as noted above).
- New tools each need:
  - A `DayAgentToolNames` constant.
  - A JSON-schema entry in `day_agent_tools.dart`.
  - A `DayAgentStrategy.processToolCalls` dispatch arm.
  - A `DayAgentWorkflow.executeToolHandler` handler.
  - Tests under `test/features/daily_os_next/agents/...` mirroring the source tree.

### Persistence / model shape
- `PlannedBlock` (in `lib/classes/day_plan.dart`) does not yet carry `reason`, `type` (`ai|cal|buffer|manual`), or `state` (`drafted|committed|inProgress|completed|dropped`). Parent plan §C lists these as mandatory for phase 3. Tool-handler enforcement: an `ai`-type block must have a non-null `reason` or the handler rejects it (see parent plan §D for the rule).
- `Day` aggregate needs a `state` field (`drafted | committed`) plus `reflection` and `metrics`.
- New entity variants required: `dayPlan`, `tomorrowNote`. New link types: `captureToPlan`, `planToBlock`, `dayToReflection`.

### Tomorrow's draft must consume today's carryover
- `recordCarryoverDecision` writes the per-task choice but the draft engine doesn't read it yet. Without that loop, the user makes carryover decisions in Shutdown and the agent ignores them at next-day drafting time.
- This is a cross-phase contract: Shutdown (phase 6) writes, Drafting (phase 3) reads.

### `RealDayAgent` is untested
- The adapter's translation logic (category projection, `DayAgentPendingKind` → `PendingItemReason`, `Task` title lookup, days-overdue computation) has zero unit-test coverage. UI widget tests still inject `MockDayAgent` directly, so they don't exercise the adapter. **Add `test/features/daily_os_next/logic/real_day_agent_test.dart`** with focused unit tests on each projection + the cache.

---

## Verification already run

- **Analyzer:** `fvm flutter analyze` — zero warnings / infos / errors project-wide, run at commit `e81fd4b33`.
- **Tests:** `fvm flutter test test/features/daily_os_next/` — **164 / 164 passing** at the same commit. Includes both PR #3209's agent-layer tests and all UI tests.
- **Format:** `fvm dart format` clean on touched files.
- **Build runner:** `fvm dart run build_runner build --delete-conflicting-outputs` — succeeded; new Riverpod-codegen outputs committed (`day_agent_providers.g.dart`).
- **Not run:** Manual UI walk-through against a live agent. The branch is diverged from `origin/feat/day_agent_layer` (rebased on main) and needs `git push --force-with-lease` to publish.

---

## Recommended next phase

In order, smallest-risk-first:

1. **Bump the day-agent template directive** to include the phase-2 capture/reconcile tools + matching thresholds, and migrate existing identities' `currentVersionId` pointer. **Without this, the wired phase-2 path doesn't work end-to-end.** Smallest unit of value-restoring work.
2. **Manual end-to-end walk** of Capture → Reconcile against the live agent (with the directive bump). Expect to find: missing seed data, template-binding edge cases, prompt-tuning needs.
3. **Adapter unit tests** in `test/features/daily_os_next/logic/real_day_agent_test.dart`. ~100 lines; pure logic; covers the translation surface.
4. **Error states** — at minimum, surface `submitCapture` and `parseCaptureToItems` errors in the UI (Reconcile loading state needs a timeout + retry path).
5. **Phase 3: Drafting tools.** `draft_day_plan` + `summarize_recent_patterns`. Biggest unit of work — adds `dayPlan` entity, `reason`/`type`/`state` on `PlannedBlock`, the inference path for plan composition. Parent plan §H phase 4.
6. **Phase 4: Refine tools.** `propose_plan_diff` + `accept_diff` + `revert_diff` using the existing `ChangeSetEntity` machinery. The diff vocabulary established here is reused by Commit and Shutdown.
7. **Phase 5/6/7: Commit / Shutdown / Tasks corpus** in any order — they're independent.
8. **Phase 8: Maturity surfaces** + `TemplateEvolutionWorkflow` activation for `day_agent`. Last because it depends on accumulated feedback from earlier phases.

The parent plan (`docs/implementation_plans/2026-05-25_day_agent_layer.md` §H) has the authoritative phasing; this handover refines it with the post-phase-2 reality.
