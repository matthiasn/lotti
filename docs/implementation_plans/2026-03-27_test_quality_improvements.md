# Test Quality Improvements

**Date**: 2026-03-27
**Status**: Complete

## Overview

Comprehensive test quality review identified five areas of improvement across the 982-file
test suite. All five were addressed. Additionally, 3 pre-existing test failures were fixed
and 104 new tests were added for previously untested business logic.

---

## Task 1: Extract Shared Task Filter Test Infrastructure

**Priority**: HIGH
**Status**: Complete

### Problem

The `test/features/tasks/ui/filtering/` directory contained 13 test files with massive
duplication:

- `MockPagingController` defined identically in 8 files
- `FakeJournalPageController` defined inline in 11 files despite a shared version existing
- `SystemChannels.platform` mock handler copy-pasted in 8 setUp() blocks
- `_MockEntitiesCacheService` defined inline despite existing in `test/mocks/mocks.dart`

### What was done

1. Moved `MockPagingController` to `test/mocks/mocks.dart`
2. Extended the shared `FakeJournalPageController` at
   `test/test_utils/fake_journal_page_controller.dart` with all missing method overrides:
   `setShowDueDate`, `setShowDistances`, `setShowCoverArt`, `setShowProjectsHeader`,
   `selectSingleTaskStatus`, `setAgentAssignmentFilter`, `toggleProjectFilter`,
   `clearProjectFilter`
3. Refactored all 13 test files to use the shared controller and central mocks
4. Removed all inline `FakeJournalPageController`, `MockPagingController`, and
   `_MockEntitiesCacheService` definitions

### Result

- ~500 lines of duplicated boilerplate eliminated
- All 78 tests pass
- Analyzer clean, formatting clean

### Files changed

- `test/mocks/mocks.dart`
- `test/test_utils/fake_journal_page_controller.dart`
- All 13 files in `test/features/tasks/ui/filtering/`

---

## Task 2: Move Inline Mock Classes to mocks.dart

**Priority**: HIGH
**Status**: Complete (merged with Task 1)

`MockPagingController` and `_MockEntitiesCacheService` were moved as part of the Task 1
refactoring. No additional inline mocks were found that needed centralization.

---

## Task 3: Replace DateTime.now() with Deterministic Dates

**Priority**: HIGH
**Status**: Complete

### Problem

845 uses of `DateTime.now()` across 75+ test files made tests non-deterministic, violating
the project's testing guidelines.

### What was done

Replaced `DateTime.now()` with fixed dates (`DateTime(2024, 3, 15, 10, 30)` and similar)
across all test files. Work was parallelized across 14 batch agents.

### Result

- **845 → 41 remaining** (95.1% reduction)
- The 41 remaining are all intentional keeps:
  - Production code calling `DateTime.now()` internally (widgets checking `isRecent`,
    controllers computing "today", countdown timers)
  - Comments referencing `DateTime.now()` (not actual calls)
  - Tests verifying production code's real-time behavior (e.g., soft-delete timestamps)
- Each remaining instance has an `// ignore: avoid_DateTime_now` comment explaining why

### Bonus: Fixed 3 pre-existing broken tests

`test/features/sync/backfill/backfill_response_handler_test.dart` had 3 tests that were
failing before our changes. Root cause: `fakeAsync` breaks `SharedPreferences.getInstance()`
(platform channel), so the handler's `await isBackfillEnabled()` would hang, preventing
cooldown/rate-limit logic from executing.

**Fix**: Replaced `fakeAsync` with regular `async` tests using real-time relative timestamps.
The cooldown and rate-limit checks work correctly with real `DateTime.now()` since the cache
entries just need correct relative timing.

### Key patterns for intentional DateTime.now() keeps

| Pattern | Example | Why it must use real time |
|---------|---------|-------------------------|
| Widget `isRecent` check | `duration_widget_test.dart` | Widget calls `DateTime.now()` internally to determine if entry is < 12h old |
| Controller "today" logic | `habits_controller_test.dart` | Controller maps completions by `DateTime.now().ymd` |
| Countdown timers | `correction_capture_service_test.dart` | `remainingTime` getter calls `DateTime.now()` |
| Soft-delete verification | `categories_repository_test.dart` | Asserts `deletedAt` is close to real current time |

---

## Task 4: Strengthen Weak Assertions in Design System Tests

**Priority**: MEDIUM
**Status**: Complete (no changes needed)

### Finding

Upon detailed manual review, the design system tests were already well-written with
meaningful assertions. The initial automated scan overstated the weakness by flagging
`findsOneWidget` calls that were part of larger test bodies with proper property/value
assertions.

Examples of existing good assertions found:
- **Dividers**: Check line count, fontSize, color, dimensions
- **Scrollbars**: Check thickness, radius, thumbColor, thumbVisibility
- **Headers**: Check title styling (fontSize, fontWeight, color), desktop height
- **Search**: Check sizes, icon positions, text styles, callbacks, clear behavior
- **Text inputs**: Check labels, helpers, errors, icons, callbacks, opacity, border colors
- **Captions**: Check text, icon size/color, action callbacks, card styling, truncation

---

## Task 5: Add Tests for Critical Untested Business Logic

**Priority**: MEDIUM-HIGH
**Status**: Complete

### New test files created

| Test file | Tests | Source file | Coverage |
|-----------|-------|------------|----------|
| `tasks_count_controller_test.dart` | 3 | `tasks_count_controller.dart` | Initial DB count, stream update with relevant ID, ignoring irrelevant notifications |
| `time_budget_progress_controller_test.dart` | 46 | `time_budget_progress_controller.dart` | All data class computed properties: `progressFraction`, `remainingDuration`, `isOverBudget` for both `TimeBudgetProgress` and `DayBudgetStats`, plus edge cases (zero planned, zero recorded, over-budget, sub-minute, both-zero) |
| `save_button_controller_test.dart` | 5 | `save_button_controller.dart` | dirty→true, saved→false, null when unloaded, save delegation, estimate forwarding |
| `transcription_repository_test.dart` | 11 | `transcription_repository.dart` | Success path, HTTP errors (with JSON/non-JSON bodies), missing text field, TimeoutException→408, FormatException, generic errors, default/custom timeout |
| `openai_transcription_repository_test.dart` | 17 | `openai_transcription_repository.dart` | Model detection (6 cases), argument validation (3 cases), multipart request construction, prompt inclusion/exclusion, HTTP error handling |
| `function_handler_test.dart` | 18 | `function_handler.dart` | FunctionCallResult data class (4), handler contract via concrete impl (14): parse, duplicate detection, description, tool response, retry prompt |
| `inference_repository_interface_test.dart` | 4 | `inference_repository_interface.dart` | `generateText` message building with/without system message, parameter passthrough, stream return |
| **Total** | **104** | | |

### Not addressed (deferred)

The following were evaluated but deferred due to extensive existing indirect coverage:

- **MatrixStreamProcessor**: 500+ line class with 12+ injected dependencies. Already covered
  indirectly by 19 test files in `test/features/sync/matrix/pipeline/` (consumer tests,
  signal tests, catch-up tests, metrics tests, retry/circuit tests).
- **MatrixService**: High-level orchestrator already covered by 3 focused test files
  (`_connectivity_test`, `_pipeline_test`, `_change_password_test`).
- **MatrixSyncGateway**: Abstract interface — concrete implementation already tested in
  `matrix_sdk_gateway_test.dart`.

---

## Summary of Impact

| Metric | Before | After |
|--------|--------|-------|
| DateTime.now() in tests | 845 | 41 (intentional) |
| Duplicated mock classes | 8+ inline definitions | 0 (all centralized) |
| Duplicated FakeController variants | 11 inline definitions | 0 (shared version) |
| Untested AI repo/interface files | 4 | 0 |
| Untested controller files | 3 | 0 |
| New tests added | — | 104 |
| Pre-existing broken tests fixed | 3 | 0 |
| Test files refactored (DRY) | — | 13 |
| Total test files touched | — | ~90 |
