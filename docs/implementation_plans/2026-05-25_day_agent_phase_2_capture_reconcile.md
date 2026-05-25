# Day Agent — Phase 2 Build Plan (Capture + Reconcile)

**Date:** 2026-05-25
**Status:** Commitments locked; ready to build
**Parent:** [`2026-05-25_day_agent_layer.md`](./2026-05-25_day_agent_layer.md) (the §H phase 2 entry).
**Scope:** Implement the eight Capture + Reconcile tools the parent plan §E lists, persist their backing data, wire them into the existing `DayAgentStrategy` / `DayAgentWorkflow`, and graduate `lib/features/daily_os_next/ui/...` from `MockDayAgent` to a real adapter for these methods only.

The parent plan covers **what** to build at the tool-name level. This plan covers the **how** — the seven implementation decisions the parent doesn't lock.

## Goal

After phase 2, the user can open the new Daily OS surface, tap-to-talk on Capture, navigate to Reconcile, see real LLM-parsed items matched against their actual task corpus, and apply real triage actions that write back to the task DB. All other screens (Drafting, Day, Refine, Commit, Shutdown, Tasks) keep using `MockDayAgent` until their phases ship.

## Non-goals

- Drafting / Day / Refine / Commit / Shutdown / Tasks tools — later phases.
- Real STT — `submit_capture` still takes a pre-transcribed string; the speech pipeline gets wired separately.
- Calendar integration — still deferred per parent §B.
- New Drift tables — everything rides on `agent_entities` / `agent_links` per parent §A.

## A. Decisions (locked)

| # | Question | Decision |
|---|----------|----------|
| 1 | Persistence shape for new entities | Two new variants on the `AgentDomainEntity` sealed union: `AgentDomainEntity.capture(...)` (type tag `day_capture`) and `AgentDomainEntity.parsedItem(...)` (type tag `parsed_capture_item`). Linked via `agent_links` with type `capture_to_parsed_item` and `parsed_item_to_task`. |
| 2 | Inference vs. direct-mutation tools | `parse_capture_to_items` runs inside the wake (LLM inference). `submit_capture`, `match_to_corpus`, `link_capture_phrase_to_task`, `break_capture_link`, `surface_pending_decisions`, `apply_triage` are direct mutations dispatched through `DayAgentStrategy.executeToolHandler` without inference. `create_task_from_phrase` is deferred (writes a `ChangeSetEntity` proposal). |
| 3 | Task-corpus snapshot for the LLM | Built once in `DayAgentWorkflow._buildUserMessage` and embedded in the user message — not exposed as a tool. The agent gets a serialised view of {open, in-progress, overdue, due-today, recurring} tasks scoped to the user's allowed categories, capped at ~200 tasks. The plan's `match_to_corpus` tool stays available for UI-triggered "did you mean…" follow-ups. |
| 4 | `surface_pending_decisions` query path | Reuse existing `JournalDb.getTasksDueOn` + `getTasksDueOnOrBefore`. Add **two** new queries in `journal_db_queries`: `getInProgressTasks(categoryIds?)` and `getMissedRecurringTasks(asOf, lookbackDays = 7)`. The tool stitches the four lists, dedups by taskId, sorts overdue first. |
| 5 | Match algorithm | LLM-only inside `parse_capture_to_items` — the inference receives the corpus snapshot and emits each `ParsedItem` with an optional `matchedTaskId` + confidence value. **No separate FTS5 stage.** Auto-link threshold: `confidence ≥ 0.75` lands as MATCHED with info-blue tint; `0.5–0.75` lands as MATCHED with warning tint and the `low_confidence` flag set; `< 0.5` is treated as NEW. `match_to_corpus` (the standalone tool) uses FTS5 for the cheaper "alternatives" dropdown. |
| 6 | UI async bridge | New Riverpod stream provider per `CaptureId`: `parsedItemsForCaptureProvider(captureId)` watches `agentUpdateStreamProvider` and emits the latest list whenever a `parsed_capture_item` linked to the capture is written. The adapter's `parseCaptureToItems(captureId)` returns the **first non-empty snapshot** (i.e. the wake completed). UI screens stay on `Future`-shaped methods. |
| 7 | Adapter graduation | New file `lib/features/daily_os_next/logic/real_day_agent.dart` implementing `DayAgentInterface`. Method-by-method: graduates `submitCapture`, `parseCaptureToItems`, `surfacePendingDecisions`, `applyTriage`, `breakCaptureLink`, `linkCapturePhraseToTask` to the real agent. Every other method `super.noSuchMethod`-delegates to a held `MockDayAgent` instance until its phase ships. `dayAgentProvider` returns `RealDayAgent(mockFallback: MockDayAgent())`. |

## B. New entity variants

```dart
// agent_domain_entity.dart — additive freezed factories.

const factory AgentDomainEntity.capture({
  required String id,            // 'capture_<uuid>'
  required String agentId,       // dayplan-YYYY-MM-DD
  required String transcript,
  required DateTime capturedAt,
  required VectorClock? vectorClock,
  String? audioRef,              // JournalAudio id once STT lands
  DateTime? deletedAt,
}) = CaptureEntity;

const factory AgentDomainEntity.parsedItem({
  required String id,            // 'parsed_<uuid>'
  required String agentId,
  required String captureId,
  required ParsedItemKind kind,  // newTask | matched | update
  required String title,
  required String categoryId,
  required ParsedItemConfidence confidence,
  required DateTime createdAt,
  required VectorClock? vectorClock,
  String? spokenPhrase,
  String? matchedTaskId,
  int? estimateMinutes,
  String? timeAnchor,
  String? proposedUpdate,
  DateTime? deletedAt,
}) = ParsedItemEntity;
```

These graduate the matching UI-side enums (`ParsedItemKind`, `ParsedItemConfidence`) from `daily_os_next/logic/day_agent_models.dart` to `features/agents/model/agent_enums.dart` so the agent layer and the UI share one definition.

`agent_links` gets two new type tags: `capture_to_parsed_item` (one capture → many items) and `parsed_item_to_task` (one item → 0..1 task, mutable via `link_capture_phrase_to_task` / `break_capture_link`).

## C. Tool implementations

Order them by complexity / risk, smallest first. Each lands as a follow-up commit after the previous is green:

1. **`submit_capture`** — direct mutation. Writes a `CaptureEntity`, enqueues a wake with trigger token `capture_submitted:<captureId>`. Returns `{captureId}`. No inference.
2. **`surface_pending_decisions`** — direct read. Wires the new `JournalDb` queries from decision 4. Returns `PendingItem[]` projected from `Task` rows. No agent involvement.
3. **`apply_triage`** — direct mutation. Writes back to `tasks` table (status / scheduled-for date / archived flag). Uses optimistic update path per parent §M.
4. **`break_capture_link`** + **`link_capture_phrase_to_task`** — direct mutations on the new `agent_links` rows.
5. **`match_to_corpus`** — FTS5 over `Fts5Db.watchFullTextMatches` scoped to the user's allowed categories. Used by the UI's "did you mean…" overflow menu, not the initial parse.
6. **`parse_capture_to_items`** — the inference tool. Wake triggered by `capture_submitted`. Workflow injects the corpus snapshot (decision 3) into the user message, runs the LLM, the model emits a `parse_capture_to_items` tool call whose args are the `ParsedItem[]` payload. `DayAgentStrategy` validates each item, persists as `ParsedItemEntity` rows + `capture_to_parsed_item` / `parsed_item_to_task` links, then ends the wake. UI sees results arrive via the stream provider from decision 6.
7. **`create_task_from_phrase`** — deferred via `ChangeSetEntity` proposal. Out of scope for first phase-2 commit; ship after 1–6 are green.

Each tool gets a `DayAgentToolNames` constant, a `dayAgentTools` JSON-schema entry, a dispatch arm in `DayAgentStrategy.processToolCalls`, and a handler in `DayAgentWorkflow.executeToolHandler` (or a sibling service for the pure-mutation ones).

## D. Workflow extensions

- `DayAgentWorkflow._buildUserMessage` gets a new `_captureContext()` helper that, when the wake's trigger tokens include `capture_submitted:<id>`, loads the capture + the corpus snapshot and embeds them in the user message.
- `DayAgentStrategy.processToolCalls` adds dispatch arms for the new tools. The model is constrained by directive update — phase 2 seeded directive replaces the "only observations and wakes" sentence with the actual phase-2 tool list and the matching/threshold guidance from decision 5.
- Seeded directive migration: bump the day-agent template head version. Existing day-agent instances pick up the new directive on their next wake.

## E. UI integration

- `lib/features/daily_os_next/logic/real_day_agent.dart` — the adapter from decision 7.
- `dayAgentProvider` flips to `RealDayAgent(mockFallback: MockDayAgent())`.
- `parsedItemsForCaptureProvider(captureId)` — new Riverpod stream provider, watched by `ReconcileController` instead of the current direct `Future` call.
- `ReconcileController.build()` reads the **pending** stream and the parsed-items stream in parallel — both are now real subscriptions.
- The Capture page's `submitCapture` becomes a real write; navigation to Reconcile passes a real `CaptureId`.

## F. Tests

Per tool:
- **Unit:** strategy + workflow tests under `test/features/daily_os_next/agents/...` mirroring the source tree. Property-test (Glados) the matching threshold + the dedup/sort in `surface_pending_decisions`.
- **Integration:** one end-to-end test per tool path that drives a fake wake through `DayAgentWorkflow`, asserts the persisted entities, and reads them back through the UI's stream provider.
- **UI:** widget tests update from `MockDayAgent` overrides to overrides of `dayAgentServiceProvider` + the new Riverpod streams. Existing 80 tests must continue to pass.

## G. Risks

- **LLM output validation** — the model emits structured `ParsedItem[]`; if a row has `matchedTaskId` pointing at a non-existent task or an unknown `categoryId`, the strategy must reject the row (don't persist) and surface a `low_confidence` fallback. Strict JSON-schema check in the dispatcher.
- **Wake latency** — parse takes a few seconds; the UI's loading state in Reconcile must handle a 5–10 s gap gracefully. The stream-provider path handles this naturally (empty list while parsing).
- **Corpus-snapshot size** — 200-task cap (decision 3) keeps the prompt bounded; revisit if real users hit the cap.
- **Existing-user migration** — day agents created during phase 1 are bound to the v1 directive. They keep working (the new tools are additive) but won't actively use them until their template head version advances. Phase 2 commit must seed the v2 template and update existing identities' `currentVersionId` pointer.

## H. Open follow-ups (out of scope for phase 2)

- Soul / preference learning for matched/unmatched items as feedback for `TemplateEvolutionWorkflow` (parent §D).
- Wiring `submit_capture` to the real `features/speech` pipeline (parent decision 4 lock).
- `create_task_from_phrase` proposal flow once the first six tools are green.
