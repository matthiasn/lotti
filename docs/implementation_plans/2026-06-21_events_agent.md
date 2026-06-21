# Event Agent — Implementation Plan

> **Status:** revised after an expert-panel review (agent-systems, codebase-fit,
> product/UX, pre-mortem). The review changed the scope and sequencing
> materially — see **Design review** at the bottom for what changed and why.

## Context

Events are now a first-class entity (behind `enableEventsFlag`), but they have
**no agentic integration**. The "AI summary" on the event detail page is a
*passive render* of whatever linked `AiResponseEntry` happens to exist — nothing
generates it, and `onRegenerateSummary` (`event_detail_view.dart:698-746`) is a
dangling callback wired to nothing (`event_view_mapping.dart:140-146`).

The goal is an AI helper that keeps an **up-to-date report** on an event and can
**propose actions**. The generic agent platform already runs **Task and Project**
agents, so the agent itself is an *additive third entity type*, not new
infrastructure.

## Product model: a recap, not a daemon

The original idea — "run quite similar to a task agent" — borrows the wrong
mental model. A **task churns**; a perpetual watcher + living report fits it. An
**event mostly happens once**; a daemon that re-summarises a static memory on
every caption edit just spends inference for a document nobody re-reads, and an
AI that silently authors your *rating* of your own memory or swaps your *cover*
is presumptuous in a personal journal.

So the event agent is shaped as a **recap with explicit, consensual actions**:

- **Wake rarely, not continuously.** Adopt the *project* agent's low-frequency /
  scheduled cadence + dormant-skip (`project_agent_execute.dart:64-73`), **not**
  the task agent's churn model (`deferPropagatedMatches=false` + 120s throttle).
  Fire when the event settles (reaches `completed` or its end date passes), then
  go dormant behind a manual **"Update recap"** affordance (reuse the dangling
  `onRegenerateSummary`). Before any LLM call, gate on a content-digest delta so a
  wake with nothing new is a cheap no-op.
- **v1 ships narration only.** The living/recap report is the de-riskable core and
  the thing users judge. The three write-actions are deferred (see scope).

## v1 scope vs. later

**v1 — narrate (read-only recap).** The agent reads the event's linked
photos/notes/audio + tasks and writes a recap report shown on the detail page.
No proposals, no mutations → no self-wake loop, no new cover setter, no
proposal-row work.

**Later PRs (one action per PR), opt-in and auditable:**

- **Suggest follow-up tasks** — genuinely event-shaped forward action; reuses the
  existing follow-up handler. Highest-value action.
- **Suggest status** — only as a *suggestion* tied to objective time signals
  ("end date passed — mark completed/missed?"); never auto-flip.

**Rating and cover are human-only — the agent never touches them.**
`EventData.stars` is the human's verdict on their own memory and `coverArtId` is
a personal aesthetic choice; both are **excluded from the agent entirely** (not
deferred). This removes the `set_event_rating` / `set_event_cover` tools, the
missing event cover-setter, and the rating-authoring concern from the whole plan.

Each write-action, when added, must (a) break the **accept → re-wake loop** by
scoping the agent's subscription to *user-authored* content only (not agent-
proposed mutations) or threading suppression through the change-set accept path,
and (b) be inspectable/revertible after it applies, not just as a pending
proposal.

## How it runs (the platform seams — verified)

The platform is entity-agnostic up to one dispatch point:

`UpdateNotifications` → `WakeOrchestrator._onBatch` (`wake_batch_router.dart`,
match tokens + suppression + **content gate**) → `WakeJob` → `_drain`
(`wake_drain_engine.dart`) → per-agent lock → the single `wakeExecutor` callback,
assigned in **`agent_wiring.dart:20` (`wireWakeExecutor`)** — the one place that
routes by the runtime `identity.kind` string. Adding an `eventAgent` arm there is
genuinely low-risk (if/early-return with per-job exception isolation at
`wake_drain_engine.dart:377`; a correctly-guarded branch can't intercept other
kinds).

Each branch runs a hand-rolled `*AgentWorkflow.execute(...)` (reconcile state →
read slot id → resolve template/profile → **build context** → run inference,
looping tool calls via the strategy → persist report/state). The event agent is a
new `eventAgent` kind with its own service, strategy, context builder, and
workflow — copied from the **project** agent (leaner than task: no
checklist/time/attention/embedding machinery).

> **Two "kind" concepts** both need an `eventAgent` arm: the runtime `AgentKinds`
> string (`agent_constants.dart:5`, drives `wireWakeExecutor`) and the
> `AgentTemplateKind` enum (`agent_enums.dart:46`, drives templates/seeding).

## Key decisions (corrected)

1. **New `EventAgentWorkflow`/strategy, not a generic engine** — every kind is
   hand-rolled; genericising would refactor 4 working agents. Copy `Project*`.
2. **The report handlers are *copied*, not reused.** `update_report` /
   `record_observations` are part-file extension methods bound to
   `TaskAgentStrategy`'s private fields (`task_agent_tool_handlers.dart:14/90`);
   the project agent *re-implemented* them (`project_agent_strategy.dart:179/258`).
   Budget a third copy.
3. **`AgentSlots.activeEventId` is migration-free JSON, but sync-unsafe as a raw
   field.** Agent state syncs via whole-row LWW; freezed/json drops unknown keys
   on round-trip, so a mixed-version mesh (and `enableEventsFlag` itself syncs)
   can clobber `activeEventId`. **Model the active event as an outbound
   `AgentLink.agentEvent`** (the reconcile path already derives slots from links)
   rather than relying on the JSON field surviving older clients.
4. **Category opt-in is a migration-free JSON field**, not a DB migration.
   `CategoryDefinition` is serialized JSON (`entity_definitions.dart:133-164`,
   like `isAvailableForDayPlan`); add nullable `defaultEventTemplateId`. The real
   concern is absent-key back-compat (⇒ null ⇒ no agent), not SQL.
5. **The content gate is a shared-singleton change — isolate it.** Generalise
   `_shouldSkipForAwaitingContent` (`wake_batch_router.dart:268`, hard-reads
   `activeTaskId`) via an explicit **`Map<AgentKind, ContentChecker>`** — *never*
   a slot-fallback like `activeTaskId ?? activeEventId`, which would route an
   event id into the task checker and **silently starve** project/task wakes.
6. **The UI needs a new event-keyed suggestion provider.**
   `unifiedSuggestionListProvider` is task-keyed and internally resolves
   `taskAgentProvider(taskId)` (`unified_suggestion_providers.dart:72-85`). v1
   (narrate-only) only needs the report; later action PRs add
   `eventSuggestionListProvider(eventId)`. Compose the *dumb* card parts
   (`TldrHeader`, report body) directly — the `ProjectAgentReportCard` precedent
   reuses none of `ai_summary_card/`'s parts, so "lean reuse" applies only to the
   plain `StatelessWidget`s.
7. **Silent string-switch sites must be hand-found** — `analyze` only catches the
   exhaustive *enum* switches, not `AgentKinds`-string switches that fall through
   `_ =>`: `instance_view_model.dart:48` (agent invisible in Settings →
   Instances), `pending_wake_view_model.dart:114` (raw `"event_agent"` label),
   `proposal_kind_part.dart` (event proposals render with a generic chip).

## The directives are the product (named deliverable)

The agent's whole value lives in prose that **does not exist yet** — the seeded
corpus (`seeded_directive_content.dart`) has task/project/day/improver arms and
zero event content. Authoring these is the highest-value, least-specified work:

- `eventAgentGeneralDirective` — persona + when to narrate vs. stay silent.
- `eventAgentReportDirective` — the **event-shaped** report contract (a
  recap/story: what happened, highlights, who/what, open follow-ups), **not** the
  project agent's `Progress / Risks / Next Steps` health-band shape, which is
  nonsensical for a memory. Define arg/provenance keys analogous to
  `project_agent_report_contract.dart`.
- The four tools' descriptions (only `narrate` for v1).
- "Event has content" = a linked photo/note (a bare title must not trigger
  inference). Tune compaction budgets down from project defaults (events have far
  less log churn).

Treat these as reviewed deliverables with example outputs, not a stub.

## Resequenced delivery (multiple PRs, not one)

For calibration, the project agent — which we're mirroring — shipped across
**8+ PRs** (#2809, #2821, #2858, a revert/re-land, plus follow-ups). Expect the
same; sequence to de-risk the shared platform first.

- **PR1 — Content-gate generalisation (shared platform, isolated & revertable).**
  Per-kind `ContentChecker` map + `activeEventId`-aware read; add a new
  `test/features/agents/wake/wake_batch_router_test.dart` (`fakeAsync`) proving
  task still gates, project is never gated, event gates on event content, and the
  mirror drop/preserve invariants hold on exception. Land green *before* any
  event-agent code depends on it.
- **PR2 — Domain + sealed-union plumbing** *(build_runner: freezed)*. `AgentKinds`
  + `AgentTemplateKind` `eventAgent`; `AgentLink.agentEvent` + `AgentLinkTypes`;
  `activeEventId` (+ decide link-vs-field for sync per decision 3); db conversions;
  `eventEntityUpdateNotification` **and its emit on event edits** + subscription;
  the silent string-switch sites (decision 7). Verify: analyze + the grep
  checklist + `agent_db_conversions_test`.
- **PR3 — Directives + report contract** (the actual product; reviewed prose).
- **PR4 — Strategy + context builder + workflow + `narrate` tool + wiring +
  auto-attach** *(build_runner: providers)*. `EventAgentService.createEventAgent`
  (copy `ProjectAgentService`, project cadence, `awaitContent`) +
  `_registerEventSubscription`; the `wireWakeExecutor` branch;
  `autoAssignCategoryEventAgent(With)` hooked into `createEvent`
  (`create_entry.dart:170`, already returns the event). Behind `enableEventsFlag`.
- **PR5 — UI card (narrate-only)** — `EventAiSummaryCard` showing the report,
  replacing the passive `_SummaryCard`; the "Update recap" button reuses
  `onRegenerateSummary`.
- **PR6+ — write-actions, one per PR** — follow-up tasks first, then status as a
  time-tied suggestion. (Rating and cover are human-only — excluded.) Each adds
  its tool + `eventSuggestionListProvider` + change-set rendering + the
  accept→re-wake-loop break.

## Cross-cutting: observability, tests, docs

- **Observability** — the agent platform emits **zero telemetry today**. Add a
  minimal "agent woke / report produced / proposal accepted" counter or log so we
  can tell post-launch whether it fires/succeeds/is used.
- **Tests** — beyond the per-phase mirrors of the project-agent suite
  (`project_agent_workflow_test`, `project_tool_dispatcher_test`,
  `project_agent_service_test`, `agent_template_seeding_test`,
  `agent_db_conversions_test`, `project_agent_report_card_test`), the content-gate
  test in PR1 is mandatory (none exists today). Add `eventAgent` arms to
  `template_view_model_test`, `agent_template_service_test`,
  `test/helpers/fallbacks.dart`, the template factories.
- **Docs** — update `lib/features/agents/README.md` (its content-gate section is
  task-worded), `lib/features/events/README.md`, CHANGELOG, and the flatpak
  metainfo (repo rule). l10n: `agentTemplateKindEventAgent` + the event template
  display name (6 locales).

## Risks

- **Biggest: the content-gate generalisation silently starves working Task/Project
  wakes.** It's a singleton field on the shared drain path with no kind-awareness
  and a *silent* failure mode (skipped wakes, no error). Mitigate: per-kind
  checker map (never slot-fallback), the dedicated `fakeAsync` test, and ship it
  as its own revertable PR1 before anything depends on it. (The `wireWakeExecutor`
  change, by contrast, is genuinely low-risk.)
- **Self-wake loop** on write-actions (accept mutation → event change → re-wake).
  Avoided in v1 (narrate-only); each action PR must break it explicitly.
- **Sync of `activeEventId`** across mixed-version meshes — addressed by modelling
  it as an `AgentLink` (decision 3).
- **Cost** — controlled by the recap (fire-once-then-dormant) model + the
  content-digest skip, **not** by `awaitContent`/throttle alone (those only
  delay the first/next wake, not steady-state re-summarisation).

## Design review (expert panel) — what changed

A four-lens panel (agent-systems, codebase-fit, product/UX, pre-mortem) reviewed
the first draft. Net changes folded in above:

- **Product/UX** → reshaped from "living-report daemon + 4 auto-actions" to
  "**recap, narrate-only v1**"; cut/demoted `set_rating` (never author the human's
  verdict) and `set_cover`; added consent/audit requirements.
- **Agent-systems** → adopt **project cadence, not task churn**; add the
  content-digest skip; flagged the **accept→re-wake loop**; corrected
  "reuse handlers" to **"copy"**; corrected the cost-mitigation claim.
- **Codebase-fit** → **Category is JSON, not a migration**; the suggestion
  provider is **task-keyed** (need a new event-keyed one); enumerated the
  **silent string-switch** sites `analyze` won't catch.
- **Pre-mortem** → **directives are the unspecified product**; the content gate is
  a **shared-singleton risk** (own PR + test); **`activeEventId` is sync-unsafe**;
  no observability / no `wake_batch_router_test` / docs unscoped; **this is many
  PRs, not one** (the project agent took 8+). *(The flagged "`set_event_cover` has
  no write path" is moot — cover is human-only.)*
