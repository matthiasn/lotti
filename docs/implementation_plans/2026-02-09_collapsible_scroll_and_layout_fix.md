# Fix Collapsible Scroll Jumpiness & Header Layout

**Date:** 2026-02-09
**Branch:** `feat/collapse_improvements`
**Status:** Approved

## Problem Summary

The recent collapsible entry feature (PR #2643) introduced two UX regressions:

1. **Scroll jumpiness** — Expanding/collapsing an entry triggers `Scrollable.ensureVisible`, which forcibly scrolls the page and disorients the user.
2. **Header layout regression** — Action icons (flag, AI, triple-dot) are placed on the left side when expanded, and the date disappears from the header into the body. This looks wrong and wastes space formerly occupied by the now-removed cover art icon.

## Root Cause Analysis

### Scroll Jumpiness

**File:** `lib/features/journal/ui/widgets/entry_details_widget.dart` (lines 475-483)

After every collapse/expand toggle, the code unconditionally calls:
```dart
Future.delayed(AppTheme.collapseAnimationDuration, () {
  if (context.mounted) {
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }
});
```

`Scrollable.ensureVisible` scrolls to make the widget's top edge visible, which moves the viewport even when the entry is already fully visible. This is the direct cause of the jump.

### Header Layout

**File:** `lib/features/journal/ui/widgets/entry_details/header/entry_detail_header.dart` (lines 121-191)

In `_buildCollapsibleHeader`, when expanded:
```
[Star*] [Flag*] [AI menu] [Triple-dot] ... Spacer ... [Chevron]
```

Action icons are on the **left**, with only the chevron on the right. The date is not shown in the header at all when expanded — it's pushed into `expandedContent` below the image/audio player (entry_details_widget.dart lines 514-520, 526-528, 532-534).

## Implementation Plan

### Step 1: Replace Unconditional Scroll with Conditional Scroll-Into-View

**File:** `lib/features/journal/ui/widgets/entry_details_widget.dart`

**Change:** Replace the `Future.delayed` + `Scrollable.ensureVisible` block with conditional logic that only scrolls when expanding and only when the card top gets pushed above the viewport.

**Rationale:** `AnimatedSize` expands in-place. The parent `CustomScrollView` in `EntryDetailsPage` naturally extends its scroll extent downward. The user's current scroll offset is preserved — the card's top stays exactly where it was. Only when the expanded content pushes the card top above the viewport do we need to gently scroll.

**Safety:** Use `RenderAbstractViewport.maybeOf` and `Scrollable.maybeOf` (nullable variants) instead of `.of` to avoid exceptions if the widget tree has changed after the `Future.delayed` callback fires.

```dart
onToggleCollapse: isCollapsible && currentLink != null
    ? () async {
        final isExpanding = currentLink.collapsed ?? false;
        // ... update link in DB (existing code) ...

        // Only auto-scroll when expanding and the card top is pushed
        // above the visible viewport. Collapsing never needs a scroll.
        if (isExpanding) {
          Future.delayed(AppTheme.collapseAnimationDuration, () {
            if (!context.mounted) return;
            final renderObject = context.findRenderObject();
            if (renderObject == null) return;
            final viewport =
                RenderAbstractViewport.maybeOf(renderObject);
            if (viewport == null) return;
            final revealedOffset = viewport.getOffsetToReveal(
              renderObject, 0.0,
            );
            final scrollable = Scrollable.maybeOf(context);
            if (scrollable == null) return;
            final currentOffset = scrollable.position.pixels;
            if (revealedOffset.offset < currentOffset) {
              Scrollable.ensureVisible(
                context,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                alignment: 0.05, // small top margin
              );
            }
          });
        }
      }
    : null,
```

**Key behavior:**
- **Collapsing:** Never auto-scrolls (content shrinks, nothing moves up out of view).
- **Expanding, card stays visible:** No scroll — zero jumpiness.
- **Expanding, card top pushed above viewport:** Smooth scroll to bring card top just into view.

### Step 2: Restructure Collapsible Header Layout

**File:** `lib/features/journal/ui/widgets/entry_details/header/entry_detail_header.dart`

**Replace** `_buildCollapsibleHeader` with a layout that matches the default header's conventions:

**Expanded state:**
```
[Date]  ...Spacer...  [Flag*] [AI menu] [Triple-dot] [Chevron]
```

**Collapsed state (unchanged concept, just reordered):**
```
[Thumbnail/Mic] [Date] [Duration*]  ...Spacer...  [Chevron]
```

**Concrete changes in `_buildCollapsibleHeader`:**

1. When expanded, show `EntryDatetimeWidget` as the **first** child (left-aligned), followed by `Spacer`, then action icons, then chevron — mirroring `_buildDefaultHeader` but with the chevron appended.
2. When collapsed, keep the existing thumbnail + date + duration preview, followed by `Spacer`, then chevron (same as current).

```dart
Widget _buildCollapsibleHeader(...) {
  return Row(
    children: [
      if (widget.isCollapsed) ...[
        // Collapsed preview: thumbnail/icon + date + duration
        if (entry is JournalImage) _buildImageThumbnail(entry),
        if (entry is JournalAudio) _buildAudioIcon(context),
        const SizedBox(width: AppTheme.spacingSmall),
        EntryDatetimeWidget(entryId: widget.entryId),
        if (entry is JournalAudio) _buildDurationLabel(context, entry),
      ],
      if (!widget.isCollapsed) ...[
        // Expanded: date on left, actions on right
        EntryDatetimeWidget(entryId: widget.entryId),
      ],
      const Spacer(),
      if (!widget.isCollapsed) ...[
        // Action icons only when expanded
        if (entry is! JournalEvent && (entry?.meta.starred ?? false))
          SwitchIconWidget(/* star */),
        if (entry?.meta.flag == EntryFlag.import)
          SwitchIconWidget(/* flag */),
        if (entry != null && (entry is Task || entry is JournalImage || entry is JournalAudio))
          UnifiedAiPopUpMenu(/* AI menu */),
        IconButton(/* triple-dot */),
      ],
      AnimatedRotation(
        turns: widget.isCollapsed ? -0.25 : 0.0,
        duration: AppTheme.chevronRotationDuration,
        child: IconButton(/* chevron */),
      ),
    ],
  );
}
```

### Step 3: Remove Duplicate Date from Expanded Content

**File:** `lib/features/journal/ui/widgets/entry_details_widget.dart`

Since the date is now back in the header (Step 2), remove the `datePadding` widget and its usage in `expandedContent`. The date no longer needs to appear below the image/audio player.

**Remove:**
```dart
final datePadding = Padding(
  padding: const EdgeInsets.only(
    left: AppTheme.spacingXSmall,
    top: AppTheme.spacingXSmall,
  ),
  child: EntryDatetimeWidget(entryId: itemId),
);
```

**And remove `datePadding` from the `expandedContent` Column children** (both the JournalImage and JournalAudio branches).

### Step 4: Fix AnimatedSize Alignment

**File:** `lib/features/journal/ui/widgets/entry_details_widget.dart`

Ensure `AnimatedSize` has `alignment: Alignment.topCenter` so the expansion animation grows downward from the header, not from the center. This prevents a subtle visual glitch where content appears to slide from the center:

```dart
AnimatedSize(
  duration: AppTheme.collapseAnimationDuration,
  curve: Curves.easeOutCubic,
  alignment: Alignment.topCenter,  // <-- add this
  child: isCollapsed ? const SizedBox.shrink() : expandedContent,
),
```

Also add the same in `CollapsibleSection` (`lib/widgets/misc/collapsible_section.dart`).

### Step 5: Update Tests

**File:** `test/features/journal/ui/widgets/entry_details/entry_detail_header_collapsible_test.dart`

Update existing tests that assert on expanded header layout:

1. The test `'does NOT show date or preview when expanded'` needs to change — the expanded header now **does** show a date widget. Rename and update to verify `EntryDatetimeWidget` is present.
2. Add a new test verifying the expanded header shows date on the left (first child before the Spacer).
3. Existing collapsed-state tests should continue to pass unchanged.

## Files Changed

| File | Change |
|------|--------|
| `lib/features/journal/ui/widgets/entry_details_widget.dart` | Replace unconditional scroll with conditional scroll-into-view; remove `datePadding`; add `alignment: Alignment.topCenter` to `AnimatedSize` |
| `lib/features/journal/ui/widgets/entry_details/header/entry_detail_header.dart` | Restructure `_buildCollapsibleHeader` — date left, actions + chevron right |
| `lib/widgets/misc/collapsible_section.dart` | Add `alignment: Alignment.topCenter` to `AnimatedSize` |
| `test/features/journal/ui/widgets/entry_details/entry_detail_header_collapsible_test.dart` | Update expanded-state tests for date-in-header layout |

## Testing

- Verify all existing tests pass (header tests, entry detail tests)
- Updated automated tests:
  - Expanded collapsible header now asserts `EntryDatetimeWidget` is present
  - Collapsed-state tests remain unchanged
- Manual verification:
  - Expand an image entry — page should NOT jump; content expands downward
  - Expand an audio entry — same behavior
  - Expand an entry near the bottom of the viewport — should gently scroll only if the card top gets pushed above the viewport
  - Collapse an entry — should never scroll
  - Header layout: date on top-left, action icons + chevron grouped on top-right when expanded
  - Collapsed header: thumbnail + date + chevron unchanged
