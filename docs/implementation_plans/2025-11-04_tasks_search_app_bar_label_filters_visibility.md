# Tasks Search App Bar — Show Active Label Filters (2025‑11‑04)

## Summary

On the Tasks page, selected label chips are supposed to appear near the search bar, but they are not
visible because the current `SliverAppBar` has a fixed `toolbarHeight` and the chips are placed
inside the `title` column. The result is clipping.

We will redesign the header so active label filters always have dedicated space just below the
search row. Phase 1 moves the chips out of the app bar into their own sliver right under the
header (simple and robust, supports multi‑line wraps). Phase 2 optionally upgrades this to a pinned
sliver for a premium feel while scrolling.

## Goals

- Always show selected label chips when any are active, with a “Clear” action.
- No clipping; support multiple rows of chips gracefully.
- Keep the search row exactly as is (no functional change).
- Maintain visual polish consistent with the current app chrome.
- Zero analyzer warnings and targeted widget tests.

## Non‑Goals

- No changes to filter logic, label management, or the filter modal.
- No redesign of the search field or icons.
- No dependency on settings header design.

## Findings (grounded in code)

- Tasks/Journal header: `lib/widgets/app_bar/journal_sliver_appbar.dart`
  - Uses `SliverAppBar(pinned: true, toolbarHeight: 100)`.
  - Puts `TaskLabelQuickFilter()` inside the `title` column under the search row.
  - This column can exceed 100px, causing the quick filter to be clipped.

- Label chips widget: `lib/features/tasks/ui/filtering/task_label_quick_filter.dart`
  - Hides when no labels are selected, else renders a title row ("Active label filters" + “Clear”)
    and a wrapping chips `Wrap`.
  - Its natural height varies based on selected labels (can be 1+ rows).

- Tasks list page: `lib/features/journal/ui/pages/infinite_journal_page.dart`
  - Renders `CustomScrollView` with `const JournalSliverAppBar()` followed by a paged sliver list.
  - Ideal insertion point for a dedicated quick‑filter sliver.

## Design Changes

1) Move quick filter out of the app bar (Phase 1)

- Remove `TaskLabelQuickFilter()` from the app bar `title`.
- Insert it directly below the header as a dedicated sliver so it can lay out to its intrinsic
  height and wrap across multiple rows without constraints.
- Layout decisions (final):
  - No divider; use spacing and a compact card‑style container for separation.
  - Outer padding: `EdgeInsets.fromLTRB(40, 8, 40, 8)`.
  - Card container: `Container(decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)), padding: EdgeInsets.all(12))`.
  - Animation: Wrap with `AnimatedSize(duration: 180ms, curve: easeInOut, alignment: topCenter)`.
  - Header (from TaskLabelQuickFilter): icon + “Active label filters (n)” + compact Clear button.

2) Optional: Pinned quick filter (Phase 2)

- Replace the `SliverToBoxAdapter` with a
  `SliverPersistentHeader(pinned: true, floating: false, delegate: …)` that computes `minExtent = 0`
  and `maxExtent` based on active content height.
- Animate show/hide with `AnimatedSize` inside the delegate to feel smooth.
 - Complexity warning: Dynamic height measurement (delegate + `GlobalKey`) can be fragile and may
   introduce jank during rapid label toggling. Defer Phase 2 until Phase 1 ships and only pursue if
   user feedback indicates the pinned behavior is valuable.

## Implementation Plan

### Phase 1 — Simple, Correct, and Polished

A. JournalSliverAppBar (remove embedded quick filters)

- File: `lib/widgets/app_bar/journal_sliver_appbar.dart`
- Changes:
  - Delete the `if (showTasks) const TaskLabelQuickFilter(),` line from the `title` column.
  - Keep `toolbarHeight: 100` for the search row and icons.

B. InfiniteJournalPage (add quick filter sliver)

- File: `lib/features/journal/ui/pages/infinite_journal_page.dart`
- Changes:
  - Insert after `const JournalSliverAppBar(),` a conditional sliver:
    ```dart
    if (snapshot.showTasks && snapshot.selectedLabelIds.isNotEmpty)
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(40, 8, 40, 8),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(12),
              child: const TaskLabelQuickFilter(),
            ),
          ),
        ),
      ),
    ```
  - Rationale: the decorated wrapper would otherwise render an empty card when no labels are active; page‑level gating avoids that.

C. Visual details

- Header: `labelMedium` + `onSurfaceVariant`, with a leading filter icon and count suffix “(n)”.
- Clear: `TextButton.icon(backspace_outlined)` with compact density and `labelSmall` text style.
- Chips: compact density for visual balance with the header.
- Background: `surfaceContainerHighest`; verify adequate contrast in light/dark.

D. Tests (targeted)

- New: `test/features/journal/ui/pages/infinite_journal_page_filters_header_test.dart`
  - Renders `InfiniteJournalPageBody(showTasks: true)` with a stubbed `JournalPageCubit` state
    containing `selectedLabelIds`.
  - Asserts that:
    - The sliver adapter with `TaskLabelQuickFilter` is present when labels are selected.
    - The `JournalSliverAppBar` no longer contains `TaskLabelQuickFilter`.
    - Tapping “Clear” calls `clearSelectedLabelIds()` on the cubit.
  - Also asserts absence of the sliver when no labels are selected.
  - Follow existing patterns from `infinite_journal_page_test.dart`:
    - Define/reuse the `pumpWithDelay` pattern from that file (copy the helper into the new test) instead of `pumpAndSettle` for stability.
    - Mirror the existing `setUp`/`tearDown` and `getIt` registrations.
  - Verifying removal from the app bar:
    - Preferred: assert the widget appears in the new location (as child of `SliverToBoxAdapter` with horizontal padding).
    - Optional: `expect(find.descendant(of: find.byType(JournalSliverAppBar), matching: find.byType(TaskLabelQuickFilter)), findsNothing);`

E. Existing tests (verification)

- `test/features/tasks/ui/filtering/task_label_quick_filter_test.dart` covers the widget in
  isolation and should remain green (no internal change).
- `test/features/journal/ui/pages/infinite_journal_page_test.dart` does not assert the quick
  filter’s location and should remain green; run it explicitly to confirm no regressions.

F. Housekeeping

- Run formatter and analyzer.
- Update `CHANGELOG.md` under `[Unreleased]` → `### Fixed`: “Tasks page: active label filters display below search; no longer clipped.” Include PR/issue number when available.
- Ensure `material.dart` remains imported where the divider/padding are added (already the case in these files).

### Phase 2 — Upgrade to Pinned (nice‑to‑have)

G. Create `TaskFiltersHeaderDelegate`

- New file: `lib/features/tasks/ui/filtering/task_filters_header_delegate.dart`
- Implements `SliverPersistentHeaderDelegate` and reads `JournalPageState`.
- Uses the existing `TaskLabelQuickFilter` content internally; measures its height with a
  `GlobalKey` + `AnimatedSize` to drive `maxExtent`.
- Returns `0 → maxExtent` with smooth animation as labels toggle.

H. Replace the Phase 1 adapter

- In `infinite_journal_page.dart`, swap the `SliverToBoxAdapter` for:
  ```dart
  SliverPersistentHeader(
    pinned: true,
    delegate: TaskFiltersHeaderDelegate(context: context),
  ),
  ```

I. Tests

- Extend the test to verify the header remains visible when scrolling and that height adapts when
  adding/removing labels.

## Decisions

- Phase 1 first: ship a robust fix quickly without over‑engineering. It fully resolves the
  visibility/clipping issue and supports multi‑line wraps out of the box.
- Optional Phase 2 delivers a premium feel (pinned) without blocking the initial improvement.
- Keep horizontal padding at `40` to align with the search bar margins.
- Preferred: compact card‑style container (rounded background) without a divider under the header.
- Page‑level condition (`selectedLabelIds.isNotEmpty`) is intentional to prevent an empty decorated container when no filters are active.

## Risks & Mitigations

- Risk: Extra vertical space might feel heavy when many labels are selected.
  - Mitigation: The section scrolls with content in Phase 1. Phase 2 can pin and cap height with
    internal scrolling if needed.
- Risk: Confusion about visibility enforcement (page vs widget).
  - Mitigation: Document that page‑level gating avoids an empty card due to the decorated wrapper; TaskLabelQuickFilter still self‑hides its content.
- Risk: Tests need a stubbed `JournalPageCubit`.
  - Mitigation: Follow patterns from existing tests that drive `BlocBuilder` state.
 - Risk: Always‑present divider sliver adds overhead.
   - Mitigation: Cost is negligible (1‑px rule). Keep it as a separate sliver for clarity; profile if needed.

## Manual QA Checklist

- No labels selected → no filter section is shown.
- 1–2 labels selected → section shows with one row of chips, “Clear” works.
- Many labels selected → chips wrap to multiple rows; no clipping.
- Small device width → chips wrap early; tap targets remain ≥ 40x40 dp.
- Verify with light/dark themes; ensure background and text contrast are adequate.
- Scroll behavior → section sits directly below the app bar (Phase 1) and can be pinned (Phase 2).
 - Upgrade path: during a version jump, toggle labels on an existing install to ensure the new
   divider + sliver appear without flicker.

## Rollout Plan

1) Add tests (red) that verify the new sliver location and confirm `TaskLabelQuickFilter` is no
   longer inside the app bar title.
2) Implement Phase 1 changes and fix tests.
3) Format, analyze, and run targeted tests via MCP tools; rerun existing
   `infinite_journal_page_test.dart` and `task_label_quick_filter_test.dart` to ensure no regressions.
4) Optionally implement Phase 2 and extend tests.

## Acceptance Criteria

- When label filters are active, a clearly visible “Active label filters” section with chips and a
  “Clear” action appears directly below the search header.
- No visual clipping on any device size; chips wrap naturally.
- Search row remains unchanged and aligned.
- Analyzer shows zero warnings; tests pass.
