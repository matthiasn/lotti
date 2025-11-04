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
- Insert it directly below the header as a `SliverToBoxAdapter(child: TaskLabelQuickFilter())` so it
  can lay out to its intrinsic height and wrap across multiple rows without constraints.
- Padding & divider decisions (final):
  - Keep the widget’s internal `Padding(EdgeInsets.only(top: 4))` for vertical rhythm.
  - Add an outer horizontal padding of `EdgeInsets.symmetric(horizontal: 40)` to align with the
    search field margins. The double padding is intentional: inner = top spacing; outer = horizontal
    alignment. No vertical duplication is introduced.
  - Insert a full‑bleed divider as a separate sliver before the padded section for clear visual
    separation from the header: `const SliverToBoxAdapter(child: Divider(height: 1))`. Using the
    stock `Divider` keeps the color theme‑aware.

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
  - Insert after `const JournalSliverAppBar(),` two slivers:
    ```dart
    // Subtle separator below the header (theme-aware)
    const SliverToBoxAdapter(child: Divider(height: 1)),
    // Visible only when tasks are shown and labels are selected (handled inside the widget)
    const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40),
        child: TaskLabelQuickFilter(),
      ),
    ),
    ```
  - We choose a standalone Divider sliver (outside padding) for a full‑bleed rule that clearly
    separates the header from the filter section.

C. Visual details

- Maintain the existing typography from `TaskLabelQuickFilter` (`labelSmall` for captions,
  `InputChip` for chips).
- Respect theme colors; ensure contrast meets WCAG AA for the “Clear” button.

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
- Keep horizontal padding at `40` to align with the search bar’s
  `EdgeInsets.symmetric(horizontal: 40)` used today.

## Risks & Mitigations

- Risk: Extra vertical space might feel heavy when many labels are selected.
  - Mitigation: The section scrolls with content in Phase 1. Phase 2 can pin and cap height with
    internal scrolling if needed.
- Risk: The divider/padding might not perfectly match themes on all platforms.
  - Mitigation: Use the stock `Divider` widget (theme‑aware by default) and verify on iOS/Android/Desktop.
- Risk: Tests need a stubbed `JournalPageCubit`.
  - Mitigation: Follow patterns from existing tests that drive `BlocBuilder` state.
 - Risk: Always‑present divider sliver adds overhead.
   - Mitigation: Cost is negligible (1‑px rule). Keep it as a separate sliver for clarity; profile if needed.

## Manual QA Checklist

- No labels selected → no filter section is shown.
- 1–2 labels selected → section shows with one row of chips, “Clear” works.
- Many labels selected → chips wrap to multiple rows; no clipping.
- Small device width → chips wrap early; tap targets remain ≥ 40x40 dp.
- Verify with light/dark themes; ensure the divider and text contrast is adequate.
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
