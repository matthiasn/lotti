# Category Filter Persistence Split Plan

## Summary

- Persist task and journal category selections independently so each tab restores its own state
  after restart while task statuses remain scoped to tasks.
- Follow AGENTS.md expectations: rely on MCP commands, keep analyzer/tests green, update relevant
  READMEs and CHANGELOG, avoid generated files in riverpod when writing new controllers.

## Goals

- Introduce dedicated settings keys (e.g. `tasksCategoryFiltersKey`, `journalCategoryFiltersKey`)
  and helper logic in `JournalPageCubit` so each tab loads/saves its own category filter.
- Preserve the existing task-status persistence for the tasks tab and ensure the journal tab never
  overwrites task status selections.
- Cover the per-tab persistence behaviour with bloc tests and keep analyzer/test runs clean via
  `dart-mcp`.

## Non-Goals

- Modifying the `TaskCategoryFilter` UI beyond wiring it to the split persistence.
- Reworking category caching/sorting or adding new filter presets.
- Changing other journal filter settings such as entry types, tags, or private toggles.

## Current Findings

- Both the tasks and journal tabs read/write the shared `TASK_FILTERS` key inside
  `JournalPageCubit` (`lib/blocs/journal/journal_page_cubit.dart`), so the last active tab wins on
  restart.
- `TasksFilter` still bundles category IDs with task statuses, so legacy JSON must be handled when
  introducing new keys.
- Existing bloc/widget tests mock categories but do not verify which settings key is touched,
  leaving the regression undetected in CI.

## Design Overview

1. **Key Strategy** — Add two new constants plus a helper returning the appropriate key based on
   `showTasks`; keep a fallback to the legacy `TASK_FILTERS` value for first-run migration.
2. **Persistence Flow** — On load, attempt to deserialize from the per-tab key and fall back to the
   legacy entry; on save, write to the per-tab key (optionally mirroring to the legacy key during
   rollout) while preventing the journal tab from touching task statuses.
3. **Documentation** — Update the relevant feature READMEs and `CHANGELOG.md` to describe the
   independent persistence behaviour and QA expectations.

## Implementation Phases

### Phase 1 – Wiring & Migration

- Add the new key constants and helper method in `JournalPageCubit`.
- Update initialization to read the per-tab key first, then fall back to `TASK_FILTERS`.
- Temporarily mirror writes to both the new key and the legacy key to avoid data loss during
  adoption.

### Phase 2 – Persistence & Tests

- Route all save operations through the helper, and stop updating the legacy key once the new keys
  are populated.
- Add bloc tests in `test/blocs/journal/journal_page_cubit_test.dart` that mock `SettingsDb` to
  verify per-tab read/write behaviour and legacy fallback.
- Assert that journal-side persistence never mutates task statuses.

### Phase 3 – Docs & Cleanup

- Update `lib/features/journal/README.md`, `lib/features/tasks/README.md` (or other feature docs
  touched), and `CHANGELOG.md` to reflect the new persistence.
- Run `dart-mcp.analyze_files` and focused `dart-mcp.run_tests` (bloc suite first, then full run)
  before final verification.

## Testing Strategy

- `dart-mcp.analyze_files` after code changes to maintain the zero-warning policy.
- Targeted `dart-mcp.run_tests` for `test/blocs/journal/journal_page_cubit_test.dart` exercising the
  new persistence logic.
- Full test run via `dart-mcp.run_tests` once targeted suites pass to guard against regressions.

## Risks & Mitigations

- **Legacy data ignored** — Mitigated by the fallback to `TASK_FILTERS` and optional one-time mirror
  writes; consider pruning the old key in a follow-up once adoption is confirmed.
- **Task status corruption** — Guard journal saves while tests assert task statuses remain
  untouched.
- **Documentation drift** — Include README and CHANGELOG updates in Phase 3 to keep collateral
  aligned.

## Rollout & Monitoring

- Land behind green analyzer/test runs; no schema migration needed.
- During QA confirm each tab restores its own categories after restart and that toggling one tab
  does not affect the other.
- After release, verify both new keys exist in settings storage and plan a follow-up to retire the
  legacy key once the change is stable.
