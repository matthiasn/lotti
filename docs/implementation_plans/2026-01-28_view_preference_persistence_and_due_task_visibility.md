# View Preference Persistence & Due Task Visibility

**Date:** 2026-01-28
**Status:** Implemented
**Version:** 0.9.828
**Related PRs:** #2612 (Day View Lanes), #2611 (Unified Data Controller)

## Overview

This plan addresses two requirements for the Daily Operating System time budgets:
1. **View Preference Persistence** - Persist List/Grid view selection per category in local settings
2. **Due Task Visibility** - Auto-include tasks due on the selected day with visual indicators

---

## Part 1: View Preference Persistence (List vs. Grid)

### Current State

- **File**: `lib/features/daily_os/ui/widgets/time_budget_card.dart`
  - `enum _TaskViewMode { list, grid }` at line 337
  - `_ExpandableTaskSection` class at lines 340-347
  - State variables at lines 350-351: `_isExpanded`, `_viewMode`
  - `_TaskProgressRow` at lines 472-535
  - `_TaskGridTile` at lines 538-659
- View mode is currently stored as local widget state (`_viewMode = _TaskViewMode.grid`)
- No persistence mechanism exists
- Default is `grid` view

### Requirements

- **Default View:** Change from Grid to **List**
- **Persistence Scope:** Per **Category**, not per task or budget instance
- **Storage:** Local `settings` database (not synced across devices)

### Implementation Steps

#### 1.1 Create View Preference Controller

**New file:** `lib/features/daily_os/state/task_view_preference_controller.dart`

```dart
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'task_view_preference_controller.g.dart';

/// View modes for task display in time budget cards.
enum TaskViewMode { list, grid }

/// Settings key pattern for category view preferences.
String _settingsKey(String categoryId) => 'time_budget_view_$categoryId';

/// Controller for persisting task view mode preferences per category.
@riverpod
class TaskViewPreference extends _$TaskViewPreference {
  late SettingsDb _settingsDb;
  late String _categoryId;

  @override
  Future<TaskViewMode> build({required String categoryId}) async {
    _settingsDb = getIt<SettingsDb>();
    _categoryId = categoryId; // Store for use in toggle()
    final stored = await _settingsDb.itemByKey(_settingsKey(categoryId));
    return stored == 'grid' ? TaskViewMode.grid : TaskViewMode.list;
  }

  Future<void> toggle() async {
    final current = state.valueOrNull ?? TaskViewMode.list;
    final newMode = current == TaskViewMode.list
        ? TaskViewMode.grid
        : TaskViewMode.list;

    await _settingsDb.saveSettingsItem(
      _settingsKey(_categoryId), // Use stored field, not arg.categoryId
      newMode == TaskViewMode.grid ? 'grid' : 'list',
    );
    state = AsyncData(newMode);
  }
}
```

#### 1.2 Modify `_ExpandableTaskSection`

**File:** `lib/features/daily_os/ui/widgets/time_budget_card.dart`

Changes:
- Convert from `StatefulWidget` to `ConsumerStatefulWidget`
- Accept `categoryId` as required parameter
- Watch the preference provider instead of local state
- Remove local `_viewMode` state variable

```dart
class _ExpandableTaskSection extends ConsumerStatefulWidget {
  const _ExpandableTaskSection({
    required this.tasks,
    required this.categoryId,
  });

  final List<TaskDayProgress> tasks;
  final String categoryId;

  @override
  ConsumerState<_ExpandableTaskSection> createState() =>
      _ExpandableTaskSectionState();
}

class _ExpandableTaskSectionState extends ConsumerState<_ExpandableTaskSection> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final viewModeAsync = ref.watch(
      taskViewPreferenceProvider(categoryId: widget.categoryId),
    );
    final viewMode = viewModeAsync.valueOrNull ?? TaskViewMode.list;

    // ... rest of build method using viewMode
  }
}
```

#### 1.3 Update `TimeBudgetCard`

Pass `categoryId` to `_ExpandableTaskSection`:

```dart
_ExpandableTaskSection(
  tasks: progress.taskProgressItems,
  categoryId: progress.categoryId,
)
```

---

## Part 2: Due Task Visibility

### Current State

- **File**: `lib/features/daily_os/state/unified_daily_os_data_controller.dart`
- Tasks are only shown if they have tracked time OR were completed on the day
- No due date integration exists
- No synthetic categories for unplanned budgets

### Requirements

- **Auto-Inclusion:** Tasks due on a specific day must appear under their category's time budget
- **No Budget Handling:** Categories with due tasks but no planned budget must appear with "0 minutes planned" and a warning indicator
- **Visual Markers:** Tasks that are "due" should have distinct visual indicators

### Implementation Steps

#### 2.1 Add Database Query for Due Tasks

**File:** `lib/database/database.dart`

Add method to query tasks by due date using JSON extraction:

```dart
/// Returns tasks with a due date on the specified day.
/// Excludes completed (Done) and rejected tasks.
Future<List<Task>> getTasksDueOn(DateTime date) async {
  final dayStart = DateTime(date.year, date.month, date.day);
  final dayEnd = dayStart.add(const Duration(days: 1));

  // Format dates as ISO strings for JSON comparison
  final startIso = dayStart.toIso8601String().substring(0, 10);
  final endIso = dayEnd.toIso8601String().substring(0, 10);

  final res = await tasksDueOnDate(startIso, endIso).get();
  return res.map(fromDbEntity).whereType<Task>().toList();
}
```

**File:** `lib/database/database.drift`

Add SQL query (uses denormalized `task_status` column for status filtering):

```sql
tasksDueOnDate:
  SELECT * FROM journal
  WHERE type = 'Task'
    AND deleted = 0
    AND task_status NOT IN ('DONE', 'REJECTED')
    AND json_extract(serialized, '$.data.due') >= :startDate
    AND json_extract(serialized, '$.data.due') < :endDate
  ORDER BY json_extract(serialized, '$.data.due') ASC;
```

> **Note:** Task status values are stored as denormalized strings: `'OPEN'`, `'GROOMED'`, `'IN PROGRESS'`, `'BLOCKED'`, `'ON HOLD'`, `'DONE'`, `'REJECTED'` (see `task.dart:225-232`).

#### 2.2 Extend `TaskDayProgress` Model

**File:** `lib/features/daily_os/state/time_budget_progress_controller.dart`

Add `dueDateStatus` field using existing `DueDateStatus` class from `lib/features/tasks/util/due_date_utils.dart`:

```dart
import 'package:lotti/features/tasks/util/due_date_utils.dart';

class TaskDayProgress {
  const TaskDayProgress({
    required this.task,
    required this.timeSpentOnDay,
    required this.wasCompletedOnDay,
    this.dueDateStatus = const DueDateStatus.none(),
  });

  final Task task;
  final Duration timeSpentOnDay;
  final bool wasCompletedOnDay;

  /// Due date status relative to the day being viewed.
  /// Use `dueDateStatus.isUrgent` to check if due/overdue.
  /// Use `dueDateStatus.urgentColor` for badge coloring (red=overdue, orange=dueToday).
  final DueDateStatus dueDateStatus;

  /// Convenience getter for UI checks.
  bool get isDueOrOverdue => dueDateStatus.isUrgent;
}
```

> **Note:** Using `DueDateStatus` instead of a boolean allows distinguishing "due today" (orange) from "overdue" (red) in the UI, leveraging existing color scheme from `lib/themes/colors.dart`.

#### 2.3 Extend `TimeBudgetProgress` Model

**File:** `lib/features/daily_os/state/time_budget_progress_controller.dart`

Add `hasNoBudgetWarning` field:

```dart
class TimeBudgetProgress {
  const TimeBudgetProgress({
    required this.categoryId,
    required this.category,
    required this.plannedDuration,
    required this.recordedDuration,
    required this.status,
    required this.contributingEntries,
    required this.taskProgressItems,
    required this.blocks,
    this.hasNoBudgetWarning = false,
  });

  // ... existing fields ...

  /// True if this category has due tasks but zero planned time.
  final bool hasNoBudgetWarning;
}
```

#### 2.4 Modify `UnifiedDailyOsDataController._fetchAllData()`

**File:** `lib/features/daily_os/state/unified_daily_os_data_controller.dart`

Fetch due tasks in parallel with existing queries:

```dart
Future<DailyOsData> _fetchAllData() async {
  // ... existing code ...

  // Fetch day plan, calendar entries, and due tasks in parallel
  final results = await Future.wait([
    _dayPlanRepository.getOrCreateDayPlan(_date),
    db.sortedCalendarEntries(rangeStart: dayStart, rangeEnd: dayEnd),
    db.getTasksDueOn(_date), // NEW
  ]);

  final dayPlan = results[0] as DayPlanEntry;
  final entries = results[1] as List<JournalEntity>;
  final dueTasks = results[2] as List<Task>; // NEW

  // ... rest of method, passing dueTasks to _buildBudgetProgress
}
```

#### 2.5 Modify `_buildBudgetProgress()`

Merge due tasks into budget progress and create synthetic entries. **Key requirement:** Handle deduplication when a task has both tracked time AND is due on the day.

```dart
List<TimeBudgetProgress> _buildBudgetProgress({
  required DayPlanEntry dayPlan,
  required List<JournalEntity> entries,
  required Map<String, Set<String>> entryIdToLinkedFromIds,
  required Map<String, JournalEntity> linkedFromMap,
  required List<Task> dueTasks, // NEW parameter
}) {
  final derivedBudgets = dayPlan.data.derivedBudgets;
  final budgetCategoryIds = derivedBudgets.map((b) => b.categoryId).toSet();

  // Create lookup for due tasks by ID for deduplication
  final dueTasksById = <String, Task>{
    for (final task in dueTasks) task.meta.id: task,
  };

  // Group due tasks by category
  final dueTasksByCategory = <String, List<Task>>{};
  for (final task in dueTasks) {
    final categoryId = task.meta.categoryId;
    if (categoryId != null) {
      dueTasksByCategory.putIfAbsent(categoryId, () => []).add(task);
    }
  }

  // Find categories with due tasks but no budget
  final categoriesNeedingSyntheticBudget = dueTasksByCategory.keys
      .where((catId) => !budgetCategoryIds.contains(catId))
      .toSet();

  final results = <TimeBudgetProgress>[];

  // Build progress for existing budgets (include due tasks)
  for (final budget in derivedBudgets) {
    final categoryDueTasks = dueTasksByCategory[budget.categoryId] ?? [];
    final categoryDueTaskIds = categoryDueTasks.map((t) => t.meta.id).toSet();

    // Build task items from tracked entries (existing logic)
    final trackedTaskItems = _buildTaskProgressItems(...);
    final trackedTaskIds = trackedTaskItems.map((i) => i.task.meta.id).toSet();

    // DEDUPLICATION: Update tracked tasks that are also due
    final mergedTaskItems = trackedTaskItems.map((item) {
      final taskId = item.task.meta.id;
      if (categoryDueTaskIds.contains(taskId)) {
        // Task has tracked time AND is due - add due date status
        final dueStatus = getDueDateStatus(
          dueDate: item.task.data.due,
          referenceDate: _date,
        );
        return TaskDayProgress(
          task: item.task,
          timeSpentOnDay: item.timeSpentOnDay,
          wasCompletedOnDay: item.wasCompletedOnDay,
          dueDateStatus: dueStatus,
        );
      }
      return item;
    }).toList();

    // Add due tasks that have NO tracked time (not already included)
    for (final dueTask in categoryDueTasks) {
      if (!trackedTaskIds.contains(dueTask.meta.id)) {
        final dueStatus = getDueDateStatus(
          dueDate: dueTask.data.due,
          referenceDate: _date,
        );
        mergedTaskItems.add(TaskDayProgress(
          task: dueTask,
          timeSpentOnDay: Duration.zero,
          wasCompletedOnDay: false,
          dueDateStatus: dueStatus,
        ));
      }
    }

    // ... build TimeBudgetProgress with mergedTaskItems
  }

  // Create synthetic budgets for categories with due tasks but no planned time
  for (final categoryId in categoriesNeedingSyntheticBudget) {
    final category = cacheService.getCategoryById(categoryId);
    final categoryDueTasks = dueTasksByCategory[categoryId]!;

    results.add(
      TimeBudgetProgress(
        categoryId: categoryId,
        category: category,
        plannedDuration: Duration.zero,
        recordedDuration: Duration.zero,
        status: BudgetProgressStatus.underBudget,
        contributingEntries: [],
        taskProgressItems: categoryDueTasks.map((task) {
          final dueStatus = getDueDateStatus(
            dueDate: task.data.due,
            referenceDate: _date,
          );
          return TaskDayProgress(
            task: task,
            timeSpentOnDay: Duration.zero,
            wasCompletedOnDay: false,
            dueDateStatus: dueStatus,
          );
        }).toList(),
        blocks: [],
        hasNoBudgetWarning: true,
      ),
    );
  }

  return results;
}
```

#### 2.6 UI Updates

##### 2.6.1 Update `TimeBudgetCard` - Warning Banner

Add warning indicator when `hasNoBudgetWarning == true`:

```dart
// In TimeBudgetCard.build(), after the header row:
if (progress.hasNoBudgetWarning) ...[
  const SizedBox(height: AppTheme.spacingSmall),
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.orange.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
        const SizedBox(width: 4),
        Text(
          context.messages.dailyOsNoBudgetWarning,
          style: context.textTheme.labelSmall?.copyWith(color: Colors.orange),
        ),
      ],
    ),
  ),
],
```

##### 2.6.2 Update `_TaskProgressRow` - Due Badge (List View)

```dart
// In _TaskProgressRow.build(), add due indicator after status circle:
if (item.isDueOrOverdue) ...[
  const SizedBox(width: 4),
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    decoration: BoxDecoration(
      color: item.dueDateStatus.urgentColor?.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(
      _getDueLabel(item.dueDateStatus, context),
      style: context.textTheme.labelSmall?.copyWith(
        color: item.dueDateStatus.urgentColor,
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
],

// Helper function:
String _getDueLabel(DueDateStatus status, BuildContext context) {
  return switch (status.urgency) {
    DueDateUrgency.overdue => context.messages.dailyOsOverdue,
    DueDateUrgency.dueToday => context.messages.dailyOsDueToday,
    DueDateUrgency.normal => '',
  };
}
```

##### 2.6.3 Update `_TaskGridTile` - Due Badge (Grid View)

```dart
// In _TaskGridTile.build(), add positioned badge (top-left, below checkmark):
if (item.isDueOrOverdue)
  Positioned(
    top: isCompleted ? 28 : 4,
    left: 4,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: item.dueDateStatus.urgentColor,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        _getDueBadgeText(item.dueDateStatus),
        style: context.textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  ),

// Helper function (short labels for compact grid):
String _getDueBadgeText(DueDateStatus status) {
  return switch (status.urgency) {
    DueDateUrgency.overdue => 'Late',
    DueDateUrgency.dueToday => 'Due',
    DueDateUrgency.normal => '',
  };
}
```

> **Visual distinction:** Overdue tasks show red badge with "Late", due-today tasks show orange badge with "Due".

---

## File Changes Summary

| File | Change Type | Description |
|------|-------------|-------------|
| `lib/features/daily_os/state/task_view_preference_controller.dart` | **New** | Riverpod controller for view preferences (stores categoryId as field) |
| `lib/features/daily_os/ui/widgets/time_budget_card.dart` | Modify | Pass categoryId, integrate preference controller, add due/overdue badges, add warning banner |
| `lib/features/daily_os/state/time_budget_progress_controller.dart` | Modify | Add `dueDateStatus: DueDateStatus` to `TaskDayProgress`, add `hasNoBudgetWarning` to `TimeBudgetProgress` |
| `lib/features/daily_os/state/unified_daily_os_data_controller.dart` | Modify | Fetch due tasks, handle deduplication, inject into budget progress, create synthetic budgets |
| `lib/database/database.dart` | Modify | Add `getTasksDueOn()` method |
| `lib/database/database.drift` | Modify | Add `tasksDueOnDate` SQL query (uses denormalized `task_status` column) |
| `lib/l10n/app_en.arb` | Modify | Add localization strings |

---

## Localization Strings

Add to `lib/l10n/app_en.arb`:

```json
"dailyOsNoBudgetWarning": "No time budgeted",
"dailyOsDueToday": "Due today",
"dailyOsOverdue": "Overdue"
```

---

## Testing Strategy

### Unit Tests

1. **`task_view_preference_controller_test.dart`**
   - Default returns `TaskViewMode.list`
   - Toggle switches between list and grid
   - Preference is persisted per category ID
   - Different categories have independent preferences

2. **`unified_daily_os_data_controller_test.dart`**
   - Due tasks are fetched for the selected date
   - Due tasks are merged into existing category budgets
   - **Deduplication:** Task with both tracked time AND due date appears once with due badge
   - Synthetic budgets created for categories with due tasks but no planned time
   - `hasNoBudgetWarning` is true for synthetic budgets
   - `dueDateStatus.urgency` is set correctly (dueToday vs overdue)

3. **Database query test**
   - `getTasksDueOn()` returns tasks with due date on specified day
   - Completed (`DONE`) and rejected (`REJECTED`) tasks are excluded
   - Tasks with null due date are excluded
   - Tasks with other statuses (`OPEN`, `IN PROGRESS`, `BLOCKED`, etc.) are included

4. **Due date status tests**
   - Task due today → `DueDateUrgency.dueToday`, orange color
   - Task overdue → `DueDateUrgency.overdue`, red color
   - Task due in future → `DueDateUrgency.normal`, no badge

### Widget Tests

1. **View mode toggle**
   - Tapping toggle switches between list and grid views
   - Preference survives widget rebuild

2. **Due badge visibility**
   - Due badge appears in list view for due tasks (orange)
   - Overdue badge appears in list view for overdue tasks (red)
   - Due badge appears in grid view for due tasks
   - Badge not shown for non-due tasks

3. **Warning banner**
   - Warning banner appears for zero-budget categories with due tasks
   - Warning banner not shown for categories with planned time

### Integration Tests

1. **End-to-end flow**
   - Create task with due date in category
   - Verify task appears on due date with badge
   - Track time on task → verify it still shows due badge (deduplication)
   - Complete task → verify it's excluded from due list

---

## Migration Notes

- No database schema migration required (uses existing JSON fields)
- Settings DB uses existing key-value schema
- Backward compatible - existing budgets work unchanged

---

## Technical Notes

### SQL Query Performance

The query uses `json_extract(serialized, '$.data.due')` which is not indexed. For initial implementation this is acceptable, but if performance becomes an issue:
1. Consider adding denormalized `due_date DATETIME` column to journal table
2. Add index: `CREATE INDEX idx_journal_due ON journal(due_date)`

### Overdue Tasks Consideration

The current implementation shows tasks that are **due on or before** the selected day (not just exact day matches). This means:
- Viewing today: Shows tasks due today AND overdue tasks
- Viewing past date: Shows tasks that were due on that date (historical view)
- Viewing future date: Shows tasks due on that specific date only

This behavior aligns with the existing `getDueDateStatus()` utility which distinguishes `dueToday` from `overdue`.

### Existing Utilities Leveraged

- `DueDateStatus` and `getDueDateStatus()` from `lib/features/tasks/util/due_date_utils.dart`
- `taskStatusRed` (overdue) and `taskStatusOrange` (dueToday) from `lib/themes/colors.dart`
- `SettingsDb.itemByKey()` and `SettingsDb.saveSettingsItem()` from `lib/database/settings_db.dart`

---

## Implementation Summary

**Completed: 2026-01-28**

### What Was Implemented

#### Part 1: View Preference Persistence
- [x] Created `TaskViewPreference` Riverpod controller with per-category persistence
- [x] Changed default view from Grid to List
- [x] Converted `_ExpandableTaskSection` to `ConsumerStatefulWidget`
- [x] View mode toggle now persists across app restarts

#### Part 2: Due Task Visibility
- [x] Added `tasksDueOnOrBefore` SQL query in `database.drift`
- [x] Added `getTasksDueOnOrBefore()` method to `JournalDb`
- [x] Extended `TaskDayProgress` with `dueDateStatus` field
- [x] Extended `TimeBudgetProgress` with `hasNoBudgetWarning` field
- [x] Modified `_buildBudgetProgress()` to merge due tasks with tracked tasks
- [x] Implemented deduplication for tasks with both tracked time AND due date
- [x] Created synthetic budgets for categories with due tasks but no planned time
- [x] Added visual badges for due/overdue tasks (list and grid views)
- [x] Added warning banner for zero-budget categories

#### Additional Improvements (from code review)
- [x] Improved sorting: overdue tasks now sort before due-today tasks
- [x] Localized grid badge strings (`dailyOsDueTodayShort`, `dailyOsOverdueShort`)
- [x] Added translations for de/es/fr/ro locales
- [x] Increased tap targets for view mode toggle (mobile UX)
- [x] Increased vertical spacing between list items (mobile UX)

### Files Changed

| File | Status |
|------|--------|
| `lib/features/daily_os/state/task_view_preference_controller.dart` | Created |
| `lib/features/daily_os/state/task_view_preference_controller.g.dart` | Generated |
| `lib/features/daily_os/ui/widgets/time_budget_card.dart` | Modified |
| `lib/features/daily_os/state/time_budget_progress_controller.dart` | Modified |
| `lib/features/daily_os/state/unified_daily_os_data_controller.dart` | Modified |
| `lib/database/database.dart` | Modified |
| `lib/database/database.drift` | Modified |
| `lib/database/database.g.dart` | Regenerated |
| `lib/l10n/app_en.arb` | Modified |
| `lib/l10n/app_localizations*.dart` | Updated |
| `test/features/daily_os/**` | Updated |

### Follow-up Items

- [ ] **Database Index for Due Date** - The `json_extract(serialized, '$.data.due')` query works but cannot use an index. For better performance on large datasets, consider adding a denormalized `due_date` column with an index. (Low priority - current implementation is acceptable for typical dataset sizes)
