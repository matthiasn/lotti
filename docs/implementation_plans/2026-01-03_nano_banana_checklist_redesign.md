# Nano Banana Checklist Redesign - Implementation Plan

**Date:** 2026-01-03
**Status:** Planned

## Overview

Major UI rewrite of the Checklist section implementing the "Nano Banana" design system with card-based architecture, global sorting mode, and improved interactions.

---

## Current State Analysis

### Key Files
| File | Description |
|------|-------------|
| `lib/features/tasks/ui/checklists/checklists_widget.dart` | Container for all checklists |
| `lib/features/tasks/ui/checklists/checklist_widget.dart` | Single checklist (ExpansionTile-based) |
| `lib/features/tasks/ui/checklists/checklist_item_widget.dart` | Item with CheckboxListTile |
| `lib/features/tasks/ui/checklists/checklist_wrapper.dart` | State wrapper + export/share |
| `lib/features/tasks/ui/checklists/checklist_item_wrapper.dart` | Item drag/delete wrapper |
| `lib/features/tasks/state/checklist_controller.dart` | Riverpod state management |

### Current vs. Target Differences
| Feature | Current | Target (Nano Banana) |
|---------|---------|---------------------|
| Global header | Title + Add + Reorder button | Title + Add (+) + Menu (...) with "Sort checklists" |
| Checklist sorting | Toggle edit mode, drag handles appear | Dedicated sorting mode with Done button |
| Item drag handles | Only visible in edit mode | Always visible on LEFT |
| Add input position | Top of expanded area | Bottom of expanded area |
| Progress ring (expanded) | Always shown (empty text if 0) | Hidden when total = 0 |
| Progress ring (collapsed) | Below title | Inline with title, always visible (even 0/0) |
| Collapsed layout | Title, then progress below | Title + Progress Ring + Chevron + Menu inline |
| Chevron | Default ExpansionTile icon | Rotating 90° animation |
| Filter tabs | SegmentedButton | Plain text tabs with underline |
| Empty state | "No items yet" exists | Keep, ensure centered |

---

## Design Decisions (Confirmed)

1. **Filter tabs:** Replace SegmentedButton with plain text tabs ("Open" / "All") with underline indicator for selected state

2. **New checklist auto-focus:** Yes - new checklist appears expanded with title input auto-focused for immediate naming

3. **Progress visibility:**
   - **Expanded state:** Hide progress ring when total = 0
   - **Collapsed state:** Always show progress ring + "0/0 done" (even when empty)

---

## Implementation Plan

### Phase 1: State Management (Foundation)

#### 1.1 Create `ChecklistsSortingController`

**New file:** `lib/features/tasks/state/checklists_sorting_controller.dart`

```dart
// State for global sorting mode
@freezed
class ChecklistsSortingState with _$ChecklistsSortingState {
  const factory ChecklistsSortingState({
    @Default(false) bool isSorting,
    @Default({}) Map<String, bool> preExpansionStates,  // Restore after sort
  }) = _ChecklistsSortingState;
}

// Provider
final checklistsSortingControllerProvider = StateNotifierProvider.autoDispose
    .family<ChecklistsSortingController, ChecklistsSortingState, String>(
  (ref, taskId) => ChecklistsSortingController(),
);
```

**Methods:**
- `enterSortingMode(Map<String, bool> currentExpansionStates)` - Save states, set sorting=true
- `exitSortingMode()` - Set sorting=false (states retained for restoration)

#### 1.2 Update Animation Constants

**File:** `lib/features/tasks/ui/checklists/consts.dart`

Add:
```dart
const checklistChevronRotationDuration = Duration(milliseconds: 200);
const checklistCardCollapseAnimationDuration = Duration(milliseconds: 250);
```

---

### Phase 2: Widget Refactoring

#### 2.1 Refactor `ChecklistsWidget` - Global Header + Sorting Mode

**File:** `lib/features/tasks/ui/checklists/checklists_widget.dart`

**Changes:**

1. Replace reorder IconButton with PopupMenuButton containing "Sort checklists"
2. Watch `checklistsSortingControllerProvider` for sorting state
3. Pass `isSortingMode` flag to child `ChecklistWrapper` widgets
4. When sorting: show "Done" button at bottom

**New header structure:**
```dart
Row(
  children: [
    Text("Checklists"),
    IconButton(icon: Icon(Icons.add_rounded), onPressed: createChecklist),
    PopupMenuButton<String>(
      icon: Icon(Icons.more_vert),
      itemBuilder: (_) => [
        PopupMenuItem(value: 'sort', child: Text('Sort checklists')),
      ],
      onSelected: (value) {
        if (value == 'sort') enterSortingMode();
      },
    ),
  ],
)
```

**Sorting mode UI:**
```dart
if (isSorting) ...[
  // All cards with large drag handles
  // At bottom:
  Padding(
    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    child: SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: exitSortingMode,
        child: Text('Done'),
      ),
    ),
  ),
]
```

#### 2.2 Refactor `ChecklistWidget` - Card Architecture

**File:** `lib/features/tasks/ui/checklists/checklist_widget.dart`

**Major restructure - Replace ExpansionTile with custom implementation:**

```dart
Column(
  children: [
    // HEADER (always visible)
    _ChecklistCardHeader(
      title: title,
      isExpanded: _isExpanded,
      isSortingMode: widget.isSortingMode,
      completedCount: completed,
      totalCount: total,
      onToggleExpand: toggleExpand,
      onTitleTap: () => setState(() => _isEditingTitle = true),
      // ... menu callbacks
    ),

    // BODY (animated visibility)
    AnimatedCrossFade(
      duration: checklistCardCollapseAnimationDuration,
      crossFadeState: _isExpanded && !widget.isSortingMode
          ? CrossFadeState.showFirst
          : CrossFadeState.showSecond,
      firstChild: _ChecklistCardBody(...),
      secondChild: const SizedBox.shrink(),
    ),
  ],
)
```

#### 2.3 Extract `_ChecklistCardHeader` (Private Widget)

**Inside:** `lib/features/tasks/ui/checklists/checklist_widget.dart`

**Layout - Expanded state:**
```
[Title (click to edit)]  [Chevron v]  [Menu ...]
[Progress Ring] X/Y done    [Open] [All]
```

**Layout - Collapsed state:**
```
[Title]  [Progress Ring] X/Y done  [Chevron >]  [Menu ...]
```

**Layout - Sorting mode:**
```
[Drag Handle ::]  [Title]  [Progress Ring] X/Y done
```

**Features:**
- **Title:** Click transforms to TitleTextField (AnimatedCrossFade)
- **Chevron:** RotationTransition (0.0 = down, 0.25 = right)
- **Progress (expanded):** Hide ring AND text when total = 0
- **Progress (collapsed):** Always show, even "0/0 done"
- **Menu:** Hide in sorting mode

**Chevron animation pattern:**
```dart
late final AnimationController _chevronController;
late final Animation<double> _chevronRotation;

// In initState:
_chevronController = AnimationController(
  duration: checklistChevronRotationDuration,
  vsync: this,
  value: widget.isExpanded ? 0.0 : 0.25,
);
_chevronRotation = _chevronController;

// Toggle:
if (expanded) {
  _chevronController.animateTo(0.0);  // Points down
} else {
  _chevronController.animateTo(0.25); // Points right (90°)
}

// Build:
RotationTransition(
  turns: _chevronRotation,
  child: Icon(Icons.expand_more),
)
```

#### 2.4 Extract `_ChecklistCardBody` (Private Widget)

**Inside:** `lib/features/tasks/ui/checklists/checklist_widget.dart`

**Layout:**
```
[Items list with drag handles]
[Empty state OR "All done" message]
[Add input field at BOTTOM]
```

**Key changes:**
- Move add input from top to bottom
- Progress ring + filters already in header (remove from here)

#### 2.5 Implement Filter Tabs

**Replace `SegmentedButton` with custom text tabs:**

```dart
Row(
  children: [
    _FilterTab(
      label: 'Open',
      isSelected: _filter == ChecklistFilter.openOnly,
      onTap: () => setFilter(ChecklistFilter.openOnly),
    ),
    SizedBox(width: 16),
    _FilterTab(
      label: 'All',
      isSelected: _filter == ChecklistFilter.all,
      onTap: () => setFilter(ChecklistFilter.all),
    ),
  ],
)

class _FilterTab extends StatelessWidget {
  // Text with underline decoration when selected
  // Bold weight when selected, normal when not
  // outline color when not selected, onSurface when selected
}
```

#### 2.6 Refactor `ChecklistItemWidget` - Always-Visible Drag Handle

**File:** `lib/features/tasks/ui/checklists/checklist_item_widget.dart`

**Changes:**
- Add drag handle icon (Icons.drag_indicator) on LEFT side
- Always visible (remove conditional based on edit mode)
- Use ReorderableDragStartListener for the handle

**New structure:**
```dart
Row(
  children: [
    // Drag handle - always visible
    ReorderableDragStartListener(
      index: index,  // Need to pass index to widget
      child: Icon(Icons.drag_indicator, size: 20, color: outline),
    ),
    SizedBox(width: 4),
    // Checkbox
    Checkbox(value: isChecked, onChanged: onToggle),
    // Title (expandable)
    Expanded(child: Text(title, ...)),
  ],
)
```

**Note:** Will need to pass `index` through widget hierarchy for ReorderableDragStartListener.

---

### Phase 3: Pass Sorting Mode Through Widget Tree

#### 3.1 Update `ChecklistWrapper`

**File:** `lib/features/tasks/ui/checklists/checklist_wrapper.dart`

Add parameter:
```dart
final bool isSortingMode;
```

Pass to `ChecklistWidget`.

#### 3.2 Update `ChecklistsWidget` Card Generation

Pass `isSortingMode` from provider to each `ChecklistWrapper`:
```dart
ChecklistWrapper(
  entryId: checklistId,
  categoryId: item.categoryId,
  taskId: widget.task.id,
  isSortingMode: sortingState.isSorting,
)
```

---

### Phase 4: Sorting Mode Behavior

#### 4.1 Enter Sorting Mode Flow

1. User taps "Sort checklists" in global menu
2. Controller stores current expansion states for each checklist
3. Sets `isSorting = true`
4. UI updates:
   - All cards collapse (body hidden)
   - Large drag handles appear on LEFT of each card
   - Chevron and menu hidden on each card
   - "Done" button appears at section bottom

#### 4.2 During Sorting

- Cards are reorderable via ReorderableListView (already implemented)
- Large drag handle (28px) on card, item handles still 20px

#### 4.3 Exit Sorting Mode Flow

1. User taps "Done"
2. Controller sets `isSorting = false`
3. Each card reads its pre-sort expansion state and restores it
4. UI returns to normal

**Restoration in `ChecklistWidget.didUpdateWidget`:**
```dart
if (oldWidget.isSortingMode && !widget.isSortingMode) {
  final state = ref.read(checklistsSortingControllerProvider(taskId));
  final wasExpanded = state.preExpansionStates[widget.id] ?? true;
  setState(() => _isExpanded = wasExpanded);
  // Trigger chevron animation accordingly
}
```

---

### Phase 5: Styling Refinements

#### 5.1 Progress Ring Visibility

**In expanded header:** Only show when `totalCount > 0`
```dart
if (totalCount > 0) ...[
  ChecklistProgressIndicator(completionRate: completionRate),
  SizedBox(width: 6),
  Text('$completedCount/$totalCount done'),
]
```

**In collapsed header:** Always show
```dart
ChecklistProgressIndicator(completionRate: completionRate),
SizedBox(width: 6),
Text('$completedCount/$totalCount done'),
```

#### 5.2 Collapsed Header Layout

Horizontal row with:
- Title (flex: expanded)
- Progress ring + text
- Chevron (rotated 90° right)
- Menu button

#### 5.3 Drag Handle Styling

```dart
Icon(
  Icons.drag_indicator,
  size: 20,  // Item level
  // size: 28 for card sorting mode
  color: colorScheme.outline.withValues(alpha: 0.6),
)
```

---

### Phase 6: Testing

#### 6.1 Update Existing Tests

| Test File | Updates Needed |
|-----------|----------------|
| `checklists_widget_test.dart` | Add sorting mode tests, menu interaction |
| `checklist_widget_test.dart` | Update for new card architecture |
| `checklist_item_widget_test.dart` | Verify drag handle always visible |

#### 6.2 New Test Cases

- Sorting mode enter/exit
- Expansion state preservation through sorting
- Progress ring hidden when 0 items (expanded)
- Progress ring shown when 0 items (collapsed)
- Chevron rotation animation
- Inline title editing (click to edit)
- Add input at bottom position
- Filter tabs with underline styling

---

## Implementation Order

| Step | Task | Files |
|------|------|-------|
| 1 | Create sorting controller + state | `checklists_sorting_controller.dart` (new) |
| 2 | Add animation constants | `consts.dart` |
| 3 | Refactor `ChecklistWidget` to card architecture | `checklist_widget.dart` |
| 4 | Add always-visible drag handles to items | `checklist_item_widget.dart` |
| 5 | Update `ChecklistWrapper` to pass sorting mode | `checklist_wrapper.dart` |
| 6 | Refactor `ChecklistsWidget` with global menu + sorting UI | `checklists_widget.dart` |
| 7 | Update/add tests | `test/features/tasks/ui/checklists/*` |
| 8 | Run analyzer, formatter, full test suite | - |

---

## Files Summary

### New Files
- `lib/features/tasks/state/checklists_sorting_controller.dart`

### Modified Files
- `lib/features/tasks/ui/checklists/checklists_widget.dart` - Global header, sorting mode
- `lib/features/tasks/ui/checklists/checklist_widget.dart` - Card architecture (major)
- `lib/features/tasks/ui/checklists/checklist_wrapper.dart` - Pass sorting mode
- `lib/features/tasks/ui/checklists/checklist_item_widget.dart` - Always-visible drag handle
- `lib/features/tasks/ui/checklists/consts.dart` - Animation constants

### Test Files to Update
- `test/features/tasks/ui/checklists/checklists_widget_test.dart`
- `test/features/tasks/ui/checklists/checklist_widget_test.dart`
- `test/features/tasks/ui/checklists/checklist_item_widget_test.dart`
