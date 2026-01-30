# Implementation Plan: Double-Tap Edit for Planned Blocks

**Date:** 2026-01-30
**Feature:** Enable double-tap editing of planned blocks in timeline
**Status:** Complete

## Problem Statement

Users didn't know they could long-press planned blocks in the timeline to edit them. Double-tap is a more intuitive gesture.

## Solution

Add `onDoubleTap` handler to `_PlannedBlockWidget` that opens `PlannedBlockEditModal`, alongside the existing `onLongPress`.

## Implementation

**File:** `lib/features/daily_os/ui/widgets/daily_timeline.dart`

**Change:** Added `onDoubleTap` to the `GestureDetector` in `_PlannedBlockWidget`:

```dart
GestureDetector(
  onTap: () {
    // highlight category
  },
  onDoubleTap: () {
    PlannedBlockEditModal.show(context, slot.block, date);
  },
  onLongPress: () {
    PlannedBlockEditModal.show(context, slot.block, date);
  },
  // ...
)
```

Now users can edit planned blocks via:
- **Double-tap** (intuitive)
- **Long-press** (still works for those who prefer it)

## Future Work (Out of Scope)

- Drag and drop support for moving blocks
- Pull to resize block duration
