# Implementation Plan: Visualizing Tracked Tasks in Time Budgets

**Date:** 2026-01-27
**Feature:** Display tasks within Time Budget categories with thumbnails, time spent, and completion indicators

## Overview

Add task visualization within Time Budget categories showing:
- Square thumbnail (if available)
- Task title
- Time spent on that day
- Completion indicator (checkmark if task was marked Done on that specific day)

Tasks are displayed in a **collapsible section** (default expanded) that users can close for focus.

## Design Decisions

| Question | Decision |
|----------|----------|
| Multi-category tasks | N/A - tasks belong to a single category |
| Zero-time tasks | Show if completed today (completion is noteworthy) |
| Sort order | Time descending; completed-today with zero time at end |
| Pinned tasks | **Deferred** - pinning mechanism not yet implemented |
| Task row format | Enhanced format with thumbnails and time |
| Expandable state | Session only (widget state, resets on navigation) |

## Current State Analysis

**What exists:**
- `TimeBudgetProgress.contributingTasks` getter - **currently broken** (filters entries by type, but time entries aren't Tasks)
- `_PinnedTaskRow` widget renders tasks with status circle + title + chevron
- `CoverArtThumbnail` widget exists for rendering task thumbnails (requires non-null `imageId`)
- `TaskStatus.createdAt` tracks when each status was set (completion tracking works)
- `linkedFromMap` in controller maps entry IDs to their parent entities (including Tasks)

**What's missing:**
- Per-task time calculation (how much time spent on each task today)
- Completion-on-day check (task marked Done today vs earlier)
- Thumbnail display in task rows
- Time duration display in task rows
- Collapsible task section

## Architecture Summary

**Data Flow:**
- `UnifiedDailyOsDataController` fetches all entries and links for the day
- `_buildBudgetProgress()` groups entries by category (using parent task's category)
- `linkedFromMap` maps entry IDs to their parent tasks
- `TimeBudgetCard` renders progress bars and task list

**Key Discovery - Completion Tracking:**
- `TaskStatus.createdAt` tracks when a status was set
- Can verify if `TaskDone` status was set on the target day via pattern matching
- This is per the user's requirement: completion only counts on the day it happened

## Files to Modify

### 1. `lib/features/daily_os/state/time_budget_progress_controller.dart`

Add new `TaskDayProgress` class:
```dart
/// Progress data for a single task on a specific day.
class TaskDayProgress {
  const TaskDayProgress({
    required this.task,
    required this.timeSpentOnDay,
    required this.wasCompletedOnDay,
  });

  final Task task;
  final Duration timeSpentOnDay;
  final bool wasCompletedOnDay;
}
```

Update `TimeBudgetProgress`:
```dart
/// Tasks with tracked time or completed today, sorted by time descending.
final List<TaskDayProgress> taskProgressItems;
```

Remove or deprecate:
- `contributingTasks` getter (broken, replaced by `taskProgressItems`)

### 2. `lib/features/daily_os/state/unified_daily_os_data_controller.dart`

Add helper method with correct pattern matching:
```dart
bool _wasCompletedOnDay(Task task, DateTime day) {
  final status = task.data.status;
  if (status is! TaskDone) return false;
  final doneAt = status.createdAt;  // Pattern match gives us TaskDone
  return doneAt.year == day.year &&
         doneAt.month == day.month &&
         doneAt.day == day.day;
}
```

Modify `_buildBudgetProgress()` to:
1. Build reverse map: `taskId -> List<JournalEntity>` for time entries linked to each task
2. For each unique task (from linkedFromMap):
   - Calculate `timeSpentOnDay` by summing linked entry durations
   - Check if task was completed on `_date` using `_wasCompletedOnDay()`
3. **Include task if**: `timeSpentOnDay > 0` OR `wasCompletedOnDay`
4. Sort: time descending, then zero-time completed tasks at end
5. Construct `TaskDayProgress` objects

### 3. `lib/features/daily_os/ui/widgets/time_budget_card.dart`

**Create `_TaskProgressRow` widget:**

Layout (left to right):
- **Thumbnail** (40x40): `CoverArtThumbnail` if `task.data.coverArtId != null`, otherwise colored status circle
- **Title**: Task name, single line with ellipsis
- **Time**: Duration formatted as "Xh Ym" or "Xm", right-aligned (reuse existing `_formatDuration`)
- **Checkmark**: Green `Icons.check_circle` (24x24) if `wasCompletedOnDay == true`

Styling:
- Completed tasks: slightly muted text, italic
- Time text: `labelSmall`, muted color
- Zero time: show "0m" (for tasks completed today with no tracking)
- Checkmark: `taskStatusGreen` / `taskStatusDarkGreen` based on brightness

**Create `_ExpandableTaskSection` widget:**

Header format: `"Tasks (N) • Xh Ym"` where:
- N = `tasks.length`
- Total time = sum of all `task.timeSpentOnDay`

```dart
class _ExpandableTaskSection extends StatefulWidget {
  const _ExpandableTaskSection({required this.tasks});
  final List<TaskDayProgress> tasks;
}

class _ExpandableTaskSectionState extends State<_ExpandableTaskSection> {
  bool _isExpanded = true;  // Default open

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header row: "Tasks (3) • 2h 15m" with expand/collapse chevron
        GestureDetector(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: _buildHeader(),
        ),
        // Animated task list
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          clipBehavior: Clip.hardEdge,
          child: _isExpanded ? _buildTaskList() : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
```

**Update `TimeBudgetCard.build()`:**
- Remove existing `contributingTasks` section
- Add `_ExpandableTaskSection` using `progress.taskProgressItems`
- Hide section entirely when `taskProgressItems` is empty

## Implementation Steps

### Step 1: Data Model (time_budget_progress_controller.dart)
- Add `TaskDayProgress` class
- Add `taskProgressItems` field to `TimeBudgetProgress`
- Remove broken `contributingTasks` getter

### Step 2: Controller Logic (unified_daily_os_data_controller.dart)
- Add `_wasCompletedOnDay()` helper with correct pattern matching
- Modify `_buildBudgetProgress()`:
  - Build task ID → entries map from `linkedFromMap`
  - Calculate per-task duration and completion status
  - Filter: include if has time OR completed today
  - Sort by time descending (zero-time completed at end)
  - Build `TaskDayProgress` list

### Step 3: Widget Update (time_budget_card.dart)
- Add import for `CoverArtThumbnail`
- Create `_TaskProgressRow` widget with thumbnail support
- Create `_ExpandableTaskSection` widget with `AnimatedSize`
- Replace existing task sections with single expandable section
- Reuse existing `_formatDuration` helper

### Step 4: Cleanup
- Update `_PinnedTaskRow` to become `_TaskProgressRow` (or replace)
- Update any tests that reference old structure

## Data Flow Detail

```
UnifiedDailyOsDataController._buildBudgetProgress()
├── Build taskIdToEntries map from linkedFromMap
├── For each task in linkedFromMap:
│   ├── Sum entry durations → timeSpentOnDay
│   └── Check _wasCompletedOnDay() → wasCompletedOnDay
├── Filter: timeSpentOnDay > 0 || wasCompletedOnDay
├── Sort: by timeSpentOnDay DESC, zero-time completed at end
└── Build List<TaskDayProgress>
```

## Edge Cases

1. **Task completed today with no time**: Shows with "0m" and checkmark, appears at end of list
2. **Tasks without cover art**: Fall back to status circle (existing pattern)
3. **Entries not linked to tasks**: Contribute to category total but don't appear in task list
4. **Task completed on different day**: `wasCompletedOnDay = false` even if current status is Done
5. **Empty task list**: Hide the expandable section entirely

## Visual Reference

```
┌─────────────────────────────────────────────────┐
│ ■ Deep Work                     +1h 45m over    │
│ 5h 15m planned                                  │
│ ████████████████████████████████████░░░░░░░░░░  │
├─────────────────────────────────────────────────┤
│ Tasks (3) • 4h 30m                          ▼   │
├─────────────────────────────────────────────────┤
│ [img] Task Title Here          2h 15m      ✓    │
│ [●]   Another Task             1h 30m           │
│ [img] Third Task               45m         ✓    │
└─────────────────────────────────────────────────┘

Collapsed state:
┌─────────────────────────────────────────────────┐
│ ■ Deep Work                     +1h 45m over    │
│ 5h 15m planned                                  │
│ ████████████████████████████████████░░░░░░░░░░  │
├─────────────────────────────────────────────────┤
│ Tasks (3) • 4h 30m                          ▶   │
└─────────────────────────────────────────────────┘
```

## Verification

1. **Unit tests**:
   - Test `_wasCompletedOnDay()` with task completed today, yesterday, and not done
   - Test task collection from linkedFromMap
   - Test sorting (time descending, zero-time completed at end)

2. **Widget tests**:
   - Test `_TaskProgressRow` renders correctly with/without thumbnail
   - Test `_TaskProgressRow` shows checkmark only for completed-today
   - Test `_ExpandableTaskSection` expand/collapse behavior
   - Test collapsed state shows correct summary

3. **Manual testing**:
   - Create tasks with different statuses and cover art
   - Track time on tasks under different categories
   - Mark a task as Done and verify checkmark appears only on that day
   - View previous days to verify completion indicator is absent
   - Test expand/collapse interaction

## Commands to Run

```bash
fvm flutter analyze
fvm flutter test
```
