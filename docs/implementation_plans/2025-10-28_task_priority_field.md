# Task Priority Field Plan

## Summary

- Introduce a first-class task priority with four levels and canonical short codes:
  - P0 — Urgent
  - P1 — High
  - P2 — Medium
  - P3 — Low
- Store priority in the task model and denormalize into the `journal` table for fast filtering and ordering.
- Let users set priority in the task header via a compact picker; render compact priority chips on task cards (Linear-style).
- Extend the task filter to select one or more priorities and update default ordering to sort by priority.
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
- Color scheme: Align with existing semantic palette and label chip style; P0 red, P1 orange, P2 blue, P3 grey.
- Storage approach: Denormalize a single scalar column (`TEXT` or `INT`) on `journal` (task rows only) — simplest, indexable, and consistent with existing `task_status` patterns.
- Default for legacy tasks: P2 (Medium) to avoid “no priority” ambiguity and simplify filtering semantics.

## Current Findings

- Tasks list queries live in `lib/database/database.drift` (`filteredTasks`, `filteredTasks2`) and sort by `date_from DESC`.
- Task filters persist via `TasksFilter` (`lib/blocs/journal/journal_page_state.dart`) and `JournalPageCubit.persistTasksFilter()`.
- Task cards are implemented in `lib/features/journal/ui/widgets/list_cards/modern_task_card.dart` with chips for status and due date; labels render as chips via `LabelChip`.
- Task header metadata row lives in `lib/features/tasks/ui/header/task_info_row.dart` (estimated time, category, language, status) and labels have their own wrapper/sheet.
- DB schema and migrations are managed in Drift (`lib/database/database.drift`, `lib/database/database.dart` migrations). Index `idx_journal_tasks` presently includes `(type, task_status, category, date_from)`.

## Data Model

1. Add enum `TaskPriority { p0Urgent, p1High, p2Medium, p3Low }` with helpers:
   - `short`: `P0`…`P3`
   - `label`: localized long form (Urgent, High, Medium, Low)
   - `toDbString`: `P0`…`P3`
   - `fromDbString(String)` with default fallback to P2

2. Extend `TaskData` (`lib/classes/task.dart`) with:
   - `TaskPriority priority` (default: `TaskPriority.p2Medium`)
   - Update Freezed JSON via build_runner (do not hand-edit generated files)

3. Denormalize to DB:
   - `journal.task_priority TEXT NULL` default `'P2'` for backfill
   - Include in conversions: set from `TaskData.priority`; parse/read on load
   - Index/ordering support via composite index

## Database & Migrations

- Drift schema (`lib/database/database.drift`):
  - Add column: `task_priority TEXT` to `journal`
  - Update `idx_journal_tasks` to include `task_priority COLLATE BINARY ASC` ahead of `date_from` for efficient ordering/filtering
  - Extend queries:
    - `filteredTasks`/`filteredTasks2`: `AND task_priority IN :priorities` (treat empty list as all in Dart; avoid empty IN())
    - Update `ORDER BY` to `task_priority ASC, date_from DESC` with mapping where `P0 < P1 < P2 < P3`
      - Simpler: store rank alongside code in query; or store rank as `INT` instead and order by `ASC`

- Migration (`lib/database/database.dart`):
  - Bump `schemaVersion` to 29
  - `onUpgrade`: add `task_priority` column, rebuild/adjust `idx_journal_tasks` if needed
  - Backfill: set `task_priority = 'P2'` for existing task rows (`task = 1`) where null

## Domain & Conversions

- `lib/database/conversions.dart`:
  - `toDbEntity`: write `journal.taskPriority` from `TaskData.priority.toDbString`
  - `fromDbEntity`: prefer serialized JSON value; when missing, default to P2
  - Keep serialized JSON authoritative; DB column is a denormalized read-model

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
  - Render a compact `PriorityChip` to the left of status (or right of due date if space-constrained)
  - Use the same color system as header chip; short code only on cards

- Visual language
  - Colors: P0 red, P1 orange, P2 blue, P3 grey; align with existing theme tokens
  - Accessibility: ensure WCAG AA contrast, switch text color by luminance

## Filtering & Ordering

- Filter UI
  - Add `TaskPriorityFilter` to the Tasks filter modal below Status/Category/Label
  - Use chips: `P0`, `P1`, `P2`, `P3`, plus `All`
  - Persist selection to `TasksFilter`

- Filter state
  - Extend `TasksFilter` (Freezed) with `selectedPriorities: Set<String>` storing `{'P0','P1',...}`
  - Load/Save via `JournalPageCubit` with per-tab keys (matches existing persistence split)

- Repository query
  - `JournalDb.getTasks(...)` signature extended to accept `priorities` list; plumb through `_selectTasks` to Drift query params
  - If empty selection, treat as all four values (avoid empty IN())

- Ordering
  - Default task list sort becomes: priority (P0→P3), then due date (ASC when present), then `date_from DESC`
  - For SQL simplicity, either: store `task_priority_rank INT` (0..3) or map `P0..P3` to rank in Dart and sort secondary fields in Dart once page is fetched. Preferred: `INT` for stable cross-platform ordering and paging.

## i18n

- `lib/l10n/app_en.arb` add keys:
  - `tasksPriorityTitle`: "Priority"
  - `tasksPriorityP0`: "Urgent"
  - `tasksPriorityP1`: "High"
  - `tasksPriorityP2`: "Medium"
  - `tasksPriorityP3`: "Low"
  - `tasksPriorityPickerTitle`: "Select priority"
  - `tasksPriorityFilterTitle`: "Priority"
  - Provide placeholders/translations mirrors for existing locales

## Testing Strategy

- Analyzer & formatting
  - Run `dart-mcp.analyze_files` and `dart-mcp.dart_format` after changes; maintain zero warnings

- Unit tests
  - `TaskPriority` enum mapping (short/label/db string) and default behavior
  - Conversions: `toDbEntity`/`fromDbEntity` priority round-trip with/without legacy values

- Repository/DB tests
  - Migration to v29 creates column, backfills P2, and preserves existing rows
  - Filtering by each priority and multi-select combinations
  - Ordering by priority rank then due then `date_from`

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
  - Mitigate in Dart by substituting all values when selection is empty

- Paging + ordering consistency when sorting by derived priorities
  - Prefer storing an integer `task_priority_rank` and index it; if TEXT only, ensure stable ORDER BY mapping

- Visual clutter on small screens
  - Use short codes on cards; wrap chips; leverage tooltips/spell-outs in picker only

## Rollout & Telemetry

- Migration: bump schema version, add column, backfill P2, adjust index
- Feature flags: not required; safe incremental UI exposure
- CHANGELOG: add entry under “feat: tasks: priority field + filtering + ordering”
- QA checklist: verify header edit, card chip, filter combinations, ordering precedence, persistence across app restarts

## Open Questions

- Store `task_priority_rank INT (0..3)` in addition to `task_priority TEXT`?
  - Recommended yes for simpler ORDER BY/paging; index `(type, task_status, category, task_priority_rank, date_from)`

- Allow “No priority” state?
  - Recommended no (default to P2) to reduce filter complexity; revisit if user feedback demands

- Due date ordering precedence
  - Current proposal: secondary (ASC) after priority; confirm with UX during review

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
- Add `task_priority` (and optionally `task_priority_rank`) to Drift schema and migration v29; update conversions

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

