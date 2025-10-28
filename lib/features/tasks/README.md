# Tasks Feature

This feature powers task creation, editing, filtering and list/grid rendering.

## Priority (P0–P3)

- Short codes: `P0` (Urgent), `P1` (High), `P2` (Medium), `P3` (Low)
- UI
  - Task Details: header shows a “Priority:” label with a chip; tapping opens the picker
  - List Cards: priority chip shown alongside status
  - Filtering: priorities appear in the Tasks filter modal alongside status/labels/categories
- Persistence
  - Per‑tab storage via `TASKS_CATEGORY_FILTERS` (tasks tab) and `JOURNAL_CATEGORY_FILTERS` (journal tab)
  - Only the tasks tab persists `selectedTaskStatuses`, `selectedLabelIds`, and `selectedPriorities`
- Database
  - Dual columns on `journal` for performance and readability:
    - `task_priority` (TEXT: `P0`–`P3`)
    - `task_priority_rank` (INTEGER: 0–3)
  - Ordering: `task_priority_rank` ASC, then `date_from`
  - Migration v29 backfills legacy tasks to `P2` with rank `2` and rebuilds `idx_journal_tasks`

## Developer Notes

- Model helpers live in `lib/classes/task.dart` (enum, rank/short/color mapping)
- Filter state lives in `JournalPageCubit`/`JournalPageState`; TasksFilter JSON is used for persistence
- Do not modify generated code; run `make build_runner` when model changes are made

