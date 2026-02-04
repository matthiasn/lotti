# Drag-and-Drop for Planned Time Blocks

## Overview

Implement drag-and-drop functionality for moving and resizing planned time blocks in the Daily OS Calendar View. This enables direct manipulation of the "Plan" lane blocks instead of requiring the edit modal for all changes.

## Screenshot Reference

The screenshot shows the Timeline view with:
- **Left lane ("Plan")**: Contains planned blocks like "1K5" (purple) and "Lotti" (olive) - these are the targets for drag/drop
- **Right lane ("Actual")**: Shows recorded time entries

---

## 1. Gesture Architecture

### Hit Zones (Platform-Adaptive)

```
+-------------------+
|  [Top Edge]       |  <- Resize top (change start time)
|                   |
|    [Body Zone]    |  <- Move entire block
|                   |
|  [Bottom Edge]    |  <- Resize bottom (change end time)
+-------------------+
```

**Hit zone sizes:**
- Desktop (pointer): 12px edges
- Touch devices: 20px edges (larger touch targets)

**Small block handling:**
- Blocks < 48px tall (< 72 minutes): Move-only mode, no edge resize
- This prevents resize handles from overlapping

### Gesture Disambiguation

Uses `RawGestureDetector` with custom recognizers for precise control over gesture conflicts:

| Gesture | Zone | Action |
|---------|------|--------|
| Tap | Any | Highlight category |
| Double-tap | Any | Open edit modal |
| Long-press (300ms) | Any | Begin drag operation (prevents accidental drags) |
| Vertical drag (after long-press) | Top edge | Resize top (change start time) |
| Vertical drag (after long-press) | Body | Move entire block |
| Vertical drag (after long-press) | Bottom edge | Resize bottom (change end time) |

**Rationale**: Long-press to initiate drag prevents accidental drags when scrolling and provides clear user intent.

---

## 2. State Management

### Drag State (Local Widget State)

```dart
enum PlannedBlockDragMode { none, move, resizeTop, resizeBottom }

@immutable
class PlannedBlockDragState {
  const PlannedBlockDragState({
    required this.mode,
    required this.originalBlock,
    required this.currentStartMinutes,
    required this.currentEndMinutes,
    required this.date,
  });

  final PlannedBlockDragMode mode;
  final PlannedBlock originalBlock;
  final int currentStartMinutes;  // Minutes from midnight
  final int currentEndMinutes;
  final DateTime date;  // The date for DateTime reconstruction

  Duration get currentDuration =>
      Duration(minutes: currentEndMinutes - currentStartMinutes);

  /// Converts minutes back to DateTime for persistence
  DateTime get startDateTime => DateTime(
    date.year, date.month, date.day,
  ).add(Duration(minutes: currentStartMinutes));

  DateTime get endDateTime => DateTime(
    date.year, date.month, date.day,
  ).add(Duration(minutes: currentEndMinutes));

  PlannedBlockDragState copyWith({
    PlannedBlockDragMode? mode,
    int? currentStartMinutes,
    int? currentEndMinutes,
  }) => PlannedBlockDragState(
    mode: mode ?? this.mode,
    originalBlock: originalBlock,
    currentStartMinutes: currentStartMinutes ?? this.currentStartMinutes,
    currentEndMinutes: currentEndMinutes ?? this.currentEndMinutes,
    date: date,
  );
}
```

### Update Flow

1. **Long-press Start**: Detect zone, create `PlannedBlockDragState`, trigger haptic feedback, lock scroll
2. **Drag Update**: Calculate delta, apply snapping, update local state (optimistic UI)
3. **Drag End**: Call `updatePlannedBlock()` on `UnifiedDailyOsDataController`, unlock scroll
4. **Drag Cancel**: Restore original position, unlock scroll

### Cancellation Triggers

- Drag position moves outside timeline bounds (> 50px horizontally)
- Second finger touch detected
- System interruption (phone call, etc.)

---

## 3. Visual Feedback

### During Drag

- **Time indicators**: Floating labels at top/bottom showing current times (e.g., "09:15")
- **Elevated appearance**: `elevation: 8`, slight scale (1.02x)
- **Duration badge**: Shows "1h 30m" in center during move operations
- **Haptic feedback**: Light impact on snap boundaries

### Resize Handle Affordances

- Subtle horizontal bars (3px height, 40% width, centered) at top/bottom edges
- Only visible on hover (desktop) or when block is focused
- Mouse cursor changes to `SystemMouseCursors.resizeUpDown` on hover (desktop only)

### Overlap Warning

- Dimmed appearance (0.4 opacity) when block would overlap another
- Red tint border when overlapping

### Drag Active State

- Other blocks fade to 0.5 opacity during drag
- `RepaintBoundary` around dragged block for 60fps performance

---

## 4. Scroll Interaction

### Current State

`DailyOsPage` (`lib/features/daily_os/ui/pages/daily_os_page.dart`) is currently a `ConsumerWidget` with:
- `SingleChildScrollView` using `AlwaysScrollableScrollPhysics()`
- No explicit `ScrollController`

### Required Changes to DailyOsPage

To implement scroll lock + auto-scroll, convert `DailyOsPage` to `ConsumerStatefulWidget`:

```dart
class DailyOsPage extends ConsumerStatefulWidget {
  const DailyOsPage({super.key});

  @override
  ConsumerState<DailyOsPage> createState() => _DailyOsPageState();
}

class _DailyOsPageState extends ConsumerState<DailyOsPage> {
  final _scrollController = ScrollController();
  bool _isDragActive = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onDragActiveChanged(bool isDragging) {
    setState(() => _isDragActive = isDragging);
  }

  @override
  Widget build(BuildContext context) {
    // ... existing build code, but with:
    SingleChildScrollView(
      controller: _scrollController,
      physics: _isDragActive
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      // ...
    )
  }
}
```

### Callback Propagation

The `onDragActiveChanged` callback must be passed through:
1. `DailyOsPage` → `DailyTimeline` (new prop)
2. `DailyTimeline` → `_VisibleTimelineSection` (new prop)
3. `_VisibleTimelineSection` → `DraggablePlannedBlock` (new prop)

### Auto-Scroll (Phase 2 Enhancement)

When dragging near container edges:
- Top/bottom 40px triggers auto-scroll
- Scroll speed: 100px/second, accelerating to 200px/second at edge
- Smooth animation using `AnimationController`
- Requires passing `_scrollController` down to `DraggablePlannedBlock`

**Note**: Auto-scroll is deferred to Phase 2. Initial implementation uses section-bounded drag (see Section 5).

---

## 5. Timeline Folding & Section Interaction

### Architecture Context

The timeline renders blocks inside **per-section `SizedBox`/`Stack` widgets** (`_VisibleTimelineSection` in `daily_timeline.dart:~523+`). Each section corresponds to either:
- A `VisibleCluster` (always visible hours)
- An expanded `CompressedRegion`

This means a block dragged across section boundaries will **visually clip/disappear** at the boundary unless we use an overlay.

### Design Decision: Section-Bounded Drag

To avoid complex overlay rendering and folding math, **drag is limited to the current visible section**:

1. Block cannot be dragged beyond the `startHour`/`endHour` of its containing section
2. If user drags to section edge, show hint: "Expand timeline to move further"
3. Existing tap-to-expand on compressed regions allows user to unlock more range

This avoids needing:
- An inverse of `timeToFoldedPosition` (position → time)
- Overlay-based drag rendering
- Complex cross-section coordinate mapping

### Minute-Accurate Compressed Region Detection

The detection must use **minutes, not hours**, to handle boundary cases correctly (e.g., a block from 9:45-10:15 where compressed region starts at 10:00):

```dart
/// Checks if a block overlaps with any compressed (non-expanded) region.
bool blockOverlapsCompressedRegion({
  required PlannedBlock block,
  required TimelineFoldingState foldingState,
  required Set<int> expandedRegions,
}) {
  final blockStartMinutes = block.startTime.hour * 60 + block.startTime.minute;
  final blockEndMinutes = block.endTime.hour * 60 + block.endTime.minute;

  for (final region in foldingState.compressedRegions) {
    // Skip if this region is expanded
    if (expandedRegions.contains(region.startHour)) continue;

    final regionStartMinutes = region.startHour * 60;
    final regionEndMinutes = region.endHour * 60;

    // Block overlaps if: blockStart < regionEnd AND blockEnd > regionStart
    if (blockStartMinutes < regionEndMinutes &&
        blockEndMinutes > regionStartMinutes) {
      return true;
    }
  }
  return false;
}
```

### Section Bounds for Drag Constraint

Each `DraggablePlannedBlock` receives its section's bounds:

```dart
class DraggablePlannedBlock extends ConsumerStatefulWidget {
  const DraggablePlannedBlock({
    required this.slot,
    required this.date,
    required this.sectionStartHour,  // From containing _VisibleTimelineSection
    required this.sectionEndHour,    // From containing _VisibleTimelineSection
    required this.onDragActiveChanged,
    // ...
  });
}
```

During drag, clamp position to section bounds:
```dart
void _updateMovePosition(double deltaY) {
  // ... calculate newStartMinutes, newEndMinutes ...

  // Clamp to section bounds
  final sectionStartMinutes = widget.sectionStartHour * 60;
  final sectionEndMinutes = widget.sectionEndHour * 60;
  final duration = newEndMinutes - newStartMinutes;

  newStartMinutes = newStartMinutes.clamp(
    sectionStartMinutes,
    sectionEndMinutes - duration,
  );
  newEndMinutes = newStartMinutes + duration;

  // Show hint if at boundary
  final atBoundary = newStartMinutes == sectionStartMinutes ||
      newEndMinutes == sectionEndMinutes;
  if (atBoundary && !_showingBoundaryHint) {
    _showBoundaryHint();
  }
}
```

### User Feedback

| Situation | Feedback |
|-----------|----------|
| Block overlaps compressed region | Drag disabled; tooltip: "Expand timeline to drag this block" |
| Drag reaches section boundary | Toast/snackbar: "Expand timeline to move further" |
| Block fully within visible section | Normal drag enabled |

### Future Enhancement: Overlay-Based Drag

For a more polished UX that allows cross-section dragging:
1. Render dragged block in an `Overlay` above the timeline
2. Use `timeToFoldedPosition` for visual positioning
3. Add inverse function `foldedPositionToTime` for drop target calculation
4. This would allow seamless dragging across section boundaries

This is **out of scope** for initial implementation but the architecture supports adding it later.

---

## 6. Edge Cases

| Constraint | Implementation |
|------------|----------------|
| **Minimum duration** | 15 minutes - prevents resize beyond this |
| **Minimum block height for resize** | 48px (72 min) - shorter blocks are move-only |
| **Snap to grid** | 5-minute intervals during drag |
| **Day boundaries** | Clamp to 00:00-24:00 |
| **Section boundaries** | Clamp to section's `startHour`-`endHour`; show hint at boundary |
| **Block overlaps** | Allowed (with visual warning) - user may intentionally overlap |
| **Overlaps compressed region** | Drag disabled, tooltip: "Expand timeline to drag this block" |
| **Very long blocks (> section height)** | Move-only if block is taller than section; rare edge case |
| **Block at section boundary** | Can still resize inward; cannot resize outward beyond section |

---

## 7. Files to Modify

### Primary Changes

| File | Changes |
|------|---------|
| `lib/features/daily_os/ui/pages/daily_os_page.dart` | Convert to `ConsumerStatefulWidget`, add `ScrollController`, add `_isDragActive` state, pass `onDragActiveChanged` callback down |
| `lib/features/daily_os/ui/widgets/daily_timeline.dart` | Add `onDragActiveChanged` prop to `DailyTimeline`, `_TimelineContent`, `_FoldedTimelineGrid`, `_VisibleTimelineSection`; pass `sectionStartHour`/`sectionEndHour` to block widget; extract `_PlannedBlockWidget` to new file |

### New Files

| File | Purpose |
|------|---------|
| `lib/features/daily_os/ui/widgets/planned_block_drag_state.dart` | Drag state class and mode enum |
| `lib/features/daily_os/ui/widgets/draggable_planned_block.dart` | Extracted widget with all drag logic, receives section bounds |
| `lib/features/daily_os/ui/widgets/drag_time_indicator.dart` | Time indicator overlay widget (section-local positioning) |
| `lib/features/daily_os/util/drag_position_utils.dart` | **Section-local** position calculation helpers (see below) |
| `test/features/daily_os/ui/widgets/planned_block_drag_test.dart` | Drag gesture tests |
| `test/features/daily_os/util/drag_position_utils_test.dart` | Unit tests for position math |

### drag_position_utils.dart Scope

This utility is **section-local only** - it does NOT handle folded timeline coordinates. All calculations assume a simple linear mapping within a single visible section:

```dart
/// Section-local position utilities.
/// All functions operate within a single visible section (startHour to endHour)
/// using the standard hourHeight (40px/hour).
///
/// For folded-global coordinates, use timeline_folding_utils.dart instead.

const double kHourHeight = 40.0;

/// Converts a Y position within a section to minutes from midnight.
int positionToMinutes(double localY, int sectionStartHour) {
  final minutesFromSectionStart = (localY / kHourHeight * 60).round();
  return sectionStartHour * 60 + minutesFromSectionStart;
}

/// Converts minutes from midnight to a Y position within a section.
double minutesToPosition(int minutes, int sectionStartHour) {
  final minutesFromSectionStart = minutes - (sectionStartHour * 60);
  return minutesFromSectionStart * kHourHeight / 60;
}

/// Snaps minutes to the nearest grid interval.
int snapToGrid(int minutes, {int gridMinutes = 5}) {
  return ((minutes / gridMinutes).round() * gridMinutes).clamp(0, 24 * 60);
}

/// Clamps minutes to section bounds.
int clampToSection(int minutes, int sectionStartHour, int sectionEndHour) {
  final minMinutes = sectionStartHour * 60;
  final maxMinutes = sectionEndHour * 60;
  return minutes.clamp(minMinutes, maxMinutes);
}
```

### No Changes Needed

- `unified_daily_os_data_controller.dart` - `updatePlannedBlock()` already exists
- `planned_block_edit_modal.dart` - Continues working for double-tap/long-press
- `day_plan.dart` - `PlannedBlock.copyWith()` already supports updates
- `timeline_folding_utils.dart` - Not modified; drag uses section-local math only

---

## 8. Implementation Steps

### Phase 0: Page Restructuring
1. Convert `DailyOsPage` from `ConsumerWidget` to `ConsumerStatefulWidget`
2. Add `ScrollController _scrollController` and dispose it properly
3. Add `bool _isDragActive` state
4. Add `_onDragActiveChanged(bool)` callback
5. Update `SingleChildScrollView` to use controller and conditional physics
6. Add `onDragActiveChanged` prop to `DailyTimeline` widget call

### Phase 1: Foundation
1. Create `PlannedBlockDragState` class and `PlannedBlockDragMode` enum in `planned_block_drag_state.dart`
2. Create `drag_position_utils.dart` with **section-local** helpers:
   - `minutesToPosition(int minutes, int sectionStartHour)`
   - `positionToMinutes(double localY, int sectionStartHour)`
   - `snapToGrid(int minutes, {int gridMinutes = 5})`
   - `clampToSection(int minutes, int sectionStartHour, int sectionEndHour)`
3. Add `blockOverlapsCompressedRegion()` to `timeline_folding_utils.dart` (minute-accurate)
4. Add constants:
   ```dart
   const kResizeHandleHeightDesktop = 12.0;
   const kResizeHandleHeightTouch = 20.0;
   const kMinimumBlockMinutes = 15;
   const kMinimumBlockHeightForResize = 48.0;
   const kSnapToMinutes = 5;
   ```

### Phase 2: Callback Propagation
1. Add `onDragActiveChanged` prop to:
   - `DailyTimeline`
   - `_TimelineContent`
   - `_FoldedTimelineGrid`
   - `_VisibleTimelineSection`
2. Add `sectionStartHour` and `sectionEndHour` props to planned block widget
3. Pass values through the widget tree

### Phase 3: Widget Extraction
1. Extract `_PlannedBlockWidget` to new file `draggable_planned_block.dart`
2. Rename to `DraggablePlannedBlock` (public)
3. Convert to `ConsumerStatefulWidget`
4. Add state: `PlannedBlockDragState? _dragState`, `bool _isLongPressActive`
5. Add props: `onDragActiveChanged`, `sectionStartHour`, `sectionEndHour`

### Phase 4: Gesture Recognition
1. Replace `GestureDetector` with `GestureDetector` using `onLongPressStart`/`onLongPressMoveUpdate`/`onLongPressEnd`
   - Simpler than `RawGestureDetector` for this use case
   - Long-press naturally disambiguates from tap/double-tap
2. Detect zone at `onLongPressStart` position
3. Implement zone detection based on platform (touch vs pointer)

### Phase 5: Drag Handling
1. Implement `_handleLongPressStart()`:
   - Check `blockOverlapsCompressedRegion()` - if true, show tooltip and return
   - Detect zone based on local position and platform
   - Initialize `PlannedBlockDragState` with current block times
   - Trigger haptic feedback (light impact)
   - Call `widget.onDragActiveChanged(true)` to lock scroll
2. Implement `_handleLongPressMoveUpdate()`:
   - Calculate delta from drag start
   - Apply section-bounded constraints using `clampToSection()`
   - Snap to grid using `snapToGrid()`
   - Update local state
   - Show boundary hint if at section edge
3. Implement `_handleLongPressEnd()`:
   - Call `updatePlannedBlock()` with converted DateTime values
   - Clear drag state
   - Call `widget.onDragActiveChanged(false)` to unlock scroll
4. Handle cancellation (drag moved off widget, etc.):
   - Restore original position
   - Unlock scroll

### Phase 6: Section-Bounded Position Calculations
```dart
void _updateMovePosition(Offset globalDelta) {
  final deltaMinutes = (globalDelta.dy / kHourHeight * 60).round();
  final duration = _dragState!.currentEndMinutes - _dragState!.currentStartMinutes;

  var newStartMinutes = _originalStartMinutes + deltaMinutes;
  newStartMinutes = snapToGrid(newStartMinutes);

  // Clamp to section bounds (key difference from original plan)
  final sectionStartMinutes = widget.sectionStartHour * 60;
  final sectionEndMinutes = widget.sectionEndHour * 60;
  newStartMinutes = newStartMinutes.clamp(
    sectionStartMinutes,
    sectionEndMinutes - duration,
  );

  final newEndMinutes = newStartMinutes + duration;

  // Detect if at boundary
  final atBoundary = newStartMinutes == sectionStartMinutes ||
      newEndMinutes == sectionEndMinutes;

  setState(() {
    _dragState = _dragState!.copyWith(
      currentStartMinutes: newStartMinutes,
      currentEndMinutes: newEndMinutes,
    );
    _isAtSectionBoundary = atBoundary;
  });
}
```

### Phase 7: DateTime Conversion & Persistence
```dart
Future<void> _commitDrag() async {
  if (_dragState == null) return;

  final updatedBlock = _dragState!.originalBlock.copyWith(
    startTime: _dragState!.startDateTime,
    endTime: _dragState!.endDateTime,
  );

  await ref.read(
    unifiedDailyOsDataControllerProvider(date: widget.date).notifier,
  ).updatePlannedBlock(updatedBlock);
}
```

### Phase 8: Visual Feedback
1. Add `DragTimeIndicator` widget showing time labels at top/bottom of block
2. Add resize handle visual affordances (conditional on hover/focus)
3. Add elevated styling during drag with `RepaintBoundary`
4. Add haptic feedback on snap boundaries
5. Add boundary hint (toast/overlay) when `_isAtSectionBoundary` is true

### Phase 9: Testing
1. Unit tests for `drag_position_utils.dart`:
   - `snapToGrid()`
   - `clampToSection()`
   - `positionToMinutes()` / `minutesToPosition()`
2. Unit tests for `blockOverlapsCompressedRegion()` (minute-accurate boundary cases)
3. Widget tests for each drag mode (move, resize-top, resize-bottom)
4. Widget tests for gesture disambiguation (tap vs double-tap vs long-press-drag)
5. Widget tests for small block handling (move-only mode)
6. Widget tests for section boundary clamping
7. Integration test for full drag flow with persistence verification

### Phase 10: Future Enhancement - Auto-Scroll (Optional)
1. Pass `ScrollController` through widget tree
2. Implement edge detection during drag
3. Use `AnimationController` for smooth scroll animation
4. This is **optional** for initial release since section-bounded drag is usable without it

---

## 9. Key Code Snippets

### Gesture Detection with GestureDetector

Using standard `GestureDetector` with long-press handlers - simpler than `RawGestureDetector` since long-press naturally disambiguates from tap/double-tap:

```dart
GestureDetector(
  onTap: _handleTap,
  onDoubleTap: _handleDoubleTap,
  onLongPressStart: _handleLongPressStart,
  onLongPressMoveUpdate: _handleLongPressMoveUpdate,
  onLongPressEnd: _handleLongPressEnd,
  onLongPressCancel: _handleLongPressCancel,
  child: // ... block content
)
```

**Note**: Flutter's `GestureDetector` automatically handles the disambiguation between tap and long-press. A tap only fires if the press duration is < 500ms and no drag occurs. Long-press fires after 500ms hold (can be customized via `LongPressGestureRecognizer.duration`).

### Zone Detection

```dart
PlannedBlockDragMode _detectZone(double localY, double blockHeight) {
  final handleHeight = _isTouch
      ? _resizeHandleHeightTouch
      : _resizeHandleHeightDesktop;

  // Small blocks: move only
  if (blockHeight < _minimumBlockHeightForResize) {
    return PlannedBlockDragMode.move;
  }

  if (localY < handleHeight) {
    return PlannedBlockDragMode.resizeTop;
  } else if (localY > blockHeight - handleHeight) {
    return PlannedBlockDragMode.resizeBottom;
  } else {
    return PlannedBlockDragMode.move;
  }
}
```

### Snap to Grid

```dart
int _snapToGrid(int minutes) {
  return ((minutes / _snapToMinutes).round() * _snapToMinutes)
      .clamp(0, 24 * 60);
}
```

### Move Position Update (Section-Bounded)

```dart
void _updateMovePosition(double deltaY) {
  final deltaMinutes = (deltaY / kHourHeight * 60).round();
  final duration = _dragState!.currentEndMinutes - _dragState!.currentStartMinutes;

  var newStartMinutes = _originalStartMinutes + deltaMinutes;
  newStartMinutes = snapToGrid(newStartMinutes);

  // Section-bounded clamping (not just day bounds)
  final sectionStartMinutes = widget.sectionStartHour * 60;
  final sectionEndMinutes = widget.sectionEndHour * 60;
  newStartMinutes = newStartMinutes.clamp(
    sectionStartMinutes,
    sectionEndMinutes - duration,
  );

  final newEndMinutes = newStartMinutes + duration;

  // Track if at boundary for hint display
  final atBoundary = newStartMinutes == sectionStartMinutes ||
      newEndMinutes == sectionEndMinutes;

  setState(() {
    _dragState = _dragState!.copyWith(
      currentStartMinutes: newStartMinutes,
      currentEndMinutes: newEndMinutes,
    );
    _isAtSectionBoundary = atBoundary;
  });

  if (atBoundary && !_hasShownBoundaryHint) {
    _showBoundaryHint();
    _hasShownBoundaryHint = true;
  }
}
```

### Resize Update (Section-Bounded)

```dart
void _updateResizeTop(double deltaY) {
  final deltaMinutes = (deltaY / kHourHeight * 60).round();

  var newStartMinutes = _originalStartMinutes + deltaMinutes;
  newStartMinutes = snapToGrid(newStartMinutes);

  // Enforce minimum duration AND section bounds
  final minStart = widget.sectionStartHour * 60;
  final maxStart = _dragState!.currentEndMinutes - kMinimumBlockMinutes;
  newStartMinutes = newStartMinutes.clamp(minStart, maxStart);

  setState(() {
    _dragState = _dragState!.copyWith(currentStartMinutes: newStartMinutes);
    _isAtSectionBoundary = newStartMinutes == minStart;
  });
}

void _updateResizeBottom(double deltaY) {
  final deltaMinutes = (deltaY / kHourHeight * 60).round();

  var newEndMinutes = _originalEndMinutes + deltaMinutes;
  newEndMinutes = snapToGrid(newEndMinutes);

  // Enforce minimum duration AND section bounds
  final minEnd = _dragState!.currentStartMinutes + kMinimumBlockMinutes;
  final maxEnd = widget.sectionEndHour * 60;
  newEndMinutes = newEndMinutes.clamp(minEnd, maxEnd);

  setState(() {
    _dragState = _dragState!.copyWith(currentEndMinutes: newEndMinutes);
    _isAtSectionBoundary = newEndMinutes == maxEnd;
  });
}
```

---

## 10. Accessibility

### Keyboard Support (Future Enhancement)

Not in initial scope, but design allows for future addition:
- Focus block with Tab
- Arrow keys to move/resize
- Enter to confirm, Escape to cancel

### Screen Reader

- Blocks have semantic labels: "Planned block: [Category] from [start] to [end]"
- Drag operations announce: "Moving block", "Block moved to [new time]"

### Reduced Motion

- Respect `MediaQuery.of(context).disableAnimations`
- Skip elevation/scale animations when reduced motion preferred

---

## 11. Verification Plan

1. **Manual Testing**:

   **Core Drag Operations:**
   - Long-press + drag block body: verify entire block moves, duration unchanged
   - Long-press + drag top edge: verify start time changes, end time fixed
   - Long-press + drag bottom edge: verify end time changes, start time fixed
   - Verify minimum duration constraint (15 min)
   - Verify snap-to-grid (5 min intervals)

   **Gesture Disambiguation:**
   - Verify tap still highlights category (no drag initiated)
   - Verify double-tap still opens edit modal
   - Verify short press (< 500ms) doesn't initiate drag

   **Section-Bounded Behavior:**
   - Drag block to top of section: verify clamped at `sectionStartHour`
   - Drag block to bottom of section: verify clamped at `sectionEndHour`
   - Verify boundary hint appears when hitting section edge
   - Verify hint suggests expanding timeline

   **Folding Interaction:**
   - Block overlapping compressed region: verify drag disabled, tooltip shown
   - Block fully in visible section: verify drag works normally
   - After expanding a compressed region: verify block can now be dragged into it

   **Edge Cases:**
   - Small blocks (< 72 min / 48px): verify move-only, no resize handles
   - Block at section boundary: verify can resize inward but not outward

   **Scroll Behavior:**
   - Verify scroll is locked during drag (can't scroll while dragging)
   - Verify scroll unlocks after drag completes

   **Platform Testing:**
   - iOS: verify 20px touch targets, haptic feedback
   - Android: verify 20px touch targets, haptic feedback
   - Desktop (macOS): verify 12px hit zones, cursor changes on hover

2. **Automated Tests**:
   - Unit tests for `drag_position_utils.dart`:
     - `snapToGrid()` with various inputs
     - `clampToSection()` boundary cases
     - `positionToMinutes()` / `minutesToPosition()` roundtrip
   - Unit tests for `blockOverlapsCompressedRegion()`:
     - Block fully before compressed region → false
     - Block fully after compressed region → false
     - Block overlaps start of region → true
     - Block overlaps end of region → true
     - Block at exact boundary (9:00 block, 9:00 compressed start) → true
     - Expanded region → false (should not block drag)
   - Widget tests for each drag mode (move, resize-top, resize-bottom)
   - Widget tests for gesture disambiguation
   - Widget tests for section boundary clamping
   - Widget tests for small block move-only mode
   - Integration test: drag → persist → verify DateTime values
   - Run with `fvm flutter test test/features/daily_os/`

3. **Analyzer/Formatter**:
   - Run `mcp__dart-mcp-local__analyze_files`
   - Run `mcp__dart-mcp-local__dart_format`
   - Run `mcp__dart-mcp-local__dart_fix`

---

## 12. Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Gesture conflicts break existing tap/double-tap | Use standard `GestureDetector` long-press (naturally disambiguates); extensive testing |
| Performance issues during drag | `RepaintBoundary`, limit rebuilds to dragged widget only |
| Scroll interaction bugs | Dedicated scroll lock via `onDragActiveChanged` callback; convert `DailyOsPage` to stateful |
| Timeline folding edge cases | Disable drag for blocks overlapping compressed regions (minute-accurate check); section-bounded drag |
| Section clipping during drag | Section-bounded drag avoids need for overlay; show hint to expand for more range |
| Platform-specific issues | Test on iOS, Android, macOS; platform-adaptive hit zones (12px desktop, 20px touch) |
| Callback propagation complexity | Clear prop threading through widget tree; consider provider-based approach if too verbose |
| DailyOsPage restructuring risk | Minimal change - just add ScrollController and bool state; no logic changes |
