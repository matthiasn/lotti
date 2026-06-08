# Daily OS Next

Daily OS Next is the clean-room home for the next Daily OS runtime. New agentic
planning code lives here so it can evolve without depending on the current
`features/daily_os` implementation.

The exception is the shared day-plan aggregate in `lib/classes/day_plan.dart`.
That model is already the durable representation of a day, so Daily OS Next
should extend it instead of creating a second day-plan store. New agent code can
reuse `DayPlanData`, `PlannedBlock`, `PinnedTaskRef`, and `dayPlanId`; it should
not depend on the existing Daily OS UI controllers.

## Agent Runtime

The day-agent layer under `agents/` reuses the shared agent infrastructure from
`features/agents` and adds only the Daily OS Next runtime surface area. It
supports the foundation wake, Capture/Reconcile, draft day-plan, refine, and
durable-knowledge tool paths; the Flutter UI integration is intentionally
separate.

### One long-lived planner, explicit day workspaces (ADR 0022)

The runtime has **one durable planner identity** —
`daily_os_planner` (`dailyOsPlannerAgentId`) — not one identity per calendar
day. The planner learns across days; each day is an explicit **workspace**, not
a separate mind. This is the model defined by ADR 0022 (Accepted) and replaces
the earlier per-day `day_agent` identity (the `kind` string stays `day_agent`
for storage compatibility, but only one such identity now exists).

```mermaid
flowchart TD
  Template["Shepherd template"] --> Planner["daily_os_planner identity (deterministic id)"]
  Planner --> Wake["DayAgentWorkflow (per wake, one day workspace)"]
  Day["planning_day:&lt;dayId&gt; token + day:&lt;dayId&gt; workspaceKey"] --> Wake
  Knowledge["PlannerKnowledgeEntity (durable, compaction-exempt)"] --> Wake
  Wake --> Strategy["DayAgentStrategy"]
  Strategy --> Observe["record_observations"]
  Strategy --> Schedule["set_next_wake"]
  Strategy --> KnowledgeTools["propose/confirm/retract_knowledge"]
  Strategy --> CaptureTools["capture/reconcile tools"]
  CaptureTools --> CaptureService["DayAgentCaptureService"]
  CaptureService --> Entities["agent_entities: capture (dayId) + parsedItem"]
  CaptureService --> Links["agent_links: capture_to_parsed_item + parsed_item_to_task"]
  CaptureService --> Tasks["JournalDb tasks"]
  Strategy --> PlanTools["draft + refine tools"]
  PlanTools --> PlanService["DayAgentPlanService"]
  PlanService --> DayPlan["agent_entities: day_plan (day_agent_plan:&lt;dayId&gt;)"]
  PlanService --> PlanLinks["agent_links: capture_to_plan"]
  PlanService --> RefineSets["agent_entities: changeSet + changeDecision"]
  DayPlan --> SharedModel["DayPlanData + PlannedBlock"]
  Schedule --> ScheduledWake["agent_entities: scheduledWake (workspaceKey)"]
  KnowledgeTools --> KnowledgeStore["agent_entities: plannerKnowledge"]
```

Runtime behavior:

- `DayAgentService.getOrCreatePlannerAgent()` is the single creation entry
  point. It mints the planner under the **deterministic** id
  `daily_os_planner` (via `AgentService.createAgent(agentId: ...)`), so two
  devices that independently create it converge through LWW instead of
  diverging into two identities. It is idempotent — a second call returns the
  existing planner. `getDayAgentForDate(date)` resolves the same planner
  regardless of date (it does not key on any day slot).
- The planner pins **no** `activeDayId` slot and writes **no** per-day
  `agent_day` link. A wake's day is carried explicitly by its trigger tokens
  (`planning_day:<dayId>`, plus the mode tokens `drafting:` / `refine:` and
  `capture_submitted:`) and a `day:<dayId>` workspace key on the queued
  `WakeJob`; `DayAgentWorkflow` resolves the day strictly from that context and
  fails the wake when no day can be resolved (no slot fallback).
- `dayAgentIdForDate(date)` (→ `dayplan-YYYY-MM-DD`) is now a **workspace id**,
  not an identity. The `dayplan-YYYY-MM-DD` string is still reused across
  storage namespaces without colliding: the legacy Daily OS `DayPlanEntry.id`
  (journal row), the `planning_day:` workspace token, `CaptureEntity.dayId`,
  and `DayPlanEntity.dayId`. The drafted plan is stored under
  `day_agent_plan:<dayId>` so the agent draft never overwrites the journal row,
  and the `agentId` discriminator separates the planner identity from the plan.
- **Legacy migration** runs once, inside `getOrCreatePlannerAgent`: every other
  active `day_agent` identity is archived (lifecycle → dormant, its
  `scheduledWakeAt` cleared so it is never re-woken or restored), and its recent
  (≤14-day) `dayPlan` / `capture` / `parsedItem` / `changeSet` entities are
  re-parented to the planner id via normal synced upserts so pre-flip plans
  stay visible. Each legacy agent is migrated under its own try/catch, so one
  failure neither blocks planner creation nor stops the others.
- The shared template service seeds the `Shepherd` day-agent template.
- `DayAgentWorkflow` builds the prompt from template directives, the planner's
  durable knowledge (a compact always-on **hook index** plus scoped full
  statements), recent private observations, the day's `dayLog`, and — for
  `capture_submitted:<captureId>` wakes — the submitted capture plus a bounded
  task corpus snapshot. The user-message keys are ordered **stable → volatile**
  so the cacheable prompt prefix is maximised for local KV-cache / prefix-cache
  reuse. The two knowledge tiers are split by stability: the always-on
  `knowledgeIndex` (global, slow-changing) leads the prefix *before* the large
  `dayLog`, while the scope-filtered `knowledgeStatements` vary by which scopes
  the wake touches (capture vs drafting vs refine) and therefore trail the
  `dayLog`/`attentionPlanning` — a changing statement set must never evict the
  much larger `dayLog` prefix behind it. Net order: `dayId`, `planDate`,
  `knowledgeIndex`, `dayLog`, `attentionPlanning`, `knowledgeStatements`, the
  per-wake mode block, then `triggerTokens` and `currentLocalTime` last.
  `currentLocalTime` lets same-day drafting distinguish future plan slots from
  time that has already passed.
- `DayAgentStrategy` handles private observations itself and delegates
  `set_next_wake`, `search_memory`, the knowledge tools, Capture/Reconcile
  tools, draft plan tools, and refine tools through the workflow handler.
- `search_memory` is the planner's recall + memory-linking tool, handled by the
  workflow itself (`DayAgentWorkflow._searchMemory` over `AgentLogCompactor`).
  With `query` it keyword-scans the **full** immutable capture-and-observation
  log — including detail folded out of the current summary — newest-first and
  bounded (`searchLog`); with `ids` it pulls up specific entries (`resolveByIds`,
  the "follow a link" path). Recall is lazy: the per-wake assembly resolves only
  the tail, and `search_memory` is the one reader that scans beyond it, and only
  when the agent explicitly recalls.
- **Author-time memory links (convergence-safe A-MEM, Phase 0).** Notes the
  agent writes (observations, knowledge) may cite a related entry inline as
  `[[relation:id]]` — `refines` / `supersedes` / `contradicts` / `relates`
  (`lib/features/agents/memory/memory_links.dart`). The token is plain content
  of an append-only entry, so it never mutates history, never touches the cached
  prompt prefix, and stays convergent because the cited id is the synced entity
  id. `search_memory` resolves each hit's outgoing links — validating existence
  (a hallucinated id renders as `(not found)`, never followed; a non-`supersedes`
  link to a superseded entry forward-follows to the live version, rendered
  `relation:old → live`) — and flags an entry that a newer note supersedes,
  giving the agent a navigable, append-only memory graph without an explicit
  edge store or any in-place rewrite. Validation is widened with the planner's
  durable-knowledge keys (passed as `extraKnownIds`), so a cross-tier link to a
  knowledge entry — e.g. a **Map of Content** keyed `moc-<topic>` whose statement
  curates `[[relates:id]]` links to a topic's entries — resolves rather than
  reading as dead. The system prompt fosters the Zettelkasten habits this
  enables: atomic, keyword-led notes; superseding rather than overwriting;
  distilling captures into linked permanent observations; maintaining MOCs; and
  actually following links via `search_memory(ids:)`. See
  `docs/implementation_plans/2026-06-08_convergence_safe_a_mem.md`.
- `DayAgentCaptureService` owns direct Capture/Reconcile mutations:
  `submit_capture`, `parse_capture_to_items`, `match_to_corpus`,
  `link_capture_phrase_to_task`, `break_capture_link`,
  `surface_pending_decisions`, `apply_triage`, and
  `create_task_from_phrase`.
- `submit_capture` persists a `CaptureEntity` and enqueues a manual wake with a
  `capture_submitted:<captureId>` trigger token.
- The selected local plan date lives in `dailyOsNextSelectedDateProvider`
  (`state/selected_date_provider.dart`); `DailyOsNextRoot` watches it and keeps
  the date strip visible on the Day surface, while the desktop sidebar's month
  calendar (shown beneath the active Daily OS nav row) drives the same provider.
  `DailyOsNextRoot` always renders `DayPage` for the selected date — the real
  plan when one exists, otherwise the empty Day surface. The
  Capture → Reconcile → Drafting ritual runs inside a full-height
  **day-planning modal** (`showDayPlanningModal`,
  `ui/pages/day_planning_modal.dart`), a Wolt multi-page sheet pushed on the
  root navigator (full-height bottom sheet on phones — covering the bottom nav
  — dialog on wide). The modal is opened from the empty surface's footer CTA
  (`DayPlanningCreate`) and from the Day surface's Refine CTA
  (`DayPlanningAdapt`). Each step submits against the selected date for
  day-agent routing; on create the Drafting step closes the whole modal once
  the plan is ready and invalidates `currentDraftPlanProvider` so the root
  re-renders the new plan. Background agent or sync updates reload the current
  plan stale-while-revalidate: the root keeps rendering the last Day surface
  while the provider re-fetches, and only shows the loading shell for the
  initial route load. The same Riverpod contract applies inside the modal's
  Reconcile and Drafting steps, Shutdown, and the Day captures panel: if an
  `AsyncValue` still has a previous value, the UI renders that value instead of
  replacing the section or page with a spinner.
- The root surface is identical on every no-plan day (design handoff v2,
  item 2): `DailyOsNextRoot` mounts `DayPage` in **empty mode**
  (`hasPlan: false` with a synthetic `DraftPlan.emptyForDay`) so any recorded
  sessions stay visible on the timeline without creating a plan first. Empty
  mode renders an honest "No plan yet" stat strip (neutral `CapacityDonut` over
  tracked minutes, tracked legend), swaps the Refine/Commit footer for a single
  "Speak a check-in" CTA that opens the day-planning modal, and hides the
  delete-plan menu entry. The modal's Capture step still shows the "Today so
  far" `TimeSpentCard` for the day's tracked time, fed by
  `dailyOsActualTimeBlocksProvider`.

```mermaid
stateDiagram-v2
  [*] --> Loading: route enters date
  Loading --> DayPlan: plan exists
  Loading --> DayEmpty: no plan (timeline still shows tracked time)
  DayEmpty --> Modal: "Speak a check-in" CTA (create)
  DayPlan --> Modal: Refine CTA (adapt)
  state Modal {
    [*] --> Capture
    Capture --> Reconcile: continue
    Reconcile --> Drafting: build my day
    [*] --> Refine: adapt intent
  }
  Modal --> DayPlan: Drafting ready / refine diff persists
  DayPlan --> DayEmpty: plan deleted
```

- The "Today so far" tracked-time block is one shared widget,
  `TimeSpentCard` (design handoff v2, item 1): calm eyebrow + right-aligned
  mono summary (`4h 35m · 3 done`), one row per recorded session (category
  dot, truncating title, mono clock range, green check when done), bounded to
  3 rows on desktop / 2 on mobile with a ghost "N earlier sessions" expander
  that keeps the most recent sessions visible. Capture pins it at the top of
  its column (with a date-neutral title for non-today dates); the Agenda tab
  reuses it as the empty-state body under a dashed "No plan yet" hint card.
- Agenda items and Day blocks always show the task-linked vs standalone
  distinction (design handoff v2, item 3): task-linked rows carry a blue
  `LinkBadge` with the live task name (resolved via `taskLiveDataProvider`)
  that opens the task, and task-linked Day blocks prefix an info-blue link
  icon; standalone rows carry the neutral `StandaloneTag` ("Time block").
  Standalone titles are click-to-edit through `EditableTitle` (pencil reveals
  on hover, Enter/blur saves, Esc cancels); the edit persists through
  `DayAgentInterface.renameBlock` → `DayAgentPlanService.renameBlock`, which
  rejects task-linked blocks (rename the task instead) and rewrites the
  `DayPlanEntity` block title in place. Agenda items derive from blocks, so
  the agenda title follows the renamed block on the next projection.
- Typography follows the calm system (design handoff v2, item 6) through the
  design-system helpers in
  `lib/features/design_system/theme/typography_helpers.dart`:
  `calmEyebrowStyle` (11/600/0.04em) for every overline,
  `calmPageTitleStyle` (23/600) for greetings/page titles, `calmHeroStyle`
  (34/500) for the Capture headline, `calmDisplayStyle` (26/600) for the
  Commit lead-in and LockInScene captions, and `calmGreetingStyle` (12/500)
  for quiet helper lines. No daily-os-next surface uses the legacy
  12/700/+8-tracking overline token directly.
- `DailyOsPreferencesController` persists Daily OS personalization in
  `SettingsDb`. The user's display name is edited from Settings > Advanced >
  About and read by the Capture greeting. Category exclusions are edited from
  the processing filter button; `ReconcileController` applies the same
  preference to parsed capture items and pending decisions before the user sees
  them.
- Day-plan category availability is strictly opt-in via the category editor's
  "Day planning" switch (`CategoryDefinition.isAvailableForDayPlan`). The pure
  predicates in `logic/day_plan_availability.dart` define the day-plan
  universe: `filterDayPlanCategories` (active, non-deleted, flag on) feeds the
  processing filter button's category list, layered UNDER the session-scoped
  exclusion preference above (exclusions are scoped to the day-plan
  universe: confirming the picker rebuilds the persisted exclusion set from
  the currently flagged categories, so exclusions of since-unflagged
  categories are dropped). Projects are tiered via `dayPlanProjectPriority`:
  `active` forms the scheduled pool; `open`/`monitoring`/`onHold` remain
  available at lower (opportunistic) priority so something noticed in them
  can still be planned; `completed`/`archived` are unavailable.
  `filterDayPlanProjects` orders the scheduled tier first. The helpers are not yet
  wired into the planner identity: `AgentIdentity.allowedCategoryIds` treats
  an EMPTY set as allow-all, so passing the strict (possibly empty) opt-in set
  there would invert the semantics. Wiring the agent layer needs an explicit
  "constrained" marker first; the per-wake prompt already derives its
  `touchedScopes` from attention claims and the baseline plan's categories, not
  from `allowedCategoryIds`.
- Capture supports both voice and typed intake. The idle copy exposes a real
  "type instead" action that moves the controller directly to the editable
  transcript state without opening the microphone. When Capture is opened for a
  previous selected date, the screen renders a prompt asking whether there is
  still time to track for that concrete day.
- The Capture voice path asks realtime transcription to prefer Mistral cloud
  realtime before MLX local realtime, then verifies the final editable
  transcript against the saved full recording via the batch transcriber when
  realtime output looks truncated. Refine uses the same Mistral-preferred
  realtime path but disables the full-file batch verifier for that session so a
  reviewed Mistral transcript is not replaced by an MLX fallback.
- `CaptureState` keeps two live audio signals while the mic is open:
  normalized `amplitudes` for the compact waveform bars and raw `dbfs` for the
  shader voice affordance. `VoiceButton` mounts the AI tension-loop shader only
  during `listening`, wraps it around the fixed-size record button, and removes
  the shader subtree for idle, transcribing, captured, and error phases.
- Agenda and Commit surfaces use the `CapacityDonut` ring (86 px on the Agenda
  stat strip, 62 px on the Commit recap) per the design handoff: teal under
  90% load, warning amber at 90–100%, error red above 100% with the
  over-amount drawn as a half-alpha arc past the clamped end, and a
  decimal-hours center label over an `of Nh` eyebrow. The honest no-plan strip
  passes `neutral: true` so tracked hours never read as a false "Near full".
  UI projections derive scheduled minutes from the non-dropped blocks they
  render. Buffers count because they reserve real time; dropped blocks do not.
  This keeps stale persisted totals from making the capacity reading disagree
  with the agenda rows.
- Sticky action bars on Day, Reconcile, and Shutdown use
  `DesignSystemGlassStrip`, the same hairline, blur, and footer gradient used
  by the task details action bar. The page-level buttons keep their own layout,
  but the background treatment stays shared through the design system component.
- Agenda rows resolve live task metadata through `taskLiveDataProvider` before
  rendering. `AgendaView` keeps draft/manual block timing as the source of truth,
  then passes the task title, status, estimate, category, `coverArtId`, and
  `coverArtCropX` into `AgendaCard`. The row uses `CoverArtThumbnail` for the
  square task image when one exists and falls back to the numbered category badge
  when it does not, so the compact mobile list keeps a stable leading column.
- `parse_capture_to_items` persists `ParsedItemEntity` rows and links them to
  the source capture. High-confidence matches (`>= 0.75`) auto-link to tasks,
  medium-confidence matches (`0.5..0.75`) auto-link with `lowConfidence`, and
  low-confidence items stay as new capture items. Stale or older overdue corpus
  tasks are allowed candidates, but the workflow prompt tells the model to use
  a strong match only when the capture phrase clearly refers to that task; when
  the evidence is ambiguous, it should emit a low-confidence match or NEW item
  so Reconcile can surface the choice.
- `ReconcileController` watches capture-id update notifications, so the
  "heard" column re-reads parsed items when the asynchronous parsing wake
  persists them.
- `create_task_from_phrase` creates a real task from a NEW capture phrase,
  returns its `taskId`, and links the parsed item when `captureItemId` is
  supplied. Drafting should use that returned `taskId` on the matching block so
  Agenda rows can open the backing task.
- `DayAgentPlanService` owns draft plan persistence:
  `draft_day_plan` validates model-emitted blocks, requires a non-empty reason
  for every `PlannedBlockType.ai` block, writes a `DayPlanEntity`, and links it
  back to the source capture when supplied. `DayPlanEntity.captureId` is the
  authoritative pointer from a plan to the capture that spawned it (used for
  inline lookups); the `captureToPlan` `AgentLink` exists for the reverse
  direction (graph traversal from a capture to every plan it produced) and is
  written in the same transaction. Treat the field as canonical and the link
  as derived — do not mutate one without the other.
- For today's plan, `draft_day_plan` rejects new drafted `ai` or `manual`
  blocks whose start is before `currentLocalTime`. It still accepts earlier
  blocks when their state is `inProgress`, `completed`, or `dropped`, because
  those represent what actually happened rather than new future planning.
- `dailyOsActualTimeBlocksProvider` projects recorded journal entries for the
  selected local day into `TimeBlock`s without importing the legacy Daily OS UI
  controllers. It reads `JournalDb.sortedCalendarEntries` across the
  midnight-to-midnight day, follows entry links back to tasks where available,
  resolves categories through `EntitiesCacheService`, and refreshes from every
  non-empty database update batch so newly stopped timers appear in the Actual
  lane.
- The Day timeline spans `00:00` to `00:00` and folds idle regions instead of
  cropping the day. Folding is calculated from the union of planned and actual
  blocks, so gaps on either side compress into the same folded-paper region
  with a shared zigzag edge and faint compressed-hour marks. Plan and Actual
  share one vertical `SingleChildScrollView`, one minute-density zoom value, and
  one sticky 24-hour time rail. Compact layouts keep the plan-first horizontal
  pager with an Actual peek; desktop-width layouts default to side-by-side.
  Two-finger vertical pinch and trackpad pinch zoom both lanes together, while
  the toolbar/horizontal pinch toggles paged versus side-by-side comparison.
  Blocks in the Actual lane render in the **tracked** treatment from the
  handoff (v2 item 2): neutral fill and left border, a small category dot, a
  green check when done, and a mono `HH:mm–HH:mm · tracked` subtitle — never
  the dashed drafted outline, never a WhyChip. Drafted plan blocks carry a
  dashed `DsDashedBorder` outline (a design-system primitive) so the whole frame reads provisional;
  committed blocks render solid. `DayBlock` opens `/tasks/<taskId>` for any
  planned or actual block whose `TimeBlock.taskId` is present; standalone
  calendar and buffer blocks stay inert.
- `surface_pending_decisions` intentionally limits overdue carryover to the
  last seven days. Due-today tasks and in-progress work still surface, but
  weeks-old overdue rows are left out of daily proposals unless the user brings
  them back through search, capture, or an explicit task decision.
- `PlannedBlock` now carries the agent-facing metadata required by the draft
  flow: optional task/title, block origin (`ai`, `cal`, `buffer`, `manual`),
  lifecycle state, and the model's placement reason.
- `DayAgentService.enqueueDraftingWake({dayDate, captureId?, decidedTaskIds,
  decidedCaptureItemIds})` is the UI's entry point for asking the agent to
  draft. The wake fires with `drafting:<dayId>` plus optional
  `capture_submitted:<id>`, `decided_task:<taskId>`, and
  `decided_capture_item:<parsedItemId>` tokens. The workflow surfaces the
  baseline plan, hydrated decided tasks, and `decidedCaptureItems` under the
  `drafting` block in the user message JSON. Items in `decidedCaptureItems`
  are approved NEW/unlinked capture items; the model must call
  `create_task_from_phrase` first and place the returned task id.
- Day-agent wakes that resolve to Gemini 3 Flash use a `thinkingLevel: LOW`
  override through their `CloudInferenceWrapper` instance. The shared Gemini
  Flash default remains unchanged; workflows opt into this latency profile
  explicitly instead of changing the global model default.
- Drafting wakes must finish by calling `draft_day_plan`. If the model stops
  after reconcile work or emits prose instead, `DayAgentWorkflow` sends one
  forced retry with `tool_choice` pinned to `draft_day_plan`; if that still
  misses the tool, the wake fails instead of letting the UI poll until timeout.
- Refine is the explicit plan-amendment surface. `DayAgentService.enqueueRefineWake(
  {dayDate, transcript})` pre-checks that a non-deleted plan exists, persists the
  refine transcript as a `CaptureEntity` (id prefixed `refine_capture:`,
  skipped when the transcript is blank), and fires a manual wake with
  `refine:<dayId>` (and `capture_submitted:<captureId>` when a capture was
  written). The workflow attaches a `refine` block carrying the current
  `baselinePlan` to the user message so the model can reference existing
  blockIds. This is allowed after a plan is agreed/committed because the
  amendment still lands as a pending diff that the user must accept.
- The Refine UI uses the same `CaptureController` recording/transcription path
  as the initial capture screen. It never injects a scripted transcript; when
  transcription produces no text, the screen returns to idle without proposing
  a diff. Final refine transcripts stop in the same editable review field as
  initial capture, and the controller submits its current reviewed text to
  `propose_plan_diff` so stale widget parameters cannot drop the user's edits.
  From Day, the Refine CTA opens the shared day-planning modal with a
  `DayPlanningAdapt` intent (`showDayPlanningModal`), whose Refine step hosts
  `RefineModalContent` over the existing plan surface (bottom sheet on narrow
  screens, dialog on wider screens); the full `RefinePage` remains as a
  direct-route fallback. Failed or empty proposals
  keep the review field open and show inline feedback instead of silently
  closing. Proposed changes render as independent suggestion cards, matching
  task-agent approval affordances: each row can be accepted or rejected, then
  collapses to an applied/rejected confirmation pill while unresolved rows stay
  actionable.
- `DayAgentPlanService.proposePlanDiff` persists each model-emitted change as
  a `ChangeItem` (tool name `move_block` / `add_block` / `drop_block`) on a
  new pending `ChangeSetEntity` keyed by the plan id. Optional
  `baselinePlanId` guards against stale diffs; optional `captureId` is
  stashed in the first item's args so the change set is discoverable from a
  refine-transcript capture.
- `acceptPlanDiff` / `revertPlanDiff` resolve some or all items atomically
  (default = all pending). The Refine controller passes `itemIndices` for
  per-card decisions. Accept mutates the plan in place: it overlays
  block moves, adds new blocks, drops by id, then re-sorts blocks by start
  time, recomputes `scheduledMinutes`, and rebuilds `pinnedTasks`. Energy
  bands, capacity, and plan status are left intact. Revert leaves the plan
  untouched. Both write `ChangeDecisionEntity` records per resolved item
  with `actor: user` and `verdict: confirmed | rejected`. Added blocks inherit
  `committed` state when the amended plan was already agreed/committed.
- Attention negotiation now has an indexed read/write path into planning.
  Task agents can call `request_attention`, which writes an evidence-backed
  `AttentionRequestEntity` into the synced agent log after checking existing
  active claims for the same task through `attention_claim_index`. The day
  agent loads `AgentRepository.getAttentionPlanningInputsForWindow(...)` for
  the planning day, which returns window-visible claims plus active
  `StandingAgreementEntity` records through projection indexes rather than
  source-table JSON scans. Planner awards still flow through the existing
  human-gated `ChangeSet` path: a planner may write `AttentionAwardEntity`
  records linked back to requests and concrete day plans when proposing blocks.
  Per ADR 0021, the planner behavior is LLM-mediated claim weighing; there is
  no standalone deterministic arbitrator fallback in production. The day
  agent must not wake task/project/health agents during drafting to manufacture
  fresh claims; producer agents maintain claims ahead of time during their own
  wake lifecycle, and drafting reads only the already-materialized projection.
  Task-agent wakes now resolve their own stale claims when terminal task state
  makes the request obsolete, and can use `resolve_attention_request` for
  LLM-mediated claim maintenance.
- `set_next_wake` persists each pre-warm as a day-scoped `ScheduledWakeEntity`
  record (deterministic id per `(agentId, workspaceKey)`) carrying its
  `workspaceKey` and `planning_day:<dayId>` trigger tokens — **not** the single,
  clobberable `AgentState.scheduledWakeAt`. A long-lived planner has several
  outstanding day wakes at once, and each must restore after a restart with its
  own day context. `ScheduledWakeManager` fires due records
  (`getDueScheduledWakeRecords`), enqueues them with their persisted tokens +
  workspace, then flips `status` to `consumed` in place (LWW, never
  hard-deleted) so a duplicate device delivery cannot re-fire it. The daily
  pre-warm cap is keyed by `(dayId, date)` so an active multi-day planner can
  pre-warm each day independently. The Settings → Agents → Pending Wakes
  diagnostic surfaces these records (`getPendingScheduledWakeRecords`) labelled
  by their day.
- Durable knowledge ("memorize what I tell you", ADR 0022 Decisions 9–10) is a
  separate, **compaction-exempt** store: `propose_knowledge` writes a
  `PlannerKnowledgeEntity` (`source: userStated` lands `confirmed`,
  `agentInferred` lands `proposed`); `DayAgentKnowledgeService` also exposes
  confirm / retract / edit. The active "Head" set is a pure projection over the
  entries (`activePlannerKnowledge` — most-recent confirmed per `key`,
  recency-wins, a retraction resurfaces the prior entry); there is no second
  Head entity. Knowledge is injected into every wake as a compact hook index
  plus scope-filtered full statements (global always; `category:`/`project:`
  scopes only when the wake touches them), and entries past their `reviewAfter`
  resurface for re-confirmation. Because it is a domain entity that never enters
  the compaction fold, durable knowledge survives summarization untouched.
- `summarize_recent_patterns` returns transient learning-card payloads from
  recent `DayPlanEntity` rows across **all** days under the one planner — the
  deliberate cross-day learning the single identity enables. It does not persist
  new state.
- Future Daily OS Next commit, agenda, and shutdown tools should be added
  under this feature without importing `features/daily_os`.

The planner identity's lifecycle (ADR 0022) — one durable mind, many day
workspaces, with legacy day agents archived on first flip:

```mermaid
stateDiagram-v2
  [*] --> Created: getOrCreatePlannerAgent (deterministic id)
  Created --> Migrating: archive legacy day agents + re-parent recent entities
  Migrating --> Active: planner ready
  state Active {
    [*] --> Idle
    Idle --> DayWake: planning_day:&lt;dayId&gt; wake (capture / draft / refine / pre-warm)
    DayWake --> Idle: wake completes (one day workspace touched)
    Idle --> Learning: propose/confirm/retract_knowledge
    Learning --> Idle: Head set updated (compaction-exempt)
  }
  Active --> Active: convergent re-creation on another device merges via LWW
```

```mermaid
stateDiagram-v2
  [*] --> Captured: submit_capture
  Captured --> WakeQueued: enqueueManualWake(capture_submitted)
  WakeQueued --> ParsingWake: DayAgentWorkflow.execute
  ParsingWake --> Parsed: parse_capture_to_items
  Parsed --> Linked: link_capture_phrase_to_task
  Linked --> Parsed: break_capture_link
  Parsed --> TaskCreated: create_task_from_phrase
  Parsed --> TaskMutated: apply_triage
  Parsed --> DraftedPlan: draft_day_plan
  DraftedPlan --> PatternCards: summarize_recent_patterns
  DraftedPlan --> RefineCaptured: enqueueRefineWake
  RefineCaptured --> PendingDiff: propose_plan_diff
  PendingDiff --> PendingDiff: accept_diff(itemIndices)
  PendingDiff --> PendingDiff: revert_diff(itemIndices)
  PendingDiff --> DraftedPlan: all items resolved
```

The Day view is a projection over one `DraftPlan` rather than a second planner
store:

```mermaid
flowchart LR
  DraftPlan["DraftPlan"] --> Planned["blocks: planned timeline"]
  JournalDb["JournalDb calendar entries"] --> ActualProvider["dailyOsActualTimeBlocksProvider"]
  ActualProvider --> Actual["actual TimeBlocks"]
  Planned --> DayView["DayTimeline"]
  Actual --> DayView
  DayView --> SharedScroll["single vertical scroll + shared zoom"]
  DayView --> Rail["sticky 24h time rail"]
  DayView --> Folds["folded idle regions"]
  DayView --> Paged["compact plan-first pager"]
  DayView --> Both["desktop side-by-side comparison"]
  Actual --> Tracked["tracked block treatment + TimeSpentCard"]
```

While the Daily OS tab is active, its desktop sidebar row expands into a
month calendar (`SidebarMonthCalendar` in the design system, wrapped by
`DailyOsSidebarCalendar` and mounted through the destination's
`expandedChildBuilder` — the same slot the Tasks row uses for saved
filters): today is highlighted teal, days with a persisted plan carry a
dot (`dailyOsPlanDaysProvider` — one batched `getEntitiesByIds` lookup
over the month's deterministic `day_agent_plan:<dayId>` ids), and tapping
a day selects it via `dailyOsNextSelectedDateProvider`, which the already
visible Daily OS surface reacts to directly.

## Testing Strategy

Pure day-plan and day-agent logic should use Glados property tests whenever an
invariant is easier to state than to cover with examples:

- date normalization and `dayplan-YYYY-MM-DD` identity stability
- Capture/Reconcile confidence threshold classification
- pending-decision dedupe and sort priority
- `DayPlanData` derived durations, category grouping, and JSON round-trips
- draft-plan JSON value objects, required AI block reasons, and positive block
  durations
- plan-diff change validation (moved/added/dropped action-specific required
  fields, in-day timestamp guards, unknown-blockId rejection)
- future tool validators such as non-overlap rules and commit-state gating

Service and workflow tests should stay deterministic example tests with mocks,
fixed clocks, and no real timers. They should verify transaction boundaries,
wake scheduling, persisted state changes, and tool error paths. Glados belongs
on pure model/validator/diff logic, not on mocked I/O orchestration.
