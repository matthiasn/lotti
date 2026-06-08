# Long-Lived Daily OS Planner — Execution Plan

- Status: In progress
- Date: 2026-06-07
- Decision baseline: [ADR 0022](../adr/0022-long-lived-daily-os-planner.md)
- Refines: [Long-Lived Daily OS Planner implementation plan](./2026-06-07_long_lived_daily_os_planner.md)
- Branch: `feat/long-lived-daily-os-planner`

This document is the concrete execution sequence for the PR1–PR7 plan, after
two adversarial review passes against the actual code. It corrects the parent
plan's touch lists, locks the open decisions, and records the findings that
reshape the phases. The parent plan remains the design rationale; where this
document and the parent plan disagree on mechanics, this document wins.

## Locked decisions

1. **Delivery.** One feature branch, one conventional commit per phase
   (PR1–PR7 become phases), analyzer + targeted tests green per phase, one PR
   at the end. Intermediate commits are not independently shippable; the
   parent plan's "PR4 must not ship without PR2+PR3" constraint is satisfied
   by the single merge.
2. **Scheduled wakes (parent plan Open Decision 1).** Persisted scheduled-wake
   records as a new `AgentDomainEntity` variant (no new Drift table) carrying
   agent id, workspace key, trigger tokens, and the due time. The day-scoped
   morning pre-warm survives via these records, per ADR 0022 Decision 12.
3. **Scope.** ADR 0022 only. Domain agents (ADR 0023) are a separate effort.
4. **Legacy data.** Phase 4 includes a one-time idempotent migration: archive
   all pre-existing per-day `day_agent` identities, clear their
   `scheduledWakeAt`, and re-parent their day-scoped domain entities
   (day plans, captures, parsed items, change sets) to the planner id via
   normal synced upserts — **bounded to recent history** (default trailing 14
   days, chunked if large) so a long-time user does not flood sync or block
   the UI thread. Older days are archived in place, not migrated.
5. **Knowledge panel.** A section widget on the Daily OS day surface next to
   the existing learning cards; no new route.
6. **`PlannerKnowledgeEntity` (parent plan Open Decision 5).** New
   `AgentDomainEntity` variant mirroring the `AgentTemplateVersionEntity`
   Version/Head pattern.
7. **Planner identity.** Deterministic constant id (`daily_os_planner`) so
   multi-device convergent creation merges via LWW instead of diverging.
   Today's per-day dedupe (`getActiveAgentByKindAndActiveDayId`, a query on
   `slots.activeDayId`) does not survive the refactor, and
   `AgentService.createAgent` mints random UUIDs — it gains an explicit-id
   path.
8. **Observation scope (parent plan Open Decision 2).** Observations stay
   unscoped episodic memory; scope lives only on `PlannerKnowledgeEntity`.
   See the compaction-convergence rule (A6) below.

## Adversarial findings folded into the phases

Two independent review passes (correctness/sync lens and feasibility lens)
were run against the parent plan before implementation. Findings:

| # | Finding | Fixed in |
|---|---|---|
| A1 | `captureIdFromTriggerTokens` has the same first-match-wins non-determinism as the drafting/refine extractors and drives the forced `parse_capture_to_items` retry — omitted from the parent plan's extractor fix | Phase 1 |
| A2 | Old per-day identities are never archived → zombie wakes via `getDueScheduledAgentStates` (no kind/lifecycle filter) and `restoreSubscriptions` | Phase 4 migration |
| A3 | No cross-device planner dedupe mechanism exists (`createAgent` = uuid.v4; the old dedupe was a slot query) | Phases 1/4 deterministic id |
| A4 | `enqueueManualWake` → `removeByAgent(agentId)` and `cancelPendingWake` cancel cross-day work; the superseding matrix must be explicit, not just "partition by reason class" | Phase 2 |
| A5 | `set_next_wake` daily cap is keyed by calendar date only → shared across all workspaces under one planner; persisted records need cleanup, a due-query, and restart restore | Phase 2 |
| A6 | Day-filtering captures while observations stay global makes compaction checkpoint coverage day-dependent → non-convergent folds | Phases 3/5 design rule below |
| A7 | Pre-existing day plans vanish behind `agentId` read guards after the flip | Phase 4 migration |
| A8 | Exhaustive variant switches break on new entity variants: `agent_db_conversions.dart` (4 maps + `entitySubtype`), `agent_lww_timestamp.dart`, `AgentEntityTypes`, entity-enumerating tests | Phases 2/3/5 |
| A9 | Riverpod dead keys after the flip: providers in `agents/state/day_agent_providers.dart` watch `agentUpdateStreamProvider(dayId)` with no broad fallback → lose reactivity entirely. Fix with **workspace-scoped** invalidation (per-`dayId` notifications), not a global-planner watch that rebuilds every loaded day (review finding) | Phase 4 (not 6) |
| A10 | Wake-executor router (`agent_providers.dart`), `wake_batch_router.dart` (3× `mergeTokens`, 2× `WakeJob` ctor), `wake_drain_engine.dart` (`hasQueuedJobFor` / `hasDirectQueuedJobFor`) missing from the parent touch lists | Phases 2/4 |
| A11 | Production prompt scaffold says "You operate on exactly one local calendar day"; seeded directives teach per-day + context-less pre-warm | Phases 4/5 |
| A12 | `restorePendingWake` reconstructs token-less jobs → a restored pre-warm cannot resolve a day post-flip | Phase 2 |
| A13 | The Glados reference model in `wake_queue_test.dart` has no workspace dimension — generative-harness rework, not additions | Phase 2 |
| A14 | `wake_prompt_reconstructor.dart` loads all captures by agentId (diagnostics cross-day leak) | Phase 3 |
| A15 | `pending_wake_view_model.dart` uses `activeDayId` as the wake-card subject label | Phase 4 |
| A16 | `TemplateEvolutionWorkflow` has no participating-kind list — wiring the planner in is a real integration through the improver/ritual machinery | Phase 5 |

### A6 design rule (compaction convergence) — RESOLVED to global dayLog

The compaction **fold substrate stays agent-global**: all days' captures and
observations fold into episodic memory. That is the deliberate cross-day
summarization ADR 0022 Decision 6 allows, and it keeps checkpoints append-only
and convergent.

**Resolution (user-confirmed during Phase 3).** Reading
`agent_log_compactor.dart`, the compacted `dayLog` is `summary + tail`, where
the tail interleaves **dayless observations** with day-scoped capture
transcripts. Day-filtering the tail would drop observations from episodic
memory — tail rendering and checkpoint coverage are inseparable. We therefore
keep the **entire `dayLog` (summary AND tail) agent-global**: it is the
planner's cross-day episodic memory. The active day's authoritative working
data is rendered by the already day/capture-scoped context blocks (`capture`,
`drafting`, `refine`), not by the episodic log. `CaptureEntity.dayId` exists
for **queries** (UI capture lists, parse-wake day resolution), not for
filtering the fold.

This is the **prefix-cache-optimal** choice: the `dayLog` is byte-identical
across a planner's day wakes, so the large stable prefix maximizes KV-cache /
prompt-prefix reuse. Volatile per-wake fields (working blocks, wall-clock)
stay last so the prefix is stable. Deviation from A6's literal "day-filter the
tail" is intentional and approved.

## Phase sequence

### Phase 0 — This document

Persist the execution plan in-repo and cross-link it from the parent plan.

### Phase 1 — Day workspace contract (additive; identity unchanged)

Touches: `day_agent_reconcile_models.dart`, `day_agent_slots.dart`,
`day_agent_service.dart`, `day_agent_workflow.dart`,
`lib/features/agents/service/agent_service.dart` (explicit-id creation path),
mirrored tests.

1. `planning_day:` token prefix + helpers alongside `drafting:` / `refine:`.
2. `DailyOsPlannerWakeContext` (plannerAgentId, dayId, reason, runKey,
   threadId, triggerTokens, captureId?, decidedTaskIds,
   decidedCaptureItemIds) + pure parse/validate helpers.
3. ALL token extractors workspace-filtered and deterministic:
   `draftingDayIdFromTriggerTokens`, `refineDayIdFromTriggerTokens`, **and
   `captureIdFromTriggerTokens`** (A1).
4. `getOrCreatePlannerAgent()` on `DayAgentService` with deterministic id
   `daily_os_planner` (A3); explicit-id path in `AgentService.createAgent`.
   Not wired to runtime yet.
5. Normalize the creation wake's bare `{dayId}` token to
   `planning_day:<dayId>`.
6. Workflow resolves day from wake context + tokens, with the `activeDayId`
   slot as fallback (behavior unchanged this phase).

Done when: extractors are deterministic under merged day-A + day-B token sets;
`getOrCreatePlannerAgent` is idempotent; existing per-day behavior unchanged.
No codegen.

### Phase 2 — Workspace-aware wake queue + persisted scheduled wakes (additive)

Touches: `wake_queue.dart`, `wake_orchestrator.dart`, `wake_batch_router.dart`
(A10), `wake_drain_engine.dart` (A10), `scheduled_wake_manager.dart`,
`run_key_factory.dart`, `agent_service.dart` (`cancelPendingWake`, A4),
`agent_domain_entity.dart` (+codegen), `agent_constants.dart`,
`agent_db_conversions.dart` (A8), `agent_lww_timestamp.dart` (A8),
`agent_repository.dart` + Drift due-query, `day_agent_workflow.dart`
(`set_next_wake` handler), day-agent enqueue paths; tests incl. the Glados
harness rework (A13) and entity factories.

1. `String? workspaceKey` on `WakeJob` (`day:<dayId>` for Daily OS; null
   otherwise). All `WakeJob(` construction sites carry it. **Run-key
   collision avoidance (review finding):** the queue dedupes by `runKey`, so
   two same-reason day wakes for different workspaces enqueued in the same
   tick must not hash identically. `RunKeyFactory.forManual` therefore
   includes `workspaceKey` when non-null (every Daily OS day wake is manual);
   when null the segment is omitted so existing single-workspace run keys stay
   byte-identical. Subscription run keys already disambiguate via
   `wakeCounter` + `timestamp`, and the day-scoped pre-warm rides a persisted
   `ScheduledWakeEntity` fired through `enqueueManualWake` (workspace-keyed),
   **not** the token-less `restorePendingWake` path — so the restore-collision
   scenario does not arise. `restorePendingWake` itself only ever restores the
   single per-agent `nextWakeAt`, so it cannot produce two colliding keys.
2. Partition `mergeTokens`, `removeByAgent`, `hasQueuedJobFor`,
   `hasDirectQueuedJobFor` by `(agentId, workspaceKey, reasonClass)`; null
   partitions only with null. Reason classes: capture / draft / refine /
   creation / scheduled.
3. **Explicit superseding matrix** (A4): a manual wake supersedes only queued
   jobs with the same `(agentId, workspaceKey, reasonClass)`. Same-day
   same-reason supersede preserved (prevents double draft runs); cross-day and
   cross-reason never dropped. `cancelPendingWake` gains workspace scope.
4. `ScheduledWakeEntity` variant: `{id, agentId, workspaceKey?, triggerTokens,
   reason, scheduledAt, status: pending|consumed, consumedAt?, createdAt,
   vectorClock, deletedAt?}` + `AgentEntityTypes` constant + exhaustive-switch
   cases + due-query.
5. `ScheduledWakeManager` runs both the legacy state query (project/improver
   agents) and the record query; record wakes enqueue with their persisted
   tokens + workspace key, then flip to `consumed` (LWW status flip; runKey
   dedupe + single-flight bound cross-device double-fire — tested).
6. `set_next_wake` (planner path) writes a record instead of
   `scheduledWakeAt`; the daily cap is re-keyed by `(dayId, date)` (A5); the
   planner stops writing `scheduledWakeAt`. Restart restoration reconstructs
   tokens from records, not via token-less `restorePendingWake` (A12).
7. Throttle/single-flight stay keyed by agentId (documented planner-global
   serialization); verify restored record wakes are not cross-throttled.

Done when: a day-B capture wake cannot drop or merge into a day-A draft; a
same-day draft re-request still supersedes; a due record fires with day context
after restart; consumed records do not re-fire; the cap is per-day-workspace;
task/project agents (null workspace) are regression-clean.

### Phase 3 — Day-scoped captures (additive, sync-safe)

Touches: `agent_domain_entity.dart` (+codegen),
`day_agent_capture_service.dart`, `day_capture_events.dart`,
`day_agent_context_builder.dart`, `day_agent_workflow.dart`,
`day_agent_plan_service.dart`, `state/day_agent_provider.dart`,
`agents/state/day_agent_providers.dart`, `wake_prompt_reconstructor.dart`
(A14), conversions/LWW tests (A8).

1. `CaptureEntity.dayId` as `@Default('') String` (never `required`) with a
   derive-on-read helper falling back to the capture date.
2. Stamp `dayId` on typed/voice/refine submit paths.
3. Parse wakes resolve day from `capture.dayId` when tokens lack
   `planning_day:<dayId>`; enqueue sites include both.
4. Day-filter per-wake **rendering** (A6 rule): capture events, capture lists,
   parse context, `capturesForDateProvider`. Fold substrate stays global;
   compaction convergence verified by test.
5. `wake_prompt_reconstructor` day-scopes its capture load.

Done when: an old-peer capture (no `dayId`) deserializes and resolves a day on
read; lists and rendered prompts are day-filtered under a shared agentId;
compaction checkpoints are identical regardless of wake day.

### Phase 4 — Planner identity cutover + legacy migration (the flip)

Touches: `day_agent_service.dart`, `derived_agent_state.dart`,
`agent_sync_service.dart`, `day_agent_workflow.dart` (incl. prompt scaffold,
A11), `agent_providers.dart` (wake-executor router, A10),
`state/day_agent_provider.dart` + `agents/state/day_agent_providers.dart`
(workspace-scoped invalidation, A9), `pending_wake_view_model.dart` (A15),
`real_day_agent.dart` (planner resolution), the migration step, link/state
tests.

1. Route all creation/enqueue through `getOrCreatePlannerAgent`; stop per-day
   identities, stop writing `slots.activeDayId`, stop creating per-day
   `AgentDayLink`. Enqueue paths target the planner with
   `planning_day:<dayId>` + `workspaceKey: day:<dayId>`.
2. Projection: stop deriving `activeDayId`; drop its reconcile write-back and
   derived-field-mismatch diagnostic arm.
3. Workflow derives day strictly from wake context; slot fallback removed;
   fails fast when unresolvable; rejects day-scoped tool calls where
   `args.dayId != context.dayId`.
4. **Legacy migration (A2/A7):** one-time idempotent step at planner creation:
   archive all other active `day_agent` identities, clear their
   `scheduledWakeAt`, re-parent their day plans / captures / parsed items /
   change sets to the planner id via synced upserts. `restoreSubscriptions`
   skips archived agents. **Bound the volume (review finding):** re-parent only
   recent history (default: trailing 14 days of day plans + their captures /
   parsed items / change sets) so a long-time user does not flood the sync
   channel or block the DB/UI thread; older days are archived in place
   (identity flipped, entities left parented to the old id — invisible but not
   migrated). If even the bounded set is large, chunk the upserts across
   transactions rather than one bulk write. Migration runs once, guarded by a
   persisted marker so it is not re-attempted on every launch.
5. Prompt scaffold rewritten to planner semantics (A11); wake-card subject
   derived from the `planning_day:` token (A15).
6. **Workspace-scoped provider invalidation (A9 + review finding).** The dead
   `agentUpdateStreamProvider(dayId)` keys must not be naively re-pointed at
   the global planner id: that rebuilds every loaded day's providers on any
   planner wake. Instead emit a workspace-scoped notification — the planner's
   persisted-state-changed callback already fires per `dayId` (see
   `onPersistedStateChanged?..call(agentId)..call(dayId)` in the workflow), so
   day providers can keep watching a `dayId`-keyed stream fed by those
   per-day notifications, with the planner id as a coarse fallback only where a
   day key is unavailable. Verify only the affected day's providers rebuild.
7. Persisted strings unchanged: `kind == day_agent`,
   `day_agent_plan:<dayId>`.

Done when: two dates yield one planner (idempotent under simulated concurrent
creation); reconcile never writes `activeDayId`; interleaved day-A / day-B
wakes neither cancel nor cross-contaminate (end-to-end); pre-flip plans are
visible post-flip; archived agents are not woken or restored; providers
rebuild on planner notifications for the right day.

### Phase 5 — Durable knowledge + two-loop memory

**Status (user-confirmed):** the **fast loop** is implemented and reviewed
(durable `PlannerKnowledgeEntity`, code-side Head selection, `propose_knowledge`
+ confirm/retract/edit service, two-tier prefix-cache-optimal prompt injection,
the "What I've learned" panel + l10n). Two deviations/deferrals are approved:

- **No `PlannerKnowledgeHeadEntity`.** Head selection is a pure projection over
  the entry set (`activePlannerKnowledge`) — convergent without a second
  variant; `supersedesId` is provenance-only.
- **The weekly one-on-one ritual (slow loop, A16) is DEFERRED to a follow-up.**
  Wiring the planner into `TemplateEvolutionWorkflow` (gather planner
  observations + fold confirmed knowledge into a new user-approved template
  version + seed/trigger an improver for the day-agent template) is a genuine
  subsystem integration, not a small change — the escalation point this plan
  reserved. The fast loop already delivers ADR 0022's core "memorize what I
  tell you" promise; the slow-loop consolidation lands separately.
  `seeded_directive_content.dart` (A11) and the localized planner display name
  (CodeRabbit) ride that follow-up.

Original Phase 5 touch list (for reference):
`agent_domain_entity.dart` (+codegen: `PlannerKnowledgeEntity`),
conversions/LWW/constants (A8), new
`day_agent_knowledge_service.dart`, `day_agent_tool_names.dart` + tool defs,
`day_agent_workflow.dart` (hook-index injection + scoped retrieval + memory
split), `template_evolution_workflow.dart` + ritual/improver wiring (A16,
deferred), `seeded_directive_content.dart` (A11, deferred), UI
`ui/widgets/knowledge_panel.dart` +
provider + day-surface integration, l10n in all primary arb files (informal
tone), mirrored tests.

1. Entity fields per parent plan: `key, hook, value, statementText,
   source(userStated|agentInferred), status(proposed|confirmed|retracted),
   supersedesId?, scope(global|category:<id>|project:<id>), createdAt,
   confirmedAt?, retractedAt?, reviewAfter?`. Head selects the active entry
   per key (non-retracted, recency-wins).
2. `propose_knowledge` / `confirm_knowledge` / `retract_knowledge` handlers;
   `source = userStated` may go straight to confirmed; user gate via panel.
3. Prompt: always-on compact hook index; full `statementText` pulled on
   demand, scoped (global always; category/project when the wake touches
   them); past-`reviewAfter` entries surface for re-confirmation. Knowledge
   never enters the fold.
4. Memory split per A6 rule; `summarize_recent_patterns` cross-day (test).
5. Weekly loop: planner participates in the template-evolution ritual via a
   scheduled weekly wake (Phase 2 records); confirmed knowledge feeds the
   evolution context → next user-approved template version. If ritual
   data-shape assumptions make this a subsystem rewrite, land the knowledge
   store and escalate the ritual wiring explicitly (A16).
6. Seeded directives updated off per-day / context-less pre-warm language
   (A11).
7. Knowledge panel: confirmed entries (hook + expandable statement),
   confirm/retract/edit, stale re-confirm affordance.

Done when: a user instruction persists as confirmed knowledge, survives a
compaction fold, and shapes the next wake's prompt; contradiction supersedes
by recency; retraction removes from the Head set; stale entries re-surface;
the panel is localized and tested.

### Phase 6 — Plan/refine/commit + UI adapter cleanup

Touches: `real_day_agent.dart` (all date→agent call sites),
`day_agent_plan_service.dart`, drafting/refine/shutdown controllers,
`ui/widgets/captures_panel.dart`, UI tests.

Replace date→agent lookups with planner + explicit day workspace;
`pendingPlanDiffsForDay` scoped by planner + plan target; final provider
invalidation pass. Done when capture → parse → reconcile → draft → refine →
commit works for one day AND interleaved across two days without leaks.

**Status:** most of this phase was absorbed by Phases 3–4 and verified, not
re-implemented:

- `real_day_agent.dart` already routes every call site through
  `getDayAgentForDate` (→ the planner) with an explicit
  `dayId: dayAgentIdForDate(date)` workspace (Phase 4 cutover).
- `pendingPlanDiffsForDay` is already scoped by **both** planner `agentId`
  **and** plan target (`cs.taskId == dayAgentPlanEntityId(dayId)`); the
  cross-day case is covered by `filters out change sets for a different plan
  (taskId mismatch)`.
- `captures_panel.dart` already consumes the day-scoped
  `capturesForDateProvider(date)` (Phase 3); controller invalidation was
  re-keyed to the planner id in Phase 4 (A9).

What this phase added: **A15** — the planner's day pre-warms are
`ScheduledWakeEntity` records (not `AgentState.scheduledWakeAt`) and it pins no
`activeDayId` slot, so the Settings → Agents → Pending Wakes diagnostic both
read a dead slot and stopped showing those wakes. Fixed by surfacing pending
scheduled-wake records (new `getPendingScheduledWakeRecords` query) labelled by
their workspace id, carried on `PendingWakeRecord.subjectLabel`; the view-model
prefers that label over the linked-entry title.

**Deferred to Phase 8:** the single consolidated interleaved-day end-to-end
test. The interleaved isolation property is already covered piecewise across
all four layers (one-identity service, no-merge wake queue, cross-day tool
rejection, cross-day diff filter); a real-services integration harness does not
yet exist in the Daily OS Next tests (the adapter test mocks its services), so
the consolidated end-to-end test lands with the Phase 8 hardening sweep where
that harness belongs — same branch, same PR.

### Phase 7 — Docs, renames, old-model removal

1. Rename non-persisted symbols/files off `day_agent_*` toward planner-shaped
   names (e.g. `dayAgentIdForDate` → `dayWorkspaceIdForDate`,
   `DayAgentService` → `DailyOsPlannerService`), mirroring test paths. Keep
   persisted strings: kind `day_agent`, `day_agent_plan:<dayId>`, entity type
   strings, wire token prefixes, the `agent_day` link type.
2. Remove compatibility wrappers and unused lookups.
3. READMEs (architecture-first, Mermaid incl. planner lifecycle):
   `lib/features/daily_os_next/README.md`, `lib/features/agents/README.md`,
   `lib/features/agents/projection/README.md`, `test/README.md` as needed.
4. Mark the 2026-05-25 day-agent plan superseded; update the orientation doc;
   flip plan statuses.
5. CHANGELOG under the current pubspec version (user-visible: cross-day
   planner memory; "What I've learned" panel) + flatpak metainfo.

### Phase 8 — Final hardening

Full `make analyze`; full Daily OS Next + agents test suites; the end-to-end
verification list below; a final multi-agent adversarial sweep over the whole
branch diff (correctness, sync/convergence, test-quality lenses) repeated
until a pass yields no confirmed findings.

**Status — adversarial sweep run (two rounds).**

Round 1 deployed four parallel adversarial reviewers — correctness/cross-day,
sync/convergence, test-quality, and a **dedicated cacheability reviewer** (per
the explicit user requirement). The cacheability reviewer returned a *verified
clean bill*: deterministic insertion-order JSON, sorted knowledge/trigger
tokens, snapshot (not `now`-relative) timestamps, a template-version-stable
system prompt, and a confirmed stable→volatile key order with `triggerTokens`
+ `currentLocalTime` last — nothing volatile caps the cacheable prefix. The
other three produced one MAJOR + several MINOR/NIT findings, all fixed:

- **MAJOR** — rapid same-day captures could lose a parse (a second capture's
  manual wake superseded the first's still-queued parse). Fixed:
  `enqueueManualWake` gained `supersede` (default true); capture wakes pass
  `supersede: false` so each submission's parse accumulates. Realizes the A4
  "cross-reason never dropped" intent for the accumulating capture case.
- **MINOR (sync)** — `set_next_wake` stored an LLM-parsed `scheduledAt` that
  could carry a `Z`/offset, breaking the due-query's lexicographic compare
  against a naive-local `now`. Fixed: normalize to local at parse.
- **MINOR (correctness)** — a stray legacy active `day_agent` is no longer
  restored; `restoreSubscriptions` hydrates only the deterministic planner id.
- Test-quality: golden rows added to the pending-wake VM test (was mirroring
  the impl), an explicit-null run-key case, a negative stale-badge case.

Round 2 deployed a fix-verifier (which *empirically* confirmed both behavioral
fixes are correct and their tests fail on revert — genuinely discriminating)
and a completeness critic. No new actionable correctness bugs. Residual items
are pre-existing and out of ADR 0022 scope, or known-deferred:

- Ollama silently ignores forced `tool_choice` (pre-existing AI-layer
  limitation; the plan's provider-neutral list is Gemini/Mistral/OpenAI-
  compatible, and the planner resolves to cloud models). Not addressed here.
- The migration intentionally does not re-parent legacy observations/audit
  records (now documented in the migration docstring; forward-looking memory
  per Decision 6, nothing user-visible lost).
- The seeded `dayAgentGeneralDirective` was re-read and found *accurate*, not
  contradictory ("shape one calendar day at a time" is the real per-wake
  behavior; pre-warms carry day context; "improve future days" is correct
  cross-day framing) — the A11 *enhancement* (durable-knowledge framing) stays
  deferred, but there is no live correctness bug.

**Deferred to a follow-up PR (consciously, see Phase 5/6/7 notes):** the weekly
ritual (A16) + seeded-directive enhancement (A11) + localized planner display
name; the cosmetic `day_agent_*` symbol/file renames; the `activeDayId` /
`agent_day` old-model removal; and a single consolidated interleaved-day
end-to-end integration test (the interleaved isolation property is already
verified piecewise across the service, wake-queue, workflow, and plan-service
suites — the round-1 test-quality reviewer confirmed cross-day isolation is
"genuinely proven, not just single-day happy path").

## Per-phase execution protocol

1. Implement; `make build_runner` when entities change (generated files are
   never edited by hand).
2. `fvm dart format .`; full `fvm flutter analyze` → zero warnings/infos.
3. Targeted tests for touched files green.
4. Adversarial review pass: parallel reviewers over the phase diff
   (correctness/cross-day-leak, sync/convergence, test-quality lenses);
   findings verified adversarially before fixing; repeated until clean.
5. Conventional commit per phase.

## End-to-end verification

- `getOrCreatePlannerAgent` idempotent, incl. simulated cross-device creation.
- Interleaved: capture day A → parse → draft; capture day B; no token/queue/
  context cross-contamination; refine + commit day A.
- User instruction → confirmed knowledge → survives compaction → shapes the
  next wake's prompt.
- Old data: pre-flip plans visible, no zombie wakes.
- Provider-neutral forced tool-choice tests (Gemini, Mistral,
  OpenAI-compatible) still pass.
- `make analyze` clean; all relevant suites green.

## Escalation points

- A6: compaction tail rendering cannot be day-filtered without breaking
  checkpoint coverage determinism.
- A16: the weekly ritual's data-shape assumptions make planner participation a
  subsystem rewrite.
- Any need for a new design-system token or visual value.
