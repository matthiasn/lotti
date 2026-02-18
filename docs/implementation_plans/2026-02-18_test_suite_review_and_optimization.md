# Test Suite Review and Optimization Plan

**Date:** 2026-02-18
**Status:** Phase 1 Complete — Ready for Phase 2
**Scope:** 774 test files, 332K lines of test code

---

## Progress Log

### Phase 0: Update AGENTS.md — DONE
- Added three subsections to `AGENTS.md` under Testing Guidelines:
  - **Test Infrastructure Rules** — centralized mocks, fallbacks, GetIt helpers, widget helpers, test data factories, 1:1 file mapping
  - **Test Quality Rules** — meaningful assertions, no copy-paste permutations, no constructor smoke tests, balanced mock-to-test ratio
  - **Async & Performance Rules** — no real waits, prefer `pump` over `pumpAndSettle`, use `fakeAsync`, deterministic dates
- Strengthened Implementation Discipline cross-reference

### Phase 1a: Delete empty/orphaned files — DONE
- Deleted `test/themes/themes_service_test.dart` (empty — group with setup but zero test cases)
- Deleted `test/utils/wait.dart` (unused `Future.delayed` utility, confirmed no callers)
- **Not deleted** (reclassified as consolidation candidates for Phase 3):
  - `test/features/ai/model/prompt_tracking_test.dart` — has real tests, but `prompt_form_state_test.dart` already exists
  - `test/features/ai/state/settings/prompt_tracking_test.dart` — has real tests, but `prompt_form_controller_tracking_test.dart` already exists

### Phase 1b: Fix explicit long timeouts — DONE
- `test/.../tags_modal_widget_test.dart:236` — removed 5s explicit timeout → default `pumpAndSettle()`
- `test/.../habits_tab_page_test.dart` — removed 4x 2s explicit timeouts → default `pumpAndSettle()`
- `test/.../analog_vu_meter_test.dart` — removed 2x 2s explicit timeouts → default `pumpAndSettle()`
- `test/.../unified_ai_popup_menu_test.dart:679` — kept 5ms `Future.delayed` (intentional async race-condition test, negligible perf impact)
- All 22 affected tests pass

### Phase 1c: Delete duplicate test files — DONE
- **Merged then deleted:** `test/sync/client_runner_test.dart` (1 unique test merged into `test/features/sync/client_runner_test.dart`, which now has all 3 tests passing)
- **Deleted:** `test/features/sync/matrix/ui/metrics_section_test.dart` (subset of comprehensive test at correct location; only unique test was a low-value `findsOneWidget` check for `dbEntryLinkNoop`)
- Removed empty directories: `test/sync/`, `test/features/sync/matrix/ui/`
- **Deferred to Phase 3** (non-overlapping tests, need proper merge):
  - `test/features/settings/ui/advanced/maintenance_page_test.dart` (87 lines, tests hint reset)
  - `test/features/settings/ui/pages/maintenance_page_test.dart` (230 lines, tests DB deletion)

### Verification
- Analyzer: zero issues
- Formatter: zero changes needed in lib/ and test/
- All affected tests pass (22 timeout tests + 3 merged client_runner tests)

---

## Executive Summary

A full sweep of the test suite reveals systemic issues across four dimensions: massive
duplication in test infrastructure (~874 duplicate mock definitions), timeout/async
mishandling (3,400+ `pumpAndSettle` calls with default 10s timeouts), low-value
assertions (~200+ tests that verify nothing meaningful), and file organization violations
(~10 source files with multiple test files, legacy directories). Addressing these issues
will shrink the codebase, speed up execution, and raise test quality.

---

## 1. Duplication & Test Benches

### Findings

The test suite has **severe mock class duplication**. A centralized `test/mocks/mocks.dart`
exists with ~30 mock definitions, but it is massively underutilized:

| Duplicated Mock Class           | Inline Definitions | Should Be Centralized |
|---------------------------------|-------------------:|:---------------------:|
| `MockLoggingService`            |                118 | Yes                   |
| `MockJournalDb`                 |                 90 | Yes                   |
| `MockAiConfigRepository`        |                 40 | Yes                   |
| `MockUpdateNotifications`       |                 39 | Yes                   |
| `MockJournalRepository`         |                 37 | Yes                   |
| `MockEntitiesCacheService`      |                 32 | Yes                   |
| `MockPersistenceLogic`          |                 30 | Yes                   |
| `MockChecklistRepository`       |                 27 | Yes                   |
| `MockCategoryRepository`        |                 18 | Yes                   |
| **Total duplicate definitions** |            **874** |                       |

### Other Duplication Patterns

| Pattern                                    | Occurrences | Notes                                                        |
|--------------------------------------------|------------:|--------------------------------------------------------------|
| GetIt register/unregister boilerplate       |       ~235  | `isRegistered` + `unregister` + `registerSingleton` repeated in 100+ files. Helper `setUpTestGetIt()` exists in `widget_test_utils.dart` but only 8 files use it. |
| `StreamController<Set<String>>` setup       |         63  | Same broadcast controller + mock wiring for `UpdateNotifications` |
| `ProviderContainer` construction            |         47  | Identical override patterns across Riverpod tests             |
| `registerFallbackValue` calls               |        560  | Central `test/helpers/fallbacks.dart` has only 4 values       |
| `when(...).thenAnswer(...)` mock stubs      |     1,388+  | Same DB/service stubs repeated across 100+ files              |
| `TestWidgetsFlutterBinding.ensureInitialized` |       240  | Could be in `flutter_test_config.dart` globally               |

### Existing Infrastructure (Underutilized)

| File                                          | Purpose                  | Usage     |
|-----------------------------------------------|--------------------------|-----------|
| `test/mocks/mocks.dart`                       | Centralized mocks        | Low       |
| `test/widget_test_utils.dart`                 | Widget test helpers      | 833 calls of `makeTestableWidget` but 4 confusing variants exist |
| `test/helpers/fallbacks.dart`                 | Fallback values          | Only 4 values vs 560+ inline calls |
| `test/features/categories/test_utils.dart`    | Category test factory    | Feature-local only |
| `test/features/ai/test_utils.dart`            | AI test data factory     | Feature-local only |
| `test/test_helper.dart`                       | 4 overlapping TestBench classes | Confusing; should be 1-2 parameterized classes |

### Top 10 Worst Offenders (Setup Duplication)

1. `test/features/sync/actor/sync_actor_test.dart` - 9 inline mock classes
2. `test/features/journal/state/entry_controller_test.dart` - 8+ inline mocks
3. `test/features/daily_os/state/unified_daily_os_data_controller_test.dart` - 8 inline mocks
4. `test/features/sync/matrix/matrix_service_pipeline_test.dart` - heavy mock setup
5. `test/features/ai/repository/ai_input_repository_test.dart` - custom `TestContainerBuilder` not reused
6. `test/features/labels/repository/labels_repository_test.dart` - 5 mocks + GetIt boilerplate
7. `test/features/categories/repository/categories_repository_test.dart` - 4 mocks + GetIt boilerplate
8. `test/features/theming/state/theming_controller_test.dart` - complex mock + GetIt setup
9. `test/features/ratings/repository/rating_repository_test.dart` - 6 mocks + async GetIt
10. `test/features/habits/repository/habits_repository_test.dart` - standard repository duplication

---

## 2. Timeouts & Async Handling

### Findings

| Category                              | Count   | Severity | Impact               |
|---------------------------------------|--------:|----------|----------------------|
| `pumpAndSettle()` calls (total)       |  3,400+ | Variable | Default 10s timeout each |
| Files using `pumpAndSettle`           |    291  | HIGH     | Potential timeout hangs  |
| Explicit long timeouts (2-5s)         |      6  | CRITICAL | 17+ seconds wasted       |
| `Future.delayed` in test code         |      2  | CRITICAL | Real time waits          |
| Files using `fakeAsync`               |     48  | --       | Only 6.2% adoption       |

### Critical Violations (Real Time Waits)

| File | Line | Issue |
|------|-----:|-------|
| `test/features/ai/ui/unified_ai_popup_menu_test.dart` | 679 | `Future.delayed(Duration(milliseconds: 5))` in mock provider setup |
| `test/utils/wait.dart` | 2 | `waitMilliseconds()` utility uses real `Future.delayed` (appears unused) |

### Excessive Explicit Timeouts

| File | Line(s) | Duration | Wasted Time |
|------|---------|----------|-------------|
| `test/features/journal/ui/widgets/tags/tags_modal_widget_test.dart` | 236 | **5 seconds** | 5s per run |
| `test/features/habits/ui/pages/habits_tab_page_test.dart` | 133, 144, 150, 157 | **2 seconds** x4 | 8s per run |
| `test/features/speech/ui/widgets/recording/analog_vu_meter_test.dart` | 84, 107 | **2 seconds** x2 | 4s per run |

### Top 15 Files by `pumpAndSettle` Count (Biggest Slowdown Risk)

| Rank | File | Count | Lines |
|-----:|------|------:|------:|
| 1 | `features/ai/ui/settings/inference_provider_edit_page_test.dart` | 140 | 1,681 |
| 2 | `features/ai/ui/settings/ai_settings_page_test.dart` | 83 | 907 |
| 3 | `features/daily_os/ui/widgets/time_budget_card_test.dart` | 72 | 2,132 |
| 4 | `features/labels/ui/widgets/label_selection_modal_content_test.dart` | 62 | -- |
| 5 | `features/daily_os/ui/widgets/daily_timeline_test.dart` | 50 | -- |
| 6 | `features/tasks/ui/task_labels_wrapper_test.dart` | 47 | -- |
| 7 | `features/labels/ui/widgets/modern_labels_item_test.dart` | 47 | -- |
| 8 | `features/ai/ui/settings/provider_prompt_setup_service_test.dart` | 47 | -- |
| 9 | `features/ai/ui/settings/prompt_edit_page_test.dart` | 47 | -- |
| 10 | `widgets/modal/modern_action_items_test.dart` | 44 | -- |
| 11 | `features/categories/ui/pages/category_details_page_test.dart` | 43 | -- |
| 12 | `features/ai/ui/unified_ai_popup_menu_test.dart` | 43 | -- |
| 13 | `widgets/modal/modern_create_entry_items_test.dart` | 39 | -- |
| 14 | `features/sync/ui/backfill_settings_page_test.dart` | 38 | -- |
| 15 | `features/categories/ui/pages/categories_list_page_test.dart` | 33 | -- |

### fakeAsync Adoption Gap

Only **48 of 774 files (6.2%)** use `fakeAsync`, despite excellent infrastructure
(`retry_fake_time.dart`, `pump_retry_time.dart`, `fake_time.dart`). The `test/README.md`
mandates fake time but compliance is low for service/controller tests.

---

## 3. Test Quality & Assertions

### Findings by Severity

| Category                         | Est. Count | % of Suite |
|----------------------------------|--------:|----------:|
| **Garbage** (delete-worthy)      |   50-60 |     6-8%  |
| **Low-value** (needs rewriting)  | 150-200 |    7-10%  |
| **Acceptable/good**              |    500+ |   65-70%  |
| **Adequate but improvable**      |    150+ |   10-15%  |

### Garbage Tests (Delete or Rewrite Immediately)

| File | Issue |
|------|-------|
| `test/themes/themes_service_test.dart` | **Empty**: group definition with setup/teardown but zero test cases |
| `test/features/settings/ui/widgets/measurable_type_card_test.dart` | 9 copy-paste tests; same widget with trivial flag permutations |
| `test/features/journal/ui/widgets/entry_details/survey_summary_test.dart` | Single assertion: `find.text('CFQ11:')` with `findsOneWidget` |
| `test/features/journal/ui/widgets/entry_details/measurement_summary_test.dart` | Single assertion: checks if text `'Coverage: 55 %'` appears |
| `test/features/sync/ui/matrix_stats/metrics_grid_test.dart` | Only checks text labels exist; no value/logic verification |
| `test/features/journal/ui/widgets/entry_details/duration_widget_timer_text_test.dart` | Tests internal implementation detail (text width stability) |
| `test/features/ai/functions/checklist_completion_functions_test.dart` | Only schema validation, no behavior testing |

### Low-Value Patterns (Systemic)

| Anti-Pattern | Occurrences | Example |
|--------------|------------:|---------|
| Only `findsOneWidget` / `findsNothing` checks | ~352 files | `metrics_grid_test.dart`, `ai_chat_icon_test.dart` |
| Constructor smoke tests ("should create") | ~50 tests | Check existence only, no behavior |
| Copy-paste test permutations | ~40 tests | `measurable_type_card_test.dart` (9 identical tests) |
| Widget rendering without interaction | ~150 tests | Pump widget, find it, done |
| Mock setup >> test logic | ~40 files | 100+ lines setup, 5 lines test |

### Top 10 Worst Quality Files

1. `test/themes/themes_service_test.dart` - empty
2. `test/features/settings/ui/widgets/measurable_type_card_test.dart` - 9 copy-paste tests
3. `test/features/journal/ui/widgets/entry_details/survey_summary_test.dart` - single rendering check
4. `test/features/sync/ui/matrix_stats/metrics_grid_test.dart` - only text finding
5. `test/features/journal/ui/widgets/entry_details/measurement_summary_test.dart` - single assertion
6. `test/features/ai/model/inference_error_test.dart` - enum existence checks
7. `test/features/journal/ui/widgets/entry_details/duration_widget_timer_text_test.dart` - implementation detail
8. `test/features/sync/ui/matrix_stats/metrics_actions_test.dart` - only text label checks
9. `test/utils/modals_test.dart` - type checks with `isA` instead of behavior
10. `test/features/habits/ui/widgets/habit_completion_color_icon_test.dart` - widget predicate only

---

## 4. File Organization (Consolidation)

### Multiple Test Files for Single Source File

| Source File | Test Files | Action |
|-------------|------------|--------|
| `lib/features/settings/ui/pages/advanced/maintenance_page.dart` | `test/.../advanced/maintenance_page_test.dart` + `test/.../pages/maintenance_page_test.dart` | Delete duplicate, keep one in correct location |
| `lib/features/settings/ui/pages/advanced/logging_page.dart` | `test/.../pages/logging_page_test.dart` + `test/widgets/logging_page_test.dart` | Consolidate into `test/.../pages/advanced/logging_page_test.dart` |
| `lib/features/ai/ui/settings/services/ai_config_delete_service.dart` | `..._test.dart` + `..._simple_test.dart` | Merge `_simple` into main test file |
| `lib/logic/habits/autocomplete_update.dart` | `test/logic/habits/...` + `test/blocs/habits/...` | Delete legacy `blocs/` copy |
| `lib/features/ai/ui/settings/form_bottom_bar.dart` | `test/features/ai/.../form_bottom_bar_test.dart` + `test/widgets/ui/form_bottom_bar_test.dart` | Consolidate to feature location |
| `lib/get_it.dart` | `test/get_it_test.dart` + `test/services/get_it_test.dart` | Consolidate |
| `lib/features/sync/client_runner.dart` | `test/features/sync/client_runner_test.dart` + `test/sync/client_runner_test.dart` | Delete misplaced copy |
| `lib/features/sync/ui/matrix_stats/metrics_section.dart` | 2 test files in different directories | Delete misplaced copy |

### Legacy/Orphaned Directories

| Directory | Issue | Action |
|-----------|-------|--------|
| `test/blocs/` | Source `lib/blocs/` no longer exists | Delete entire directory; merge any live tests to `test/logic/` |
| `test/sync/` | Source is `lib/features/sync/` | Move tests to `test/features/sync/` |

### Orphaned Test Files (No Source)

| File | Status |
|------|--------|
| `test/features/ai/model/prompt_tracking_test.dart` | No corresponding source file |
| `test/features/ai/state/settings/prompt_tracking_test.dart` | No corresponding source file |
| `test/utils/wait.dart` | Appears unused |

---

## Implementation Plan

### Phase 0: Update AGENTS.md Testing Guidance — DONE

**Goal:** Prevent regressions by codifying the lessons from this analysis into AI agent
instructions. Every future test written by an AI agent should follow these rules from the
start, so the debt doesn't grow back.

**What to add** — expand the existing `## Testing Guidelines` section in `AGENTS.md` with
the following rules (proposed wording below):

```markdown
## Testing Guidelines

[...existing content stays...]

### Test Infrastructure Rules

- **Use centralized mocks.** Import from `test/mocks/mocks.dart`. Never define a mock
  class inline in a test file if it already exists in the central file. If a new mock is
  needed, add it to `test/mocks/mocks.dart` first, then import it.
- **Use centralized fallback values.** Import from `test/helpers/fallbacks.dart` and call
  `registerFallbackValue(...)` with values defined there. If a new fallback is needed, add
  it to the central file.
- **Use `setUpTestGetIt()` / `tearDownTestGetIt()`.** Import from
  `test/widget_test_utils.dart`. Never write inline `getIt.isRegistered` /
  `getIt.unregister` / `getIt.registerSingleton` boilerplate. If additional services are
  needed beyond what the helper registers, extend the helper or register them after calling
  it.
- **Use `makeTestableWidget()` for widget tests.** Import from
  `test/widget_test_utils.dart`. Do not create ad-hoc `MaterialApp` / `ProviderScope` /
  `MediaQuery` wrappers. Use the `overrides` parameter for Riverpod overrides.
- **Use test data factories** where they exist (e.g.,
  `test/features/categories/test_utils.dart`,
  `test/features/ai/test_utils.dart`). When creating test entities for a feature that
  already has a factory, use it. When touching a new feature, consider creating one.
- **One test file per source file.** Test file paths must mirror source file paths
  (`lib/features/foo/bar.dart` → `test/features/foo/bar_test.dart`). Never split tests
  for one source file across multiple test files.

### Test Quality Rules

- **Every test must assert something meaningful.** `findsOneWidget` alone is not a valid
  test — it only proves the widget tree built without crashing. Always verify at least one
  of: displayed content/values, state changes after interaction, callback invocations, or
  error handling.
- **No copy-paste test permutations.** If you need to test the same widget with different
  flag combinations (e.g., `private: true/false`, `favorite: true/false`), use a loop or
  parameterized helper, not N nearly-identical test bodies.
- **No constructor smoke tests.** Tests that only instantiate an object and check
  `isNotNull` have zero value. Test behavior, not existence.
- **Mock setup must not dwarf test logic.** If a test has 100 lines of mock setup and 5
  lines of assertions, the test is either testing the wrong thing or needs a shared
  helper. Prefer extracting setup into `setUp()` or a helper function.

### Async & Performance Rules

- **Never use `Future.delayed()`, `sleep()`, or real `Timer` in tests.** See
  `test/README.md` for the fake time policy.
- **Prefer `tester.pump(duration)` over `tester.pumpAndSettle()`.** `pumpAndSettle` has a
  default 10-second timeout and will hang if animations never settle. Use it only when you
  genuinely need all animations to complete, and never pass a duration > 1 second.
- **Use `fakeAsync` for unit/service tests** that involve timers, delays, retries, or
  debounce. See `test/test_utils/retry_fake_time.dart` and
  `test/test_utils/pump_retry_time.dart` for helpers.
- **Use deterministic dates.** Never use `DateTime.now()` in tests. Use specific dates
  like `DateTime(2024, 3, 15)`.
```

Also update the `## Implementation discipline` section — the existing bullet "Write
meaningful tests that actually assert on valuable information" should be strengthened with
a cross-reference:

```markdown
- Write meaningful tests that actually assert on valuable information. Refrain from adding BS
  assertions such as finding a row or whatnot. Focus on useful information. See the
  "Test Quality Rules" and "Test Infrastructure Rules" sections above for specifics.
```

**Why Phase 0:** This must happen first so that all subsequent test work (Phases 1-4) and
all future AI-generated tests follow the new rules. It is zero-risk — it only changes
documentation, not code.

### Phase 1: Quick Wins — DONE

**Goal:** Remove dead weight and fix the most obvious violations.

1. **Delete empty/orphaned test files**
   - Delete `test/themes/themes_service_test.dart` (empty)
   - Delete `test/utils/wait.dart` (unused real-delay utility)
   - Investigate and likely delete `test/features/ai/model/prompt_tracking_test.dart`
   - Investigate and likely delete `test/features/ai/state/settings/prompt_tracking_test.dart`

2. **Fix explicit long timeouts**
   - `test/.../tags_modal_widget_test.dart:236`: 5s -> investigate why, reduce
   - `test/.../habits_tab_page_test.dart:133,144,150,157`: 2s x4 -> investigate, reduce
   - `test/.../analog_vu_meter_test.dart:84,107`: 2s x2 -> investigate, reduce
   - `test/.../unified_ai_popup_menu_test.dart:679`: Replace `Future.delayed` with immediate mock

3. **Delete duplicate test files** (keep the one in the correct location)
   - `test/features/settings/ui/pages/maintenance_page_test.dart` (duplicate of `advanced/` version)
   - `test/sync/client_runner_test.dart` (duplicate of `features/sync/` version)
   - `test/features/sync/matrix/ui/metrics_section_test.dart` (misplaced)

**Estimated effort:** 1-2 hours
**Estimated savings:** ~17 seconds per test run + reduced confusion

### Phase 2: Centralize Test Infrastructure (Medium Effort, High Impact)

**Goal:** Eliminate the bulk of duplication by expanding shared helpers.

4. **Expand `test/mocks/mocks.dart`**
   - Add all 30+ commonly duplicated mock classes (MockLoggingService, MockJournalDb, etc.)
   - Systematically replace inline definitions across 874+ occurrences
   - Start with the top 9 most-duplicated mocks (covers ~431 inline definitions)

5. **Expand `test/helpers/fallbacks.dart`**
   - Add commonly registered fallback values (currently only 4, need 20+)
   - Create a single `registerAllFallbackValues()` function
   - Replace 560+ inline `registerFallbackValue` calls

6. **Create `test/helpers/getit_test_helper.dart`**
   - Centralize the register/unregister boilerplate
   - Provide a `withTestGetIt({required List<Override> overrides})` helper
   - Replace boilerplate in 100+ files

7. **Create test data factories per feature**
   - Follow the `CategoryTestUtils` pattern from `test/features/categories/test_utils.dart`
   - Prioritize: `HabitDefinition`, `DashboardDefinition`, `JournalEntity`, `Metadata`
   - Place in `test/features/<feature>/test_utils.dart`

8. **Consolidate widget test helpers**
   - Reduce from 4 `makeTestableWidget*` variants to 1-2 with parameters
   - Consolidate 4 `WidgetTestBench` classes into 1 parameterized class

**Estimated effort:** 2-3 days
**Estimated savings:** ~5,000+ lines of duplicated code removed

### Phase 3: Test Quality Improvements (Ongoing)

**Goal:** Raise the floor on test value.

9. **Rewrite garbage tests**
   - Replace copy-paste permutations with parameterized tests (e.g., `measurable_type_card_test.dart`)
   - Add meaningful assertions to rendering-only tests (start with the top 10 worst files)
   - Convert smoke tests to behavioral tests where the source code has testable logic

10. **Consolidate split test files**
    - Merge `ai_config_delete_service_simple_test.dart` into main test
    - Merge `test/blocs/habits/autocomplete_update_test.dart` into `test/logic/habits/`
    - Merge `test/widgets/logging_page_test.dart` into feature test
    - Merge `test/widgets/ui/form_bottom_bar_test.dart` into feature test
    - Delete `test/blocs/` directory entirely

11. **Reduce `pumpAndSettle` usage in top 15 files**
    - Profile actual execution to find which calls hit the 10s timeout
    - Replace with specific `pump(Duration)` where possible
    - Consider breaking files with 50+ `pumpAndSettle` calls into smaller focused tests

### Phase 4: Systematic fakeAsync Migration (Long-Term)

**Goal:** Bring fakeAsync adoption from 6.2% to 50%+ for non-widget tests.

12. **Migrate service/controller tests to fakeAsync**
    - Prioritize tests with timers, delays, or retry logic
    - Use existing `retry_fake_time.dart` and `pump_retry_time.dart` infrastructure
    - Target: all tests under `test/features/*/state/`, `test/features/*/repository/`, `test/services/`

13. **Add CI guardrails**
    - Lint rule or pre-commit hook to catch `Future.delayed` in `*_test.dart`
    - Warning for `pumpAndSettle(Duration(seconds: N))` where N >= 2
    - Warning for test files with 50+ `pumpAndSettle` calls

---

## Success Metrics

| Metric                              | Current    | Target (Phase 2) | Target (Phase 4) |
|-------------------------------------|------------|-------------------|-------------------|
| Inline mock class definitions       | 874        | < 50              | < 20              |
| `registerFallbackValue` inline calls| 560        | < 50              | < 20              |
| GetIt boilerplate files             | 100+       | < 10              | < 5               |
| Explicit timeouts >= 2s             | 6          | 0                 | 0                 |
| `Future.delayed` in test files      | 2          | 0                 | 0                 |
| fakeAsync adoption                  | 6.2%       | 15%               | 50%+              |
| Garbage/empty test files            | ~7         | 0                 | 0                 |
| Duplicate test file pairs           | ~10        | 0                 | 0                 |
| Total test LOC                      | 332K       | ~320K             | ~300K             |
