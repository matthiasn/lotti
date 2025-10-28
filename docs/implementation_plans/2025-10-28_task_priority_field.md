# Task Priority Field Plan

## Summary

- Introduce a first-class task priority with four levels and canonical short codes:
  - P0 — Urgent
  - P1 — High
  - P2 — Medium
  - P3 — Low
- Store priority in the task model and denormalize into the `journal` table using two columns for optimal sorting and readability:
  - `task_priority TEXT` (e.g., `P0..P3`)
  - `task_priority_rank INTEGER` (0..3)
- Let users set priority in the task header via a compact picker; render compact priority chips on task cards (Linear-style).
- Extend the task filter to select one or more priorities and update default ordering to sort by priority rank.
- Preserve existing behavior when no explicit priority is set by defaulting legacy tasks to P2 (Medium).
- Follow AGENTS.md: MCP tooling, analyzer/tests green, docs + CHANGELOG updated, avoid touching generated files directly.

## Goals

- Model: Add `TaskPriority` enum and surface on `TaskData` with JSON persistence and sane defaults.
- Storage: Denormalize as `journal.task_priority` with index support for efficient filtering/sorting.
- UX: 
  - Header: Priority section next to existing task metadata controls with an edit affordance.
  - Card: Compact chip showing `P0…P3` color-coded, visually consistent with label chips.
  - Picker: Short codes with spelled-out explanations (e.g., “P0 — Urgent (ASAP)”).
- Filtering: Add a priority filter section to the Tasks filter modal; persist in `TasksFilter`.
- Ordering: Primary sort by priority (P0→P3), secondary by due date (asc) if present, then by `date_from` (desc).
- Testing: Unit + widget + repository coverage; keep analyzer at zero warnings and CI green.

## Non-Goals

- Implementing due dates (tracked separately).
- Reworking broader tasks UX beyond adding priority controls and chips.
- Server-side analytics or ML heuristics based on priority (future work).

## Decisions (after brief research/fit analysis)

- Short codes in UI: Use `P0…P3` to minimize footprint on cards; the picker and tooltips spell out meanings.
- Color scheme: Align with existing semantic palette and label chip style; P0 red, P1 orange, P2 blue, P3 grey (reuse existing theme tokens where possible).
- Storage approach: Denormalize two columns on `journal` (task rows only): `task_priority TEXT` and `task_priority_rank INTEGER`. The INT enables efficient ORDER BY and indexing; TEXT aids debugging and ad‑hoc queries.
- Default for legacy tasks: P2 (Medium) to avoid “no priority” ambiguity and simplify filtering semantics.

## Current Findings

- Tasks list queries live in `lib/database/database.drift` (`filteredTasks`, `filteredTasks2`) and sort by `date_from DESC`.
- Task filters persist via `TasksFilter` (`lib/blocs/journal/journal_page_state.dart`) and `JournalPageCubit.persistTasksFilter()`.
- Task cards are implemented in `lib/features/journal/ui/widgets/list_cards/modern_task_card.dart` with chips for status and due date; labels render as chips via `LabelChip`.
- Task header metadata row lives in `lib/features/tasks/ui/header/task_info_row.dart` (estimated time, category, language, status) and labels have their own wrapper/sheet.
- DB schema and migrations are managed in Drift (`lib/database/database.drift`, `lib/database/database.dart` migrations). Index `idx_journal_tasks` presently includes `(type, task_status, category, date_from)`.

## Data Model

1. Add enum `TaskPriority { p0Urgent, p1High, p2Medium, p3Low }` with helpers:
   - `int get rank => index` (0..3)
   - `String get short => 'P$rank'` (P0..P3)
   - `String get toDbString => short`
   - `Color colorForBrightness(Brightness)` using existing theme tokens
   - Parsing should follow the existing top-level helper pattern (mirrors `taskStatusFromString`):
     - Top-level function: `TaskPriority taskPriorityFromString(String value, {TaskPriority fallback = TaskPriority.p2Medium})`

2. Extend `TaskData` (`lib/classes/task.dart`) with:
   - `TaskPriority priority` (default: `TaskPriority.p2Medium`)
   - Update Freezed JSON via build_runner (do not hand-edit generated files)

3. Denormalize to DB:
   - Add `journal.task_priority TEXT` and `journal.task_priority_rank INTEGER`
   - Backfill existing tasks to `P2` and `2`
   - Composite index includes `task_priority_rank` for ordering

   Drift schema column syntax (explicit):
   - `task_priority TEXT,`
   - `task_priority_rank INTEGER,`

## Database & Migrations

- Drift schema (`lib/database/database.drift`):
  - Add columns: `task_priority TEXT` and `task_priority_rank INTEGER`
  - Replace `idx_journal_tasks` with index including priority rank:
    - `(type, task_status, task_priority_rank, category, date_from)`
  - Extend queries:
    - `filteredTasks`/`filteredTasks2` add a priority filter block mirroring the label filter pattern:
      - `AND (CASE WHEN :filterByPriorities THEN task_priority IN :priorities ELSE 1 END) = 1`
      - Keep Dart guard to avoid empty `IN ()` clauses
    - Update `ORDER BY` to prioritize rank, then `date_from DESC` (due date tie-breaker is deferred to the separate “due date” task):
      - `ORDER BY COALESCE(task_priority_rank, 2) ASC, date_from DESC`

   Drift query parameter additions (mirrors label filter pattern):
   - `:filterByPriorities BOOLEAN`
   - `:priorities List<String>`

- Migration (`lib/database/database.dart`):
  - Bump `schemaVersion` to 29
  - `onUpgrade`: add both columns, backfill P2/2 for existing tasks, drop/recreate `idx_journal_tasks`
  - Sample snippet:
    ```dart
    if (from < 29) {
      await () async {
        debugPrint('Adding task priority columns and updating index');
        await m.addColumn(journal, journal.taskPriority);
        await m.addColumn(journal, journal.taskPriorityRank);
        await customStatement(
          "UPDATE journal SET task_priority = 'P2', task_priority_rank = 2 WHERE task = 1",
        );
        // Replacing an existing index requires dropping it first to avoid errors
        await customStatement('DROP INDEX IF EXISTS idx_journal_tasks');
        await m.createIndex(idxJournalTasks);
      }();
    }
    ```

## Domain & Conversions

- `lib/database/conversions.dart`:
  - `toDbEntity`:
    - `taskPriority: entity.maybeMap(task: (t) => t.data.priority.toDbString, orElse: () => null)`
    - `taskPriorityRank: entity.maybeMap(task: (t) => t.data.priority.rank, orElse: () => null)`
  - `fromDbEntity`: continue to reconstruct from serialized JSON; treat DB columns as denormalized/read-optimized only. When serialized JSON lacks the field (legacy tasks), default to `TaskPriority.p2Medium` in model code.

## UX & UI

- Task header
  - Add `TaskPriorityWrapper` alongside `EstimatedTimeWrapper`, `TaskCategoryWrapper`, `TaskLanguageWrapper`, `TaskStatusWrapper` in `TaskInfoRow`
  - Show a chip/button using the label chip style with `P0…P3` and color-coded background
  - Tap opens `TaskPrioritySheet` with radio-list:
    - P0 — Urgent (ASAP)
    - P1 — High (Soon)
    - P2 — Medium (Default)
    - P3 — Low (Whenever)
  - Persist via entry controller/repository, update DB denormalized column via `updateJournalEntity`

- Task card (`ModernTaskCard`)
  - Insert a compact priority chip into the `statusRow` before the status chip
  - Reuse `ModernStatusChip` with `label: 'P0…P3'` and color from `TaskPriority.colorForBrightness`
  - Short code only on cards; full description appears in picker/tooltips

- Visual language
  - Colors (reuse existing tokens):
    - P0: `taskStatusRed` (dark) / `taskStatusDarkRed` (light)
    - P1: `taskStatusOrange` (dark) / `taskStatusDarkOrange` (light)
    - P2: `taskStatusBlue` (dark) / `taskStatusDarkBlue` (light)
    - P3: `Colors.grey`
  - Accessibility: ensure WCAG AA contrast, switch text color by luminance

## Filtering & Ordering

- Filter UI
  - Add `TaskPriorityFilter` to the Tasks filter modal below Status/Category/Label
  - Use chips: `P0`, `P1`, `P2`, `P3`, plus `All`
  - Persist selection to `TasksFilter`

- Filter state
  - Extend `TasksFilter` (Freezed) with `selectedPriorities: Set<String>` storing `{'P0','P1',...}`
  - Add `toggleSelectedPriority(String priority)` and `clearSelectedPriorities()` in `JournalPageCubit` (mirror label methods)
  - Load/Save via `JournalPageCubit` with per-tab keys (matches existing persistence split)

- Repository query
  - `JournalDb.getTasks(...)` signature extended to accept `priorities` list; plumb through `_selectTasks` to Drift query params
    - In `lib/database/database.dart` within `class JournalDb`:
      ```dart
      Future<List<JournalEntity>> getTasks({
        required List<bool> starredStatuses,
        required List<String> taskStatuses,
        required List<String> categoryIds,
        List<String>? labelIds,
        List<String>? priorities, // new
        List<String>? ids,
        int limit = 500,
        int offset = 0,
      })
      ```
  - If empty selection, treat as all four values (avoid empty IN())

- Ordering
  - Default task list sort becomes: priority rank (P0→P3) then `date_from DESC`
  - Due date tie-breaker remains a follow-up when due is denormalized (separate task).

## i18n

- `lib/l10n/app_en.arb` add keys:
  - `tasksPriorityTitle`: "Priority"
  - `tasksPriorityP0`: "Urgent"
  - `tasksPriorityP1`: "High"
  - `tasksPriorityP2`: "Medium"
  - `tasksPriorityP3`: "Low"
   - `tasksPriorityPickerTitle`: "Select priority"
   - `tasksPriorityFilterTitle`: "Priority"
   - `tasksPriorityFilterAll`: "All"
   - Descriptions for picker list:
     - `tasksPriorityP0Description`: "Urgent (ASAP)"
     - `tasksPriorityP1Description`: "High (Soon)"
     - `tasksPriorityP2Description`: "Medium (Default)"
     - `tasksPriorityP3Description`: "Low (Whenever)"
   - Provide placeholders/translations mirrors for existing locales

## Testing Strategy

- Analyzer & formatting
  - Run `dart-mcp.analyze_files` and `dart-mcp.dart_format` after changes; maintain zero warnings

- Unit tests
  - `TaskPriority` enum mapping (short/label/db string) and default behavior
  - Conversions: `toDbEntity`/`fromDbEntity` priority round-trip with/without legacy values

- Repository/DB tests
  - Migration v28→v29 adds both columns, backfills P2/2, and preserves existing rows
  - Filtering by each priority and multi-select combinations
  - Ordering by priority rank then `date_from` (until due is denormalized)

- Test data best practices (per CLAUDE.local.md):
  - Avoid `DateTime.now()`; use fixed timestamps
  - Assert on actual DB/model values; never rely on assumptions without verifying state

- Example test cases
  - Migration test: v28→v29 preserves all task data and sets `P2`/`2`
  - Ordering test: verify order by rank then `date_from DESC` across mixed priorities

- Widget tests
  - Header `TaskPriorityWrapper` pick/change reflects in chip and persists
  - `TaskPrioritySheet` content and selection behavior
  - Card chip renders correct short code and color

- Integration (optional where infrastructure exists)
  - Create tasks with various priorities → filter by priority → verify list contents and ordering

## Risks & Mitigations

- Analyzer drift or generated files out-of-sync
  - Mitigate by running build_runner via `make build_runner` and MCP

- SQL empty `IN ()` when no priorities selected
  - Mitigate in Dart by substituting all values when selection is empty; in Drift, gate with `:filterByPriorities` as with labels

- Paging + ordering consistency when sorting by derived priorities
  - Prefer storing an integer `task_priority_rank` and index it; if TEXT only, ensure stable ORDER BY mapping

- Visual clutter on small screens
  - Use short codes on cards; wrap chips; leverage tooltips/spell-outs in picker only
- Color consistency
  - Reuse existing theme tokens (e.g., `taskStatusRed`, `taskStatusOrange`) for priority chip colors to maintain visual harmony

## Rollout & Telemetry

- Migration: bump schema version, add column, backfill P2, adjust index
- Feature flags: not required; safe incremental UI exposure
- CHANGELOG: add entry under “feat: tasks: priority field + filtering + ordering”
- QA checklist: verify header edit, card chip, filter combinations, ordering precedence, persistence across app restarts

## Open Questions

- Store both `task_priority_rank INT (0..3)` and `task_priority TEXT`?
  - Yes — adopted in this plan for efficient ORDER BY and readable queries.

- Allow “No priority” state?
  - Recommended no (default to P2) to reduce filter complexity; revisit if user feedback demands

- Due date ordering precedence
  - Deferred to the separate “due date” task; once denormalized, apply as secondary ASC tie-breaker.

## Acceptance Criteria

- Users can set priority on a task and see it on the header and task cards.
- Tasks can be filtered by priority and default-sort by priority with defined tie-breakers.
- Migration runs cleanly, backfills P2 for legacy tasks, and indices exist.
- Analyzer shows zero warnings; all relevant tests pass in CI.
- Docs and CHANGELOG updated.

## Implementation Phases

1) Modeling & i18n
- Add `TaskPriority` enum and update `TaskData` + i18n strings

2) Persistence & Migration
- Add `task_priority` and `task_priority_rank` to Drift schema and migration v29; update conversions

2.5) Codegen Sync
- Run `make build_runner` to regenerate Freezed/Drift after model/schema changes

3) Repository & Queries
- Extend `getTasks`/`_selectTasks`/Drift queries to filter and order by priority; update index

4) UI: Header + Picker + Card
- Add `TaskPriorityWrapper`, `TaskPrioritySheet`, and `PriorityChip`; insert into `TaskInfoRow` and `ModernTaskCard`

5) Filtering UI & State
- Add `TaskPriorityFilter`; extend `TasksFilter` and `JournalPageCubit` persistence

6) Testing
- Unit, repository, widget tests as above; run analyzer/formatter, then full test run

7) Documentation & CHANGELOG
- Update feature READMEs and `CHANGELOG.md` with usage and QA notes

---

This plan consolidates the two transcripts into a concrete, review-ready implementation outline that fits the project’s architecture and prior patterns (labels/tags, tasks filtering, Drift migrations). It optimizes for performance (denormalized column + index), UI clarity (short `P0…P3` with spelled-out picker), and testability (clear phases and coverage).
