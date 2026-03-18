# Voice-Driven Time Tracking Entries

## User Story

As a user tracking my work via voice, I want to say things like "I worked on the API
integration from 2 PM to 4 PM" or "Start a timer at 7 PM", and have the app create
time tracking entries automatically, so I can log work sessions without manual input.

## Overview

This plan adds a new AI tool call, `create_time_entry`, to the task agent's tool
registry. When a user dictates a work session description, the LLM extracts start/end
times and a distilled summary, then calls the tool to create a `JournalEntry` linked
to the current task — with `meta.dateFrom` / `meta.dateTo` representing the tracked
time span.

---

## Technical Approach

### Design Decisions

1. **Single tool, two modes** — `create_time_entry` handles both completed sessions
   (start + end) and running timers (start only). A single tool keeps the LLM's
   decision surface small and avoids ambiguity about which tool to use.

2. **JournalEntry, not Task** — Time entries are `JournalEntity.journalEntry` instances
   linked to the parent task. This matches how manual time tracking already works:
   journal entries under a task carry `dateFrom`/`dateTo` that represent tracked time.
   Tasks represent work items; journal entries represent time blocks.

3. **Deferred execution (user confirmation)** — The tool is registered as a deferred
   tool in `AgentToolRegistry.deferredTools`. This means the proposed time entry appears
   in the change set for the user to approve before persisting. This is critical because
   the user story explicitly states "the user will approve the entries later."

4. **Running timers via TimeService** — When only `startTime` is provided (no `endTime`),
   the handler creates the journal entry and starts `TimeService` on it, producing the
   familiar running-timer UX with per-second updates.

5. **Recency constraint in tool description** — The tool description explicitly
   instructs the LLM to only create entries for *very recent* dictation (last few
   minutes to ~1 hour). The system prompt will inject the current timestamp to anchor
   the LLM's temporal reasoning.

6. **Dedicated handler class** — Follows the established pattern: a
   `TimeEntryHandler` class (like `FollowUpTaskHandler`) encapsulates creation logic,
   returns `ToolExecutionResult`, and is independently testable.

7. **No duplicate guarding** (iteration 1) — Per requirements, we skip overlap
   detection. The user approves entries via the change set UI, making duplicates a
   cosmetic concern handled later.

---

## Tool Definition

### `create_time_entry`

```json
{
  "name": "create_time_entry",
  "description": "Create a time tracking entry for a work session on the current task. Use ONLY when the user has JUST NOW (within the last few minutes to ~1 hour) dictated what they worked on. The dictation must be from the current recording session — NEVER create entries based on old transcripts, historical context, or text from previous wakes. If unsure whether the dictation is recent, do NOT call this tool. Supports two modes: (1) completed session with start and end times, (2) running timer with start time only (omit endTime).",
  "parameters": {
    "type": "object",
    "properties": {
      "startTime": {
        "type": "string",
        "description": "Start time in ISO 8601 format (e.g., '2026-03-17T14:00:00'). Must be today's date. Resolve spoken times like '2 PM' or '14:00' to full ISO 8601 using the current date from context."
      },
      "endTime": {
        "type": "string",
        "description": "End time in ISO 8601 format. Omit to start a running timer. Must be after startTime and on the same day. Must not be after the current wake timestamp."
      },
      "summary": {
        "type": "string",
        "maxLength": 500,
        "description": "A distilled 1-2 sentence summary of what the user worked on. Extract the essence from the dictation — do not copy verbatim. Write in the task's content language."
      }
    },
    "required": ["startTime", "summary"],
    "additionalProperties": false
  }
}
```

### Registration Points

| File | Change |
|------|--------|
| `agent_tool_registry.dart` | Add `createTimeEntry` to `TaskAgentToolNames`, add `AgentToolDefinition` to `taskAgentTools`, add to `deferredTools` set |
| `task_tool_dispatcher.dart` | Add `case TaskAgentToolNames.createTimeEntry:` routing to `TimeEntryHandler` |

---

## Handler: `TimeEntryHandler`

**File:** `lib/features/agents/tools/time_entry_handler.dart`

### Responsibilities

1. **Parse & validate arguments** — Extract `startTime`, optional `endTime`, `summary`.
2. **Temporal validation:**
   - `startTime` / `endTime` must parse to valid **local** ISO 8601 timestamps
     with an explicit time component (no date-only values, no timezone suffix).
   - If `endTime` is omitted: running-timer mode. `startTime` must be today
     relative to `clock.now()` and must not be in the future.
   - If `endTime` is provided: completed-session mode. `startTime` / `endTime`
     must be validated against the originating wake timestamp (carried through
     deferred confirmation) rather than the later approval time, so approvals
     after midnight still work.
   - `endTime` must be after `startTime`, on the same day, and not after the
     wake timestamp reference used for the completed session.
3. **Create JournalEntry** — Build metadata via `PersistenceLogic.createMetadata()`
   with:
   - `dateFrom` = parsed `startTime`.
   - `dateTo` = parsed `endTime` for completed sessions, otherwise `null`.
   - `categoryId` = inherited from the source task.
4. **Persist in a single write** — Create `JournalEntity.journalEntry(...)` with
   the generated summary text and persist it via `PersistenceLogic.createDbEntity()`
   using `linkedId = sourceTaskId`.
5. **Start running timer** (if no `endTime`) — Call `TimeService.start()` with the
   created in-memory entity and the linked task.
6. **Return `ToolExecutionResult`** — With the new entry's ID as `mutatedEntityId`.

### Constructor Dependencies

```dart
TimeEntryHandler({
  required PersistenceLogic persistenceLogic,
  required JournalDb journalDb,
  required TimeService timeService,
  DomainLogger? domainLogger,
})
```

### Error Cases

| Condition | Response |
|-----------|----------|
| Missing/unparseable `startTime` | Error: "startTime must be a valid ISO 8601 datetime" |
| Running-timer `startTime` not today | Error: "startTime must be today's date" |
| Completed-session `startTime` not on wake date | Error mentioning the wake timestamp reference |
| Completed-session `startTime` / `endTime` after wake timestamp | Error mentioning the wake timestamp reference |
| `endTime` before `startTime` | Error: "endTime must be after startTime" |
| `endTime` on a different day | Error: "endTime must be on the same day as startTime" |
| Empty `summary` | Error: "summary must be a non-empty string" |
| Timer already running | Error: "a timer is already running — stop it first" |
| Entry persistence failure | Error: "failed to persist time entry" |

---

## Integration with Task Agent Strategy

The tool is **deferred**, meaning `TaskAgentStrategy` adds it to the `ChangeSetBuilder`
rather than executing immediately. On approval, `ChangeSetConfirmationService`
injects the `ChangeSetEntity.createdAt` timestamp as an internal reference so
completed sessions validate against the originating wake rather than the later
approval moment. The change set UI will show:

- **Tool name:** `create_time_entry`
- **Preview:** The summary text + formatted time range (e.g., "14:00–16:00")
- **On approval:** `TaskToolDispatcher.dispatch()` → `TimeEntryHandler.handle()`

No changes to `TaskAgentStrategy` itself are needed — the existing deferred-tool
flow handles this automatically via the `deferredTools` set.

---

## System Prompt Context

The task agent's system prompt already receives the current date/time context. We will
ensure the following is present in the context passed to the LLM when audio entries
are being processed:

```text
Current date and time: 2026-03-17T15:30:00 (local timezone)
```

This anchors the LLM's interpretation of spoken times like "from 2 PM" and enables the
recency check ("was this dictated just now?").

If the task agent workflow (`TaskAgentWorkflow`) does not already inject a current
timestamp, we add it to the user message preamble. Check the existing implementation
and add if absent.

---

## File Changes Summary

### New Files

| File | Purpose |
|------|---------|
| `lib/features/agents/tools/time_entry_handler.dart` | Handler for `create_time_entry` tool |
| `test/features/agents/tools/time_entry_handler_test.dart` | Unit tests for the handler |

### Modified Files

| File | Change |
|------|--------|
| `lib/features/agents/tools/agent_tool_registry.dart` | Add tool name constant, tool definition, deferred registration |
| `lib/features/agents/workflow/task_tool_dispatcher.dart` | Add dispatch case for `create_time_entry` |
| `test/features/agents/tools/agent_tool_registry_test.dart` | Update tool count assertions if they exist |
| `test/features/agents/workflow/task_tool_dispatcher_test.dart` | Add dispatch tests for the new tool |

---

## Implementation Steps

### Phase 1: Tool Definition & Registry
1. Add `createTimeEntry = 'create_time_entry'` to `TaskAgentToolNames`.
2. Add the `AgentToolDefinition` to `taskAgentTools` list.
3. Add `TaskAgentToolNames.createTimeEntry` to `deferredTools`.
4. Run analyzer + existing tests to verify no regressions.

### Phase 2: Handler Implementation
5. Create `TimeEntryHandler` class following `FollowUpTaskHandler` pattern.
6. Implement argument parsing with temporal validation.
7. Implement journal entry creation via `PersistenceLogic.createMetadata()`
   plus `PersistenceLogic.createDbEntity()` in a single DB write.
8. Implement completed-session validation against the originating wake
   timestamp carried through deferred confirmation.
9. Implement running-timer integration with `TimeService`.

### Phase 3: Dispatcher Integration
10. Add the dispatch case in `TaskToolDispatcher`.
11. Wire up handler dependencies (inject `TimeService` into dispatcher).

### Phase 4: Testing
12. Unit tests for `TimeEntryHandler`:
    - Happy path: completed session (start + end).
    - Happy path: running timer (start only).
    - Validation: missing startTime, bad format, wrong day, end before start, future end.
    - Edge case: timer already running.
    - Verify correct `dateFrom`/`dateTo` on created entry.
    - Verify `TimeService.start()` called for running timers.
13. Integration test for dispatcher routing.
14. Run full analyzer pass.

### Phase 5: Verification
15. Run `make analyze` — zero warnings.
16. Run targeted tests — all green.
17. Manual smoke test via voice recording linked to a task.

---

## Future Extensibility

### Gap-Filling and Historical Context (P3)

**Design hooks already in place:**

- The task agent's system prompt already receives full task context including linked
  journal entries with their `dateFrom`/`dateTo` timestamps. A future iteration can:
  1. Add a query that fetches all time entries for a given day on the current task
     (already possible via existing `journal` table indexes on `date_from`/`date_to`).
  2. Include this data in the agent's context as "already tracked today" blocks.
  3. The LLM can then identify gaps and suggest entries to fill them.

- **No schema changes required.** The `create_time_entry` tool already accepts
  arbitrary start/end times within today. Gap-filling is purely a prompt-engineering
  and context-injection concern.

- **Potential new tool:** `suggest_time_entries` (returns multiple suggestions in a
  single call). Alternatively, the LLM can call `create_time_entry` multiple times
  in one turn — the multi-turn conversation loop already supports this.

- **Implementation approach:** Add a `TimeEntryContextBuilder` that queries the day's
  existing entries and formats them as a timeline for the LLM. Inject into the user
  message alongside the transcript. The LLM identifies gaps and proposes entries.

### Session Ratings (P3)

**Design hooks already in place:**

- The `create_time_entry` tool schema can be extended with an optional `rating`
  parameter without breaking existing calls (JSON Schema allows additive optional
  fields).

- The app already has a rating system for journal entries — `DurationWidget` triggers
  a rating prompt when a recording stops (≥ 1 minute). The same rating persistence
  mechanism can be reused.

- **Proposed extension:**
  ```json
  "rating": {
    "type": "object",
    "properties": {
      "score": {
        "type": "integer",
        "minimum": 1,
        "maximum": 5,
        "description": "Session quality rating (1-5)"
      },
      "note": {
        "type": "string",
        "description": "Optional note about the session quality"
      }
    }
  }
  ```

- **Handler change:** After creating the entry, if `rating` is present, persist it
  via the existing rating mechanism linked to the new entry's ID.

- **No architectural changes required** — the tool definition is additive, the handler
  gains a conditional branch, and the rating persistence already exists.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| LLM creates entries for old dictation | Strong tool description constraint + current-timestamp injection. Iteration 2 can add server-side recency checks. |
| LLM misinterprets spoken times (e.g., AM/PM confusion) | User confirmation via deferred tool flow. The change set preview shows the parsed times for review. |
| Running timer conflicts (timer already active) | Handler checks `TimeService.getCurrent()` and rejects if non-null. |
| Timezone handling | Use local time consistently. `clock.now()` and parsed ISO strings are both local. |
| `TimeService` not available in dispatcher | Add it as a dependency. It's already registered in GetIt as a singleton. |

---

## Out of Scope (Iteration 1)

- Duplicate/overlap detection
- Multi-day time entries
- Editing existing time entries via voice
- Gap-filling suggestions
- Session ratings
- Cross-task time entries (entry is always linked to the current task)
