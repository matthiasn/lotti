# Agent Edits to Historical Time Entries

## User Story

As a user dictating into a task, I want the agent to revise any time-tracking
entry on that task — not just the running timer — based on what I just said.
For example: "the workshop yesterday actually ran 45 minutes longer and we
covered token budgets too." On the next wake, the agent should locate that
entry on this task's log, propose a new `dateTo` and a richer summary, and
route the change through the existing review UI so I can confirm, reject, or
let it sit pending while I record a follow-up correction.

## Overview

Today the task agent has two time-tracking tools:

- `create_time_entry` — proposes a new `JournalEntry` with a `dateFrom` /
  optional `dateTo` linked to the task. Completed sessions accept any prior
  day; running-timer mode requires today and rejects future timestamps. A
  same-day constraint forces `dateTo` and `dateFrom` onto the same calendar
  day. A `_referenceTimestamp` is injected at confirmation to relax the
  future cutoff after midnight.
- `update_running_timer` — proposes a new entry text for the *currently
  running* timer on this task. Text-only. Refuses if no timer is active or
  the active timer is on another task.

Neither tool can revise a **completed** time entry's text, `dateFrom`, or
`dateTo`. There is no path for "the meeting started at 13:30, not 14:00,"
"yesterday's workshop ran 45 minutes longer," or "the entry I logged Monday
should also mention the rollback discussion."

This plan does two things:

1. **Adds a third tool, `update_time_entry`**, scoped to historical
   (non-running) `JournalEntry` rows linked to the current task. It reuses
   the existing deferred-tool / change-set / review-UI machinery; the
   agent does not gain unilateral write access. It also exposes a new
   **Editable Time Entries** section in the wake prompt so the agent can
   reference past entries by ID with confidence.
2. **Simplifies `create_time_entry`** so completed sessions use the same
   temporal model as the new tool. Today's completed-session constraints
   — same-day for `dateTo` vs. `dateFrom`, future cutoff at wake time,
   `_referenceTimestamp`-based relaxation at confirmation — are removed.
   Completed sessions keep only `endTime > startTime`. Running-timer mode
   stays as it is today: `startTime` must be today and must not be in the
   future. A timer that starts tomorrow or yesterday is not a running
   timer in the product model. If a user wants to create a completed block
   for tomorrow, last year, spanning midnight, or anything else, the tool
   allows it.

The existing `update_running_timer` tool is **unchanged**. It retains
state validation: a timer must be actively running, it must belong to
this task, and the supplied `timerId` must match. Those invariants keep
`TimeService`'s in-memory snapshot consistent with the DB after the live
`dateTo = clock.now()` write. The new historical-edit tool explicitly
refuses to operate on the running timer's ID and tells the LLM to use
`update_running_timer` in that case. `create_time_entry` also keeps the
existing live-timer guards: a new running timer must start today and must
not start in the future.

---

## Technical Approach

### Design Decisions

1. **New tool, not an extension of `update_running_timer`.** The running
   timer handler synchronizes `TimeService._current` after persistence and
   sets `dateTo = clock.now()` to capture the live instant. Historical edits
   need none of that and would benefit from a different validation profile
   (no "must match running timer ID" check, but a "must NOT be the running
   timer" check). Keeping the handlers separate preserves the invariants of
   each.

2. **JournalEntry only.** The wider feature talks about "the entry type used
   for time recording, likely called journal text or similar." That maps to
   `JournalEntity.journalEntry` — see
   `lib/features/agents/tools/time_entry_handler.dart:202` where
   `create_time_entry` produces exactly this variant. Audio, image,
   measurement, and habit entries are out of scope for this tool; the
   handler returns an error if `entryId` resolves to a non-`JournalEntry`.

3. **No date restrictions for completed / historical entries.** Both
   `create_time_entry` completed sessions and `update_time_entry`
   historical edits share one temporal rule: `endTime > startTime` when
   both are present (a non-positive duration would break duration math
   throughout the app — `entryDuration`, `formatHhMm`, time-spent
   aggregations on tasks). Beyond that, completed / historical entries
   may be any day past or future, midnight-spanning, today, yesterday, or
   next year. The wake-anchored `_referenceTimestamp` mechanism is
   removed entirely from `create_time_entry` since completed sessions no
   longer have a future cutoff to relax. Running-timer creation keeps its
   current `same day as now` and `startTime <= clock.now()` checks because
   a live timer in this product represents work already underway today.

4. **Deferred tool, human-in-the-loop.** The tool registers in
   `AgentToolRegistry.deferredTools`. Proposals land on the existing
   `ChangeSetEntity`, render in `AgentSuggestionsPanel` /
   `SuggestionRow`, and are dispatched only on user confirmation — same
   flow as `create_time_entry`. The user's three options described in the
   feature spec (confirm / reject / leave pending while recording a
   follow-up correction) are all already supported by that flow.

5. **Surface entry IDs to the agent via a dedicated prompt section.** The
   existing `AiInputLogEntryObject` in `lib/features/ai/model/ai_input.dart`
   has no `id` field. Rather than mutate that model (touched by many
   non-agent paths), the workflow gains a new
   `_buildEditableTimeEntriesSection(...)` that mirrors
   `_buildActiveTimerSection(...)` (`task_agent_workflow.dart:1744`) and
   lists each editable `JournalEntry` linked to the task with its
   `entryId`, `dateFrom`, `dateTo`, current text, and "(running)" marker
   omitted (we filter it out — see Decision #6).

6. **Excludes the active timer's row.** If a `JournalEntry` is the
   currently running timer (matches `TimeService.getCurrent().meta.id`),
   it is **omitted** from the Editable Time Entries section. Updating live
   text is `update_running_timer`'s job. The handler additionally rejects
   the running timer ID at execution time as a defense-in-depth check
   against stale-context drift.

7. **At least one of `summary` / `startTime` / `endTime` must be set.** A
   call with only `entryId` is meaningless and is rejected at the handler.

8. **Persistence: extend `PersistenceLogic`.** Today
   `updateJournalEntityText(id, text, dateTo)` covers text + `dateTo`. We
   add a more general method that accepts optional `dateFrom`, optional
   `dateTo`, and optional `entryText`, applied via the existing
   `MetadataService.updateMetadata` / `updateDbEntity` pipeline. The new
   helper does **not** replace the existing one — `updateJournalEntityText`
   stays as the running-timer / audio / image fast path because it has its
   own `EntryFlag.import` clearing semantics for audio / image.

10. **`[generated]` suffix.** New summary text continues to be persisted
    with the trailing ` [generated]` marker, matching
    `RunningTimerUpdateHandler` (`running_timer_update_handler.dart:106`)
    and `TimeEntryHandler` (`time_entry_handler.dart:200`). Skipping the
    suffix on edits would be inconsistent with how authors of these
    entries are tracked downstream.

---

## Tool Definition

### `update_time_entry`

Registered alongside the existing time-tracking tools in
`agent_tool_registry.dart` (after the `update_running_timer` entry near
line 437). Description leans heavily on "evidence from the current
recording session" — same recency posture as `create_time_entry`.

```json
{
  "name": "update_time_entry",
  "description": "Revise an existing past time entry on this task — text, start time, end time, or any combination — when the user has JUST NOW dictated a correction or addition based on the current recording session. Use this when the wake context's `Editable Time Entries` section contains the entry the user is referring to. Do NOT use this for the currently running timer (use `update_running_timer` instead). Do NOT use this for entries on other tasks. Do NOT fabricate IDs — only reference IDs that appear in the Editable Time Entries section. The proposal is user-gated; the user reviews the diff before accepting.",
  "parameters": {
    "type": "object",
    "properties": {
      "entryId": {
        "type": "string",
        "description": "The ID of the journal entry to update, taken verbatim from the `Editable Time Entries` section of the wake context."
      },
      "startTime": {
        "type": "string",
        "description": "Optional new start time in local ISO 8601 format with explicit time and no timezone suffix (e.g., '2026-04-15T13:30:00'). Omit to keep the entry's current dateFrom."
      },
      "endTime": {
        "type": "string",
        "description": "Optional new end time in local ISO 8601 format. Omit to keep the entry's current dateTo. Must be strictly after the new (or unchanged) startTime — no other temporal restrictions (any day, past or future, is allowed)."
      },
      "summary": {
        "type": "string",
        "maxLength": 500,
        "description": "Optional revised 1-2 sentence summary of what the user worked on. Distill from the dictation — do not copy verbatim. Omit to keep the entry's current text. Written in the task's content language."
      }
    },
    "required": ["entryId"],
    "additionalProperties": false
  }
}
```

`required: ["entryId"]` plus a runtime "at least one of summary / startTime
/ endTime" check keeps the JSON schema valid while still rejecting empty
no-op calls.

### Registration Points

| File | Change |
|------|--------|
| `lib/features/agents/tools/agent_tool_registry.dart` | Add `updateTimeEntry = 'update_time_entry'` to `TaskAgentToolNames`; add `AgentToolDefinition` to `taskAgentTools`; add to `deferredTools` set |
| `lib/features/agents/workflow/task_tool_dispatcher.dart` | Add `case TaskAgentToolNames.updateTimeEntry:` routing |
| `lib/features/agents/workflow/task_agent_strategy.dart` (`_generateHumanSummary`) | Add a case producing `Update entry HH:mm–HH:mm: "..."` for the suggestions list |
| `lib/features/agents/service/change_set_confirmation_service.dart:355` (`_injectDispatchContext`) | **Remove the entire method.** With no completed-session wake cutoff left, the wake-timestamp injection has no consumer. Drop the special-case for `createTimeEntry`. (See "Existing-tool simplification" below.) |
| `lib/features/agents/tools/time_entry_handler.dart` | Strip completed-session same-day and future-cutoff checks. Keep `endTime > startTime`, summary validation, running-timer today-only / `startTime <= clock.now()` checks, "timer already running" guard, and source-task lookup. Remove `_resolveCompletedSessionReference` and the `_referenceTimestamp` arg consumer. |
| `lib/features/agents/time_entry_datetime.dart` | Delete `timeEntryReferenceTimestampArg` constant — no remaining consumer. Keep `parseTimeEntryLocalDateTime` and `formatTimeEntryHhMm`. |

---

## Existing-Tool Simplification: `create_time_entry`

**File:** `lib/features/agents/tools/time_entry_handler.dart`

The handler today (lines 113-173) carries multiple temporal rules. Only
completed-session creation is loosened to line up with
`update_time_entry`; live running timers keep their existing "today" and
"not in the future" constraints.
Concrete edits:

### Removed

- **Lines 136-145** — completed-session future cutoff against the
  resolved reference timestamp.
- **Lines 156-162** — `_isSameDay(endTime, startTime)` for completed
  sessions.
- **Lines 163-172** — completed-session `endTime` future cutoff.
- The `args[timeEntryReferenceTimestampArg]` read inside the handler.

### Kept

- Summary validation (non-empty, ≤ 500 chars).
- `startTime` parses cleanly via `parseTimeEntryLocalDateTime`.
- `endTime` parses cleanly when present (lines 84-111).
- Running-timer `_isSameDay(startTime, now)` check — a live timer must
  start today.
- Running-timer `startTime.isAfter(now)` check — a live timer cannot
  start in the future.
- `endTime.isAfter(startTime)` strict ordering check (lines 148-155) —
  the only temporal rule for completed sessions.
- Source-task lookup (lines 184-194) and category inheritance.
- "Timer already running" guard (lines 175-182) — non-temporal,
  protects `TimeService` against a second concurrent timer.
- Persistence via `createMetadata` + `createDbEntity` and the
  `TimeService.start()` call for running-timer mode (lines 196-250).

### Updated helper cleanup

- Keep `_isSameDay` because running-timer validation still uses it.
- **Lines 290-311** — `_resolveCompletedSessionReference` method (no
  remaining caller).

### Tool description rewrite (`agent_tool_registry.dart:351-396`)

Today's description correctly says a running timer must use today's date,
but it over-constrains completed sessions to today or earlier and same-day
end times. Rewrite only the completed-session parts:

> Create a time tracking entry for a work session on the current task.
> Use ONLY when the user has JUST NOW dictated what they worked on.
> Supports two modes: (1) completed session with start and end times
> (any day, past or future, including spans across midnight),
> (2) running timer with start time only (today only, never the
> future). The user reviews the proposal before it persists.

Argument descriptions: keep "must be today's date" and "must not be in
the future" for running-timer mode. Drop "must be on the same day as
startTime" and "Must not be after the current wake timestamp" from
`endTime`. Keep the local ISO 8601 format guidance and the "after
startTime" requirement on `endTime`.

### Confirmation service

Remove the `_injectDispatchContext` special case that today only fires
for `createTimeEntry`. After this plan, no time-tracking tool needs the
wake timestamp injected, so the method's only branch evaporates and the
method itself can be removed (or kept as a no-op identity for any
future deferred-tool that needs it; preference is to remove since
re-introducing it later is one line).

### Tests touched

- `test/features/agents/tools/time_entry_handler_test.dart` —
  delete the completed-session same-day / future-cutoff assertions and
  keep the "endTime > startTime" assertion. Keep or add rejection tests
  for running timers that start on another day or in the future. Add
  positive cases for: future completed block, last-year block, and
  midnight-spanning completed block.
- `test/features/agents/time_entry_datetime_test.dart` — drop the
  reference-timestamp constant assertion.
- `test/features/agents/service/change_set_confirmation_service_test.dart`
  — drop the `_referenceTimestamp` injection assertion for
  `createTimeEntry`.

---

## Handler: `TimeEntryUpdateHandler`

**File:** `lib/features/agents/tools/time_entry_update_handler.dart` (new)
**Test:** `test/features/agents/tools/time_entry_update_handler_test.dart` (new)

### Responsibilities

1. **Argument parsing.**
   - `entryId` — required non-empty string.
   - `summary` — optional; if present, must be a non-empty trimmed string
     ≤ 500 chars (matches `RunningTimerUpdateHandler:42`).
   - `startTime` / `endTime` — optional; if present, must parse via
     `parseTimeEntryLocalDateTime` (rejects date-only and timezone-suffixed
     strings, see `lib/features/agents/time_entry_datetime.dart:11`).
   - At least one of `summary`, `startTime`, `endTime` must be provided —
     otherwise return "no changes specified" error.

2. **Entity lookup & ownership.**
   - Load via `journalDb.journalEntityById(entryId)`.
   - Must be a `JournalEntry` (reject other variants with a clear error).
   - Must be an outgoing linked entity of `sourceTaskId`. `createDbEntity(
     linkedId: sourceTaskId)` creates `sourceTaskId → entryId`, and the
     task-progress / AI-input paths read those children with
     `JournalDb.getLinkedEntities(sourceTaskId)`. Use that same direction
     here and confirm the loaded linked-entity IDs contain `entryId`. This
     guards against an agent that hallucinates an ID from another task it
     saw in linked-task context.

3. **Running-timer guard.**
   - If `timeService.getCurrent()?.meta.id == entryId`, return
     `'use update_running_timer instead'` without naming the running
     timer's ID (preserve the cross-task secrecy posture from
     `running_timer_update_handler.dart:71-84`).

4. **Compute resolved values.**
   - `resolvedDateFrom = newStart ?? entry.meta.dateFrom`
   - `resolvedDateTo   = newEnd   ?? entry.meta.dateTo`
   - `resolvedText     = newSummary != null ? '$newSummary [generated]'
     : entry.entryText`

5. **Temporal validation against resolved values.**
   - `resolvedDateFrom < resolvedDateTo` — strict ordering. This is the
     **only** temporal rule. No same-day check, no future cutoff, no
     wake-relative anchor. Multi-day spans, future blocks, and historical
     blocks are all allowed.

6. **Persist.** Call the new
   `PersistenceLogic.updateJournalEntry(id, {entryText, dateFrom,
   dateTo})` helper (see Persistence Layer section).

7. **No `TimeService` sync.** Historical entries are not held in the
   in-memory time service; nothing to update.

8. **Return.** `ToolExecutionResult(success: true, output: ..., mutatedEntityId: entryId)`. `mutatedEntityId` lets the existing
   self-notification suppression in the agent runtime ignore the change
   set's own write back through the inbox.

### Error Cases

| Condition | Response |
|-----------|----------|
| Missing/blank `entryId` | "entryId must be a non-empty string" |
| All of `summary`, `startTime`, `endTime` omitted | "at least one of summary, startTime, endTime must be provided" |
| `summary` empty after trim or > 500 chars | "summary must be a non-empty string with at most 500 characters" |
| Unparseable `startTime` / `endTime` | "X must be a valid ISO 8601 datetime with explicit local time" |
| Entry not found | "entry $id not found" |
| Entry is not a `JournalEntry` | "entry $id is not a time-tracking journal entry" |
| Entry not linked from this task | "entry $id is not linked from this task" |
| Entry is the running timer | "use update_running_timer to edit the active timer" |
| Resolved `dateTo` ≤ resolved `dateFrom` | "endTime must be after startTime" |
| Persistence failure | "failed to persist time entry update" |

### Constructor

```dart
TimeEntryUpdateHandler({
  required PersistenceLogic persistenceLogic,
  required JournalDb journalDb,
  required TimeService timeService,
  DomainLogger? domainLogger,
});
```

Injected from `TaskToolDispatcher._handleUpdateTimeEntry(...)` mirroring
`_handleUpdateRunningTimer` (`task_tool_dispatcher.dart:572`).

---

## Persistence Layer

**File:** `lib/logic/persistence_logic.dart`

### New method: `updateJournalEntry`

The existing `updateJournalEntityText(id, text, dateTo)` (line 517) is too
narrow: it cannot change `dateFrom`, and it always writes a non-null
`entryText`. Add:

```dart
Future<bool> updateJournalEntry({
  required String journalEntityId,
  EntryText? entryText,
  DateTime? dateFrom,
  DateTime? dateTo,
});
```

Behavior:

- Look up the entity. Return `false` if missing.
- Return `false` if `entryText`, `dateFrom`, and `dateTo` are all omitted;
  otherwise this method would bump `updatedAt` / vector clock without an
  actual edit. The handler already rejects no-op proposals, but the
  persistence method should keep the same contract when tested directly.
- Type-guard: only operate on `JournalEntry` (the one variant the agent
  edit tool targets). For any other variant, return `false` so the caller
  surfaces a clean error. We do not extend the audio/image branches here
  — those have specialized `EntryFlag.import` clearing logic that is out
  of scope for time-entry editing and would couple this method to
  audio/image pipelines.
- Build `newMeta` via `updateMetadata(currentMeta, dateFrom: dateFrom,
  dateTo: dateTo)`. The existing `MetadataService.updateMetadata` already
  supports both args.
- `updateDbEntity(entry.copyWith(meta: newMeta, entryText: entryText ??
  entry.entryText))`.
- Same try/catch shape as `updateJournalEntityText` (lines 583-595): log
  via `_loggingService.captureException` with `subDomain:
  'updateJournalEntry'`, return `false` on caught exception so callers see
  a failure rather than a silent commit.

`updateJournalEntityText` stays for the existing journal-editor and
running-timer paths, including audio / image branches that depend on
their import-flag clearing semantics — no behavior changes there.

---

## Prompt Context: Editable Time Entries Section

**File:** `lib/features/agents/workflow/task_agent_workflow.dart`

Add a sibling to `_buildActiveTimerSection` (line 1744). Skeleton:

```dart
Future<String> _buildEditableTimeEntriesSection(
  Task task,
  TimeService? timeService,
) async {
  final runningId = timeService?.getCurrent()?.meta.id;
  // Iterate outgoing entities linked from `task` via
  // journalDb.getLinkedEntities(task.id), the same link direction used
  // by createDbEntity(linkedId: task.id), task progress, and AI log input.
  // Filter:
  //   - is JournalEntry (text time entry)
  //   - meta.id != runningId
  // Sort newest-first by dateFrom.
  // Render as a markdown list:
  //   - id: <uuid>
  //     dateFrom: <iso>
  //     dateTo:   <iso>
  //     text:     "<truncated to ~200 chars>"
}
```

Exact entry-iteration helper: call `journalDb.getLinkedEntities(task.id)`
directly from `TaskAgentWorkflow` or factor a small private
`_listEditableTimeEntries(task, timeService)` helper next to
`_buildActiveTimerSection`. Do **not** use
`AiInputRepository.buildLinkedFromContext` for this: that method returns
linked task context, not the raw non-task journal entries needed here.
`Metadata.dateFrom` and `Metadata.dateTo` are required fields, so no
nullable `dateTo` filter is needed; the active timer is excluded by ID.

The section is gated:

- If the task has zero editable entries → emit nothing. The LLM has no
  reason to call the tool, and `update_time_entry` itself will already be
  in the registry; the absence of context naturally discourages the call.
- If non-empty → emit, with a header that explicitly tells the LLM these
  IDs are the only ones it may pass to `update_time_entry`.

Section is appended to the prompt right after `_buildActiveTimerSection`,
keeping all time-related context together.

---

## Confirmation Service Changes

**File:** `lib/features/agents/service/change_set_confirmation_service.dart`

`_injectDispatchContext` (line 355) is removed entirely. Its sole
purpose was to carry the originating wake timestamp into
`create_time_entry` so the handler could relax the future cutoff at
confirmation time. With the completed-session cutoff dropped, no consumer
remains. The dispatch path now passes `item.args` through unmodified for
non-migration tools; the existing `create_follow_up_task` placeholder
resolution for checklist migration remains.

Reintroducing the mechanism in the future (if a new deferred tool ever
needs the wake timestamp) is a localized one-method addition.

---

## Review UI Changes

### `SuggestionRow` (`lib/features/agents/ui/suggestion_row.dart:113`)

Today the row branches on `createTimeEntry` to render `TimeEntryTile`.
Add a parallel branch for `updateTimeEntry` rendering a new
`TimeEntryUpdateTile`. Generic `humanSummary` fallback stays in place for
all other tools.

### New widget: `TimeEntryUpdateTile`

**File:** `lib/features/agents/ui/time_entry_update_tile.dart`
**Test:** `test/features/agents/ui/time_entry_update_tile_test.dart`

Renders a *diff* view so the user can confirm meaningfully:

- Two-column layout under a single timer icon, similar in spirit to
  `TimeEntryTile` (lines 47-99).
- Reads `entryId` / `startTime` / `endTime` / `summary` from `args`.
- Uses a narrow auto-dispose provider in this widget file (for example,
  a `FutureProvider.family<JournalEntity?, String>`) that reads
  `journalRepositoryProvider.getJournalEntityById(entryId)` to fetch the
  current entry's `dateFrom` / `dateTo` / text. There is no existing
  `journalEntityProvider`; `entryControllerProvider(id: ...)` exists but
  is editor-oriented and brings focus / draft state along with it. If the
  entry is unavailable (deleted, rejected-pending sync), render a
  degraded "current state unavailable" tile with the proposed values only.
- For each field that the proposal touches, show
  `current → proposed`. Untouched fields are displayed greyed-out
  using the current value only.
- Existing busy/progress indicator behavior matches `TimeEntryTile`.

Alternative considered: showing a single line of the new summary plus a
discreet "tap to expand" diff. Rejected — the user explicitly wants to
see what changed before confirming, and the sketched mock at
`Screenshot 2026-05-02 at 12.17.28.png` shows start/end values inline,
not collapsed.

### Localization

New ARB keys (added to all six primary ARBs per project policy in
`AGENTS.md` → "Localization"):

- `agentSuggestionTimeEntryUpdateCurrent` → "Current"
- `agentSuggestionTimeEntryUpdateProposed` → "Proposed"
- `agentSuggestionTimeEntryUpdateNoChange` → "(unchanged)"
- `agentSuggestionTimeEntryUpdateUnavailable` → "Original entry not available"

Run `make l10n` and `make sort_arb_files` after edits. Use informal
register for de/fr/es; formal `dvs.` for ro.

---

## File Changes Summary

### New Files

| File | Purpose |
|------|---------|
| `lib/features/agents/tools/time_entry_update_handler.dart` | Handler for `update_time_entry` |
| `lib/features/agents/ui/time_entry_update_tile.dart` | Review-UI tile rendering current → proposed diff |
| `test/features/agents/tools/time_entry_update_handler_test.dart` | Handler unit tests |
| `test/features/agents/ui/time_entry_update_tile_test.dart` | Tile widget tests |

### Modified Files

| File | Change |
|------|--------|
| `lib/features/agents/tools/agent_tool_registry.dart` | Add tool name, definition, deferred registration |
| `lib/features/agents/workflow/task_tool_dispatcher.dart` | Dispatch case + `_handleUpdateTimeEntry` |
| `lib/features/agents/workflow/task_agent_strategy.dart` | `_generateHumanSummary` branch |
| `lib/features/agents/workflow/task_agent_workflow.dart` | New `_buildEditableTimeEntriesSection`; wire into prompt assembly next to active timer section; update active-timer prompt wording that still says `create_time_entry` is only for earlier/prior-day sessions |
| `lib/features/agents/service/change_set_confirmation_service.dart` | Remove `_injectDispatchContext` and the now-unused `time_entry_datetime.dart` import. |
| `lib/features/agents/tools/time_entry_handler.dart` | Strip completed-session same-day and future-cutoff checks; remove `_resolveCompletedSessionReference` and the `_referenceTimestamp` consumer; keep running-timer today-only and future-start guards (see *Existing-Tool Simplification*). |
| `lib/features/agents/time_entry_datetime.dart` | Delete the `timeEntryReferenceTimestampArg` constant — no remaining consumer. |
| `lib/features/agents/ui/suggestion_row.dart` | Branch on `updateTimeEntry` to render new tile |
| `lib/logic/persistence_logic.dart` | New `updateJournalEntry({...})` method |
| `lib/l10n/app_en.arb` (+ cs/de/es/fr/ro/en_GB if spelling differs) | New labels for diff UI |
| Generated l10n via `make l10n` | (regenerated, not hand-edited) |

### Tests Updated

| File | Change |
|------|--------|
| `test/features/agents/tools/agent_tool_registry_test.dart` | Tool count assertions, presence of `updateTimeEntry` in deferred set |
| `test/features/agents/workflow/task_tool_dispatcher_test.dart` | Dispatch routes to handler |
| `test/features/agents/workflow/task_agent_workflow_test.dart` (or its sibling for prompt assembly) | Editable Time Entries section appears with correct content; running timer is excluded |
| `test/features/agents/service/change_set_confirmation_service_test.dart` | Drop the existing `_referenceTimestamp` injection assertion for `createTimeEntry` (the method is gone). |
| `test/features/agents/tools/time_entry_handler_test.dart` | Drop completed-session same-day / future-cutoff assertions; keep or add running-timer wrong-day and future-start rejections; add positive cases for future completed blocks, last-year blocks, and midnight-spanning completed blocks (see *Existing-Tool Simplification*). |
| `test/features/agents/time_entry_datetime_test.dart` | Drop the `timeEntryReferenceTimestampArg` constant assertion. |
| `test/features/agents/ui/suggestion_row_test.dart` | Renders `TimeEntryUpdateTile` for `updateTimeEntry` proposals |

No `*.freezed.dart` / `*.g.dart` regeneration is required — the new
arguments live in tool args (a plain `Map<String, dynamic>`) and we are
not introducing a new freezed model.

---

## Implementation Steps

### Phase 1 — Persistence helper

1. Add `PersistenceLogic.updateJournalEntry({...})`.
2. Unit-test it directly (not through the agent flow): write a journal
   entry, mutate text only, mutate dateFrom only, mutate both, mutate
   neither (returns false), entity-not-found, type-mismatch.
3. `make analyze`, run targeted tests.

### Phase 2 — Tool definition & registry

4. Add `updateTimeEntry` constant, `AgentToolDefinition`, deferred-set
   entry.
5. Add `_generateHumanSummary` branch.
6. Update registry tests.

### Phase 3 — Handler

7. Implement `TimeEntryUpdateHandler.handle(...)` against the persistence
   helper.
8. Write the full unit-test matrix described in *Testing* below.
9. Wire dispatcher case + `_handleUpdateTimeEntry`.
10. `make analyze`, targeted tests.

### Phase 4 — `create_time_entry` simplification

11. Strip completed-session same-day and future-cutoff checks from
    `time_entry_handler.dart` (see *Existing-Tool Simplification*). Keep
    running-timer `same day as now` and `startTime <= clock.now()` guards.
12. Update `create_time_entry`'s tool description and parameter
    descriptions in `agent_tool_registry.dart` to drop the now-stale
    completed-session "same day" / "not after wake timestamp" wording,
    while keeping the running-timer "today only" / "not in the future"
    wording.
13. Remove `_injectDispatchContext` from
    `change_set_confirmation_service.dart` and the
    `timeEntryReferenceTimestampArg` constant from
    `time_entry_datetime.dart`.
14. Update `_buildActiveTimerSection` wording in
    `task_agent_workflow.dart` so it no longer says distinct
    `create_time_entry` sessions must be earlier today or prior-day only.
15. Update / drop the affected tests:
    `time_entry_handler_test.dart` (drop completed-session temporal-fail
    assertions, keep / add running-timer wrong-day and future-start
    failures, add loose completed-session positive cases),
    `time_entry_datetime_test.dart`
    (drop constant assertion), `change_set_confirmation_service_test.dart`
    (drop injection assertion).

### Phase 5 — Prompt context

16. Implement `_buildEditableTimeEntriesSection` and the supporting
    helper (`_listEditableTimeEntries` in `TaskAgentWorkflow` if
    extracted).
17. Tests: empty list → no section; with entries → section formatted
    correctly; running timer is excluded; cross-task-linked entries are
    excluded; cap of N is enforced and ordering is newest-first.

### Phase 6 — Review UI

18. Build `TimeEntryUpdateTile` with the diff layout.
19. Localization: ARB updates → `make l10n` → `make sort_arb_files`.
20. Branch in `SuggestionRow`; widget tests.

### Phase 7 — End-to-end verification

21. `make analyze` — must be zero warnings.
22. `fvm dart format .`.
23. Targeted suites green: `time_entry_handler_test`,
    `time_entry_update_handler_test`, `suggestion_row_test`,
    `change_set_confirmation_service_test`, `task_agent_workflow_test`.
24. Manual smoke tests:
    - Dictate "the workshop yesterday actually ran 45 minutes longer
      and we covered token budgets too" into a task with a matching
      past entry; verify the agent proposes `update_time_entry`, the
      review row shows the diff, confirming persists the new `dateTo`
      + summary, rejecting leaves the entry untouched.
    - Dictate "log a 2-hour block on Saturday next week for the
      offsite" into a task; verify `create_time_entry` accepts the
      future date end-to-end (regression check on the simplified
      handler).
25. CHANGELOG entry under the current `pubspec.yaml` version (not
    `[Unreleased]`); matching `flatpak/com.matthiasn.lotti.metainfo.xml`
    update per project policy.
26. Update relevant feature READMEs (the agents README under
    `lib/features/agents/`, plus any time-tracking README that lists the
    agent toolset) to reflect the new tool and the
    `create_time_entry` simplification — architecture-first, with a
    Mermaid diagram for the proposal → confirmation flow if the README
    already uses that style.

---

## Testing Plan

Follow `AGENTS.md` "Test Infrastructure Rules" — central mocks
(`test/mocks/mocks.dart`), `setUpTestGetIt`, `makeTestableWidget`, fake
time, deterministic dates. No `Future.delayed` or `pumpAndSettle`-on-
animation; use `fakeAsync` where timers are involved.

### `TimeEntryUpdateHandler`

- Happy paths:
  - text-only update.
  - `dateFrom`-only update.
  - `dateTo`-only update.
  - all three updated in one call.
  - update on an entry from "yesterday" / "last week" (deterministic
    dates, e.g. `DateTime(2026, 4, 15, 13, 30)` with wake clock at
    `DateTime(2026, 5, 2, 9, 0)`).
- Validation failures (one test per row in the Error Cases table).
- Running-timer guard: when `TimeService.getCurrent().meta.id == entryId`,
  returns the "use update_running_timer" error and does **not** call
  persistence.
- Cross-task guard: entry is linked from a different task → rejected,
  no persistence.
- Loose-rules positive cases:
  - Edit dates onto a different calendar day from the original.
  - Edit `dateTo` to a future date.
  - Edit a midnight-spanning range.
- Persistence failure: `PersistenceLogic.updateJournalEntry` returns
  `false` → handler returns the "failed to persist time entry update"
  error and surfaces the right `ToolExecutionResult`.

### Workflow / prompt tests

- `_buildEditableTimeEntriesSection` returns empty string when no
  editable entries exist.
- Section content includes ID, ISO timestamps, truncated text.
- Running timer entry is excluded.
- Audio / image / measurement entries are excluded.
- Cross-task-linked entries are excluded.
- Newest-first ordering.

### UI tests

- `TimeEntryUpdateTile` shows `current → proposed` for each touched
  field, "(unchanged)" for untouched fields, and the unavailable state
  when the entry can't be loaded.
- `SuggestionRow` routes `update_time_entry` proposals to the new tile
  while keeping `create_time_entry` on the existing `TimeEntryTile`.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| LLM hallucinates an `entryId` or copies one from a linked task's report | Handler enforces "linked from this task" via DB check, not just prompt-level guidance. |
| LLM proposes nonsensical times (e.g. dates a century out) | The user reviews every proposal in the change-set UI before it persists. The diff tile shows the proposed `dateFrom` / `dateTo` explicitly, so wild values are obvious at a glance and rejected with one tap. |
| Race: user edits the entry manually between proposal and confirmation | The handler reads the entry at confirmation time, applies the agent's proposed deltas onto whatever is currently persisted (proposal stores only the *new* values, not a full snapshot). The diff UI reflects the up-to-date "current" so the user sees the actual base. If the user prefers an all-or-nothing semantics, they can reject and re-record. |
| Race: agent proposes the same edit twice across wakes | Existing `ChangeSetBuilder` fingerprint dedup catches identical `(toolName, args)` pairs; rejected fingerprints stay blocked. |
| Editing the running timer via this tool corrupts `TimeService` state | Handler refuses if `entryId == TimeService.getCurrent().meta.id`. The Editable Time Entries section also omits that row, so the LLM normally won't see it as a target. |
| Negative-duration entries (`endTime ≤ startTime`) | Both `create_time_entry` and `update_time_entry` keep the strict-ordering check; this is the one temporal rule that survives. |

---

## Out of Scope

- Editing time entries on tasks other than the one the agent is woken
  for — would broaden the agent's blast radius significantly and is not
  in the requirements.
- Editing audio / image / measurement / habit-completion entries — these
  have specialized data models, transcripts, and flag semantics. The
  user spec scopes this work to "journal text" entries.
- Splitting / merging / deleting entries — explicitly out of the
  feature's stated scope ("suggest edits" only).
- `update_running_timer` reorganization — it stays as is; this plan does
  not refactor running-timer semantics.

---

## Decisions

- **No partial-text edits.** The agent must always propose the full
  new summary. No append / prepend / insert variants, no
  `summaryAppend` arg. If append-style edits are ever needed, they
  ship as a separate tool, not as new args on this one.
- **Rejection signal: rely on existing infrastructure only.** Rejected
  `update_time_entry` proposals flow through the same path as every
  other deferred tool: they land in the `recent proposal activity`
  block of the next wake's prompt
  (`task_agent_workflow.dart:1469-1498`), and fingerprint dedup
  (`change_set_builder.dart`) blocks identical re-proposals. No
  per-entry cooldown, no inline rejection annotation in the Editable
  Time Entries section, no reason chips on the reject button. The
  `update_time_entry` tool gets no special-cased rejection handling.
