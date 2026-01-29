# Future Date Filtering & Priority Sorting Implementation Plan

**Date:** 2026-01-29
**Status:** Complete

## Problem Statement

Currently, when viewing the Time Budget view for a future date (e.g., Friday Jan 30), the system shows tasks that are "Overdue" from previous days. This pollutes the view for future planning. Users want to see only tasks specifically due on that date when planning ahead, while still seeing all overdue tasks on today's view.

Additionally, the task list lacks priority visibility and proper priority-based sorting.

## Requirements

### 1. Task Filtering Logic

| View Date | Tasks Shown |
|-----------|-------------|
| **Today or Past** | Tasks due today + All overdue tasks |
| **Future Date** | Only tasks due on that specific date (hide overdue) |

### 2. Priority Indicators & Sorting

- Add visual priority indicators (P0, P1, P2, P3) styled like Linear
- Sort tasks by priority (P0 highest, P3 lowest) within the time-spent grouping
- Priority badges should be compact and color-coded

### 3. Administrative

- Capture "Task Pinning" feature for future implementation (manual ordering / "eat the frog")

---

## Implementation Details

### Phase 1: Database Changes

**File:** `lib/database/database.drift`

Add a new query to fetch tasks due on a specific date only:

```sql
tasksDueOn:
SELECT * FROM journal
  WHERE type = 'Task'
  AND deleted = 0
  AND task_status NOT IN ('DONE', 'REJECTED')
  AND json_extract(serialized, '$.data.due') IS NOT NULL
  AND json_extract(serialized, '$.data.due') >= :startDate
  AND json_extract(serialized, '$.data.due') <= :endDate
  AND private IN (0, (SELECT status FROM config_flags WHERE name = 'private'))
  ORDER BY json_extract(serialized, '$.data.due') ASC;
```

**File:** `lib/database/database.dart`

Add a new method:

```dart
/// Returns tasks that are due on the specified date only.
/// Excludes completed (DONE) and rejected (REJECTED) tasks.
/// Does NOT include overdue tasks from previous days.
Future<List<Task>> getTasksDueOn(DateTime date) async {
  final startOfDay = DateTime(date.year, date.month, date.day);
  final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  final startIso = startOfDay.toIso8601String();
  final endIso = endOfDay.toIso8601String();

  final res = await tasksDueOn(startIso, endIso).get();
  return res.map(fromDbEntity).whereType<Task>().toList();
}
```

### Phase 2: Controller Changes

**File:** `lib/features/daily_os/state/unified_daily_os_data_controller.dart`

Modify `_fetchAllData()` to conditionally fetch tasks:

```dart
Future<DailyOsData> _fetchAllData() async {
  // ... existing code ...

  final db = getIt<JournalDb>();
  final dayStart = _date.dayAtMidnight;
  final dayEnd = dayStart.add(const Duration(days: 1));

  // Determine if selected date is today or future
  final today = DateTime.now();
  final todayStart = DateTime(today.year, today.month, today.day);
  final selectedDateStart = DateTime(_date.year, _date.month, _date.day);
  final isFutureDate = selectedDateStart.isAfter(todayStart);

  // Fetch appropriate tasks based on date
  final List<Task> dueTasks;
  if (isFutureDate) {
    // Future dates: Only show tasks due ON that specific day
    dueTasks = await db.getTasksDueOn(_date);
  } else {
    // Today or past: Show tasks due on/before (includes overdue)
    dueTasks = await db.getTasksDueOnOrBefore(_date);
  }

  // ... rest of method remains the same ...
}
```

### Phase 3: Priority Sorting

**File:** `lib/features/daily_os/state/unified_daily_os_data_controller.dart`

Update the sorting logic in `_buildBudgetProgress()`:

```dart
// Re-sort: time descending, then priority, then urgency, then alphabetical
mergedTaskItems.sort((a, b) {
  // Both have time: sort by time descending
  if (a.timeSpentOnDay > Duration.zero && b.timeSpentOnDay > Duration.zero) {
    return b.timeSpentOnDay.compareTo(a.timeSpentOnDay);
  }
  // One has time, one doesn't: time first
  if (a.timeSpentOnDay > Duration.zero) return -1;
  if (b.timeSpentOnDay > Duration.zero) return 1;

  // Both zero time: sort by priority first (lower rank = higher priority)
  final priorityCompare = a.task.data.priority.rank.compareTo(b.task.data.priority.rank);
  if (priorityCompare != 0) return priorityCompare;

  // Same priority: sort by urgency (overdue > dueToday > normal)
  final urgencyCompare = b.dueDateStatus.urgency.index.compareTo(a.dueDateStatus.urgency.index);
  if (urgencyCompare != 0) return urgencyCompare;

  // Same urgency: alphabetical by title
  return a.task.data.title.compareTo(b.task.data.title);
});
```

### Phase 4: Priority Badge UI

**File:** `lib/features/daily_os/ui/widgets/time_budget_card.dart`

Add a new priority badge widget:

```dart
/// Compact priority badge styled like Linear.
class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    final color = priority.colorForBrightness(Theme.of(context).brightness);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        priority.short,
        style: context.textTheme.labelSmall?.copyWith(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
```

Update `_TaskProgressRow` to include priority badge:

```dart
// Priority badge (after status indicator, before due badge)
if (task.data.priority != TaskPriority.p2Medium) ...[
  const SizedBox(width: 4),
  _PriorityBadge(priority: task.data.priority),
],
```

Update `_TaskGridTile` to include priority badge in the top corner.

---

## Files to Modify

1. `lib/database/database.drift` - Add new SQL query
2. `lib/database/database.dart` - Add `getTasksDueOn()` method
3. `lib/features/daily_os/state/unified_daily_os_data_controller.dart`:
   - Modify `_fetchAllData()` for conditional filtering
   - Update sorting logic for priority
4. `lib/features/daily_os/ui/widgets/time_budget_card.dart`:
   - Add `_PriorityBadge` widget
   - Update `_TaskProgressRow` to show priority
   - Update `_TaskGridTile` to show priority

## Tests to Add/Update

1. `test/features/daily_os/state/unified_daily_os_data_controller_test.dart`:
   - Test that future dates only show tasks due on that day
   - Test that today shows tasks due today + overdue
   - Test priority sorting works correctly

---

## Future Work: Task Pinning

**Note for later implementation:**

- Allow users to "pin" tasks to manually order them at the top
- Support "Eat the Frog" workflow - highlight the most important task
- Pinned tasks should override automatic sorting
- Store pin order in `DayPlanEntry` data

This feature is captured here but NOT implemented in this PR.

---

## Checklist

- [x] Add `tasksDueOn` SQL query to database.drift
- [x] Add `getTasksDueOn()` method to JournalDb
- [x] Modify `_fetchAllData()` to conditionally fetch based on date
- [x] Update sorting logic for priority
- [x] Add `_PriorityBadge` widget
- [x] Update `_TaskProgressRow` with priority badge
- [x] Update `_TaskGridTile` with priority badge
- [x] Add tests for future date filtering
- [x] Add tests for priority sorting
- [x] Run analyzer, formatter, and tests
