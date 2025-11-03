# Task Cards — Title Focus & Scroll Padding (2025‑11‑03)

## Summary

- Reduce visual prominence of the category icon on task cards and move it into the second row, just before the priority/status chips.
- Remove the dedicated leading column so the title gains horizontal space and aligns with the card’s left padding (mirrors right padding).
- Add extra space at the bottom of the tasks list to avoid the last card being partially obscured and to separate it from the time recorder and FAB.

## Goals

- Title gets more width by eliminating the left icon gutter on task cards.
- Category icon becomes a subtle inline element:
  - Sits in the subtitle row, before `P3` and `Groomed` chips.
  - Visually sized to match the chips (reduced from large display size).
- Improve scroll experience by adding ~100 px bottom space in the tasks list.
- Zero analyzer warnings; thorough widget tests for the updated layout.

## Non‑Goals

- No changes to task data model, filtering, or navigation.
- No functional changes to status/priority semantics.
- No global theming overhaul; keep existing color/typography scale.

## Findings (grounded in code)

- Task card UI:
  - `lib/features/journal/ui/widgets/list_cards/modern_task_card.dart`
    - Uses `ModernBaseCard` + `ModernCardContent` with a `leading` `ModernIconContainer` that wraps `CategoryIconCompact(size: CategoryIconConstants.iconSizeLarge)`.
    - Subtitle row already contains the priority and status chips, optional due date, and trailing `CompactTaskProgress`.
- Card layout primitives:
  - `lib/widgets/cards/modern_card_content.dart` controls the optional `leading` slot and content spacing.
  - `lib/widgets/cards/modern_base_card.dart` applies symmetric `EdgeInsets.all(AppTheme.cardPadding)` (currently 16) and card visuals.
  - Chip styling lives in `lib/widgets/cards/modern_status_chip.dart`.
- Tasks list page:
  - `lib/features/journal/ui/pages/infinite_journal_page.dart` renders a `CustomScrollView` with a `PagedSliverList` (via `PagingListener`). No bottom padding/sliver is added today, which causes the last card to sit flush at the bottom and bounce back when trying to reveal it fully above the overlays.

## Design Changes

1) Reposition and resize category icon
- Remove the `leading` slot usage in `ModernTaskCard` to reclaim left space for the title.
- Add a compact `CategoryIconCompact` inline in the subtitle row, after the priority and status chips.
- Size choice: match chip visual scale rather than the old large display size.
  - Use `CategoryIconConstants.iconSizeSmall` (24px default) to visually match the ~26px chip height.
  - Spacing: `SizedBox(width: 6)` between the status chip and the category icon (consistent with existing chip spacing).
- Keep category color as the icon color for recognizability.

2) Increase bottom space in the scroll view
- Wrap the `PagedSliverList` with `SliverPadding(padding: EdgeInsets.only(bottom: 100))` so the last item can scroll fully into view above the time recorder and FAB.
- Alternatively/additionally append a terminal `SliverToBoxAdapter(child: SizedBox(height: 100))` if wrapping proves awkward with `PagingListener`.

## Implementation Plan

A. ModernTaskCard (title focus)
- File: `lib/features/journal/ui/widgets/list_cards/modern_task_card.dart`
- Changes:
  - Remove `leading: ModernIconContainer(child: CategoryIconCompact(...))` from `ModernCardContent`.
  - In `_buildSubtitleWidget`, add a small `CategoryIconCompact` to the `statusRow` children list after the priority and status chips:
    - Priority chip, then status chip, then `const SizedBox(width: 6)`, then `CategoryIconCompact(task.meta.categoryId, size: /* see Decision */)`
  - Verify no overflow or misalignment; keep `CompactTaskProgress` aligned at the far right via `Spacer()`.

B. InfiniteJournalPage (bottom padding)
- File: `lib/features/journal/ui/pages/infinite_journal_page.dart`
- Changes:
  - Inside the `PagingListener` builder, wrap the `PagedSliverList<int, JournalEntity>` in `SliverPadding(padding: const EdgeInsets.only(bottom: 100), sliver: ...)`.
  - If wrapping inside `PagingListener` is intrusive, add a final `SliverToBoxAdapter(child: SizedBox(height: 100))` after the paged list sliver.

C. Tests (add first, iterate per guideline)
- Use `flutter_test` with targeted widget tests; run analyzer/tests after each file via MCP tools.

1. ModernTaskCard layout tests
- New file: `test/features/journal/ui/widgets/list_cards/modern_task_card_test.dart`
- Cases:
  - Renders category icon in subtitle row before the priority chip using Row children inspection:
    ```dart
    // Find the Row that contains the chips
    final rowFinder = find.ancestor(
      of: find.byType(ModernStatusChip).first,
      matching: find.byType(Row),
    );
    final row = tester.widget<Row>(rowFinder);
    expect(row.children[0], isA<CategoryIconCompact>());
    expect(row.children[1], isA<SizedBox>());
    expect(row.children[2], isA<ModernStatusChip>()); // priority chip
    ```
  - Does not render `ModernIconContainer` leading anymore (ensure it’s absent):
    ```dart
    expect(
      find.descendant(
        of: find.byType(ModernCardContent),
        matching: find.byType(ModernIconContainer),
      ),
      findsNothing,
    );
    ```
  - Category icon size matches the chosen target (24.0). Example:
    ```dart
    final iconFinder = find.byType(CategoryIconCompact);
    final size = tester.getSize(iconFinder.first);
    expect(size.width, 24);
    expect(size.height, 24);
    ```
  - Do not rely on pixel positioning for the title; verifying absence of the leading `ModernIconContainer` is sufficient to confirm the title gains space.

2. InfiniteJournalPage bottom padding tests
- New file: `test/features/journal/ui/pages/infinite_journal_page_bottom_padding_test.dart`
- Approach:
  - Provide a stub `JournalPageCubit`/`JournalPageState` with a minimal, non‑null `pagingController` and a tiny page of fake `JournalEntity` tasks.
  - Pump `InfiniteJournalPageBody(showTasks: true)` inside a `BlocProvider.value` using the stub.
- Assert there is a `SliverPadding` with `EdgeInsets.only(bottom: 100)` or a terminal `SliverToBoxAdapter` with `SizedBox(height: 100)`.
  - Optionally scroll to max extent to ensure no bounce‑back hides the final card (golden/unnecessary — keep test reliable and structural).

D. Housekeeping
- Run `dart-mcp.dart_format` to format the workspace.
- Run analyzer via MCP: `dart-mcp.analyze_files` (zero warnings policy).
- Run targeted tests via MCP: `dart-mcp.run_tests` with `paths` limited to the new test files.
- Update `CHANGELOG.md` under “UI” with a brief note: “Task cards: category icon moved inline; bottom padding added to tasks list.”
- No localization edits needed.

E. Update/baseline existing tests
- Before implementation, search for and update any existing tests that assert on the leading category icon or ModernIconContainer in task cards, to prevent breakage:
  - Discovery commands:
    - `rg -n "ModernTaskCard|AnimatedModernTaskCard" test`
    - `rg -n "ModernIconContainer|CategoryIconCompact\(" test`
  - Adjust expectations to the new inline icon placement per the patterns above.

## Decisions

- Category icon inline size: 24px (`CategoryIconConstants.iconSizeSmall`) to align with chip height without dominating.
- Icon emphasis/color: keep full category color (no alpha reduction).
- Bottom padding: fixed 100px across all platforms; implement via a terminal `SliverToBoxAdapter(SizedBox(height: 100))` after the paged list.
- Presence rule: always show the category icon inline after priority/status chips regardless of labels.

## Risks & Mitigations

- Risk: Icon inline may increase subtitle row height on small screens.
  - Mitigation: Use compact size (24px) and maintain chip spacing (6px). Verify on smaller device sizes in tests/manual run.
- Risk: Wrapping `PagedSliverList` may be awkward inside `PagingListener`.
  - Mitigation: Append a final `SliverToBoxAdapter(SizedBox(height: 100))` instead — behavior‑equivalent and simpler. <= YES GOOD IDEA
- Risk: Visual regressions in other cards using `ModernCardContent` leading slot.
  - Mitigation: We only change `ModernTaskCard` usage; other cards still use `leading` as before.

## Manual QA Checklist

- Small phone (e.g., iPhone SE size): verify title wrapping, chip row height, and tap targets.
- Tablet layout: verify alignment and that increased width benefits title.
- Very long task titles (50+ chars): ensure ellipsis behavior is unchanged and visually balanced.
- Tasks with many chips (priority, status, due date, several labels): ensure no overflow and spacing remains consistent.
- Tasks with no category: verify fallback icon rendering inline does not distort row height.

## Rollout Plan

1) Add tests (failing initially): ModernTaskCard order/size tests; tasks page bottom padding test.
2) Implement `ModernTaskCard` changes; fix tests; run analyzer.
3) Implement `InfiniteJournalPage` padding; fix tests; run analyzer.
4) Format, update `CHANGELOG`, and run full `make test`.

## Acceptance Criteria

- Task cards show the category icon inline in the subtitle row before the priority and status chips.
- The title aligns with the card’s left padding and has visibly more width than before.
- The category icon is reduced to a compact size matching the chips’ visual scale (decision above), without overshadowing the title.
- The tasks list allows the last item to scroll fully into view; a ~100px space exists between 
  the last card and the bottom overlays.
- Analyzer: zero warnings. All new tests pass reliably.

## Code Pointers

- `lib/features/journal/ui/widgets/list_cards/modern_task_card.dart`
- `lib/widgets/cards/modern_card_content.dart` (reference only; no changes planned here)
- `lib/widgets/cards/modern_status_chip.dart` (reference for sizing)
- `lib/features/journal/ui/pages/infinite_journal_page.dart`

---

## Appendix — Sketch of core diffs (illustrative)

ModernTaskCard

```dart
// before
ModernCardContent(
  title: task.data.title,
  maxTitleLines: 3,
  leading: ModernIconContainer(
    child: CategoryIconCompact(
      task.meta.categoryId,
      size: CategoryIconConstants.iconSizeLarge,
    ),
  ),
  subtitleWidget: _buildSubtitleWidget(context),
  trailing: TimeRecordingIcon(...),
)

// after
ModernCardContent(
  title: task.data.title,
  maxTitleLines: 3,
  subtitleWidget: _buildSubtitleWidget(context),
  trailing: TimeRecordingIcon(...),
)

Widget _buildSubtitleWidget(BuildContext context) {
  final brightness = Theme.of(context).brightness;
  final statusRow = Row(
    children: [
      // NEW — subtle inline category icon
      CategoryIconCompact(
        task.meta.categoryId,
        size: 20, // or CategoryIconConstants.iconSizeExtraSmall (16) — see decision
      ),
      const SizedBox(width: 6),
      ModernStatusChip(label: task.data.priority.short, ...),
      const SizedBox(width: 6),
      ModernStatusChip(label: _getStatusLabel(context, task.data.status), ...),
      // ... unchanged: due date, Spacer, CompactTaskProgress
    ],
  );
  // ... unchanged labels row below
}
```

InfiniteJournalPage (one option)

```dart
return PagedSliverList<int, JournalEntity>(
  state: pagingState,
  fetchNextPage: fetchNextPageFunction,
  builderDelegate: ...,
).toSliverPadding(bottom: 100); // extension or explicit SliverPadding
```

Or explicitly:

```dart
SliverPadding(
  padding: const EdgeInsets.only(bottom: 100),
  sliver: PagedSliverList<int, JournalEntity>(
    state: pagingState,
    fetchNextPage: fetchNextPageFunction,
    builderDelegate: ...,
  ),
)
```

```dart
// Alternative minimal change if wrapping complicates the builder:
const SliverToBoxAdapter(child: SizedBox(height: 100)),
```
