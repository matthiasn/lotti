# Test Quality Improvements Plan

**Date**: 2026-03-27
**Status**: In Progress

## Overview

Comprehensive test quality review identified five areas of improvement across the 982-file
test suite. This plan addresses all five in priority order.

---

## Task 1: Extract Shared Task Filter Test Infrastructure

**Priority**: HIGH — eliminates ~500 lines of duplication across 13 files
**Status**: In Progress

### Problem

The `test/features/tasks/ui/filtering/` directory contains 13 test files with massive
duplication:

- `MockPagingController` defined identically in 8 files (due_date, distance, cover_art,
  date, status, category, sort, filter_icon)
- `FakeJournalPageController` subclass defined inline in 11 files, each with slightly
  different method subsets — despite a shared version already existing at
  `test/test_utils/fake_journal_page_controller.dart`
- `SystemChannels.platform` mock handler copy-pasted in 8 setUp() blocks
- `WidgetTestBench` + `ProviderScope` wrapping duplicated in 8 `buildSubject()` functions
- `_MockEntitiesCacheService` defined inline in `task_label_filter_test.dart` and
  `task_label_quick_filter_test.dart` despite existing in `test/mocks/mocks.dart`

### Plan

1. Move `MockPagingController` to `test/mocks/mocks.dart`
2. Add missing method overrides to the existing shared `FakeJournalPageController` at
   `test/test_utils/fake_journal_page_controller.dart`:
   - `setShowDueDate`, `setShowDistances`, `setShowCoverArt`
   - `selectSingleTaskStatus`
   - `setAgentAssignmentFilter`
3. Refactor all 13 test files to:
   - Import `MockPagingController` from `test/mocks/mocks.dart`
   - Import `FakeJournalPageController` from `test/test_utils/fake_journal_page_controller.dart`
   - Import `MockEntitiesCacheService` from `test/mocks/mocks.dart` (label tests)
   - Remove inline class definitions

### Files Changed

- `test/mocks/mocks.dart` — add MockPagingController
- `test/test_utils/fake_journal_page_controller.dart` — add missing overrides
- All 13 files in `test/features/tasks/ui/filtering/`

---

## Task 2: Move Inline Mock Classes to mocks.dart

**Priority**: HIGH — prevents drift and inconsistency
**Status**: Pending

### Problem

Several test files define mock classes that already exist in or belong in the central
`test/mocks/mocks.dart` file:

- `_MockEntitiesCacheService` in label filter tests (already exists in mocks.dart)
- `MockPagingController` in 8+ task filter tests (not in mocks.dart)
- Duplicate mock definitions in AI config repository tests

### Plan

1. Add `MockPagingController` to `test/mocks/mocks.dart`
2. Search for any remaining inline `Mock*` or `Fake*` classes that duplicate central ones
3. Replace inline definitions with imports from the central file

### Files to scan

```
grep -r "class Mock.*extends Mock" test/ --include="*_test.dart"
```

---

## Task 3: Replace DateTime.now() with Deterministic Dates

**Priority**: HIGH — 1,401 occurrences risk flaky tests
**Status**: Pending

### Problem

1,401 uses of `DateTime.now()` across test files make tests non-deterministic, violating
the project's own testing guidelines (see CLAUDE.md: "Do not use DateTime.now() in tests,
use specific dates").

### Worst offenders (by count)

| File | Count |
|------|-------|
| `test/database/editor_db_test.dart` | 26 |
| `test/services/logging_service_test.dart` | 13+ |
| `test/widgets/misc/map_widget_test.dart` | 10 |
| `test/widgets/date_time/datetime_field_test.dart` | 5 |
| `test/services/ip_geolocation_service_test.dart` | multiple |
| `test/database/open_db_connection_test.dart` | 2 |
| `test/database/database_test.dart` | 2 |

### Strategy

Replace `DateTime.now()` with deterministic dates. Common replacements:

```dart
// Before
final now = DateTime.now();

// After — use a fixed, readable date
final testDate = DateTime(2024, 3, 15, 10, 30);
```

Where tests need distinct timestamps (e.g., "created before" / "created after"), use
incrementing fixed dates:

```dart
final earlier = DateTime(2024, 3, 15, 10, 0);
final later = DateTime(2024, 3, 15, 11, 0);
```

### Execution order

Work file by file starting with the highest-count files. Run tests after each file to
verify no regressions.

---

## Task 4: Strengthen Weak Assertions in Design System Tests

**Priority**: MEDIUM — tests exist but provide little value
**Status**: Pending

### Problem

Many widget tests only assert `findsOneWidget` or `isNotNull` without verifying actual
content, styling, or behavior.

### Key files

- `test/features/design_system/components/dividers/` — only checks widget exists
- `test/features/design_system/components/scrollbars/` — only checks descendant exists
- `test/features/design_system/components/headers/` — only checks slots render
- `test/features/design_system/components/search/` — only checks text/icon existence
- `test/features/design_system/components/spinners/` — only checks no exception thrown
- `test/features/design_system/components/captions/` — only checks border isNotNull
- `test/features/design_system/widgetbook/` — badge and button tests

### Improvement strategy

For each test, add at least one of:
- **Property verification**: Check actual values (fontSize, color, dimensions)
- **Interaction testing**: Verify callbacks fire on tap/gesture
- **State verification**: Check widget state changes on input changes
- **Content verification**: Check actual text content, not just existence

### Example improvement

```dart
// Before (weak)
expect(find.byType(Divider), findsOneWidget);

// After (meaningful)
final divider = tester.widget<Divider>(find.byType(Divider));
expect(divider.thickness, 1.0);
expect(divider.color, equals(Theme.of(context).dividerColor));
```

---

## Task 5: Add Tests for Critical Untested Business Logic

**Priority**: MEDIUM-HIGH — critical code paths with zero coverage
**Status**: Pending

### Problem

Several important business logic files have no corresponding test files. These are
controllers, services, and repositories — not just simple widgets.

### Priority targets (by criticality)

| Source file | Category | Why critical |
|-------------|----------|-------------|
| `lib/features/sync/matrix/pipeline/matrix_stream_processor.dart` | Sync infra | Core stream processing |
| `lib/features/sync/matrix/matrix_service.dart` | Sync infra | Core sync service |
| `lib/features/labels/services/label_assignment_processor.dart` | Labels | Label processing logic |
| `lib/features/ai/repository/transcription_repository.dart` | AI | Transcription service |
| `lib/features/daily_os/state/time_budget_progress_controller.dart` | Daily OS | Time budget state |
| `lib/features/habits/state/habit_completion_controller.dart` | Habits | Habit completion state |
| `lib/features/tasks/state/tasks_count_controller.dart` | Tasks | Task count state |
| `lib/features/journal/state/save_button_controller.dart` | Journal | Save button state |
| `lib/features/sync/gateway/matrix_sync_gateway.dart` | Sync | Sync gateway |
| `lib/features/ai/functions/function_handler.dart` | AI | AI function dispatch |

### Strategy

For each file:
1. Read the source to understand the API surface and dependencies
2. Create a test file at the mirrored test path
3. Write tests covering:
   - Happy path behavior
   - Error handling / edge cases
   - State transitions (for controllers)
   - Integration with mocked dependencies

### Execution order

Start with Riverpod state controllers (simpler to test) before tackling sync infrastructure
(complex dependencies).

---

## Additional Issues Found

### pumpAndSettle misuse (LOW)

- 2,976 total `pumpAndSettle()` calls — many could use targeted `pump(duration)`
- 2 instances with `Duration(seconds: 2)` in `analog_vu_meter_test.dart:229,269`

### Coverage summary by feature

| Feature | Source | Tests | Coverage |
|---------|--------|-------|----------|
| surveys | 6 | 1 | 16.7% |
| user_activity | 2 | 1 | 50.0% |
| dashboards | 31 | 18 | 58.1% |
| settings | 34 | 21 | 61.8% |
| whats_new | 8 | 5 | 62.5% |
| habits | 15 | 10 | 66.7% |
| daily_os | 32 | 26 | 81.3% |
| speech | 24 | 20 | 83.3% |
| ai | 157 | 155 | 98.7% |
