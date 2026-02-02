# Quick Task Creation from Time Budget Rows

## Overview

Add a "+" button to each Time Budget row on the Daily Operating System screen that instantly creates a task with pre-assigned category and due date, then navigates to the task detail screen for immediate editing.

## Requirements

1. **UI**: Plus button on the right side of each TimeBudgetCard header row
2. **Task Defaults**:
   - Category: Auto-assigned from the budget row's category
   - Due Date: Auto-assigned to the selected day (context date)
   - Status: Open (existing default)
3. **Flow**: Navigate to task detail immediately after creation

## Implementation Plan

### Step 1: Extend `createTask` Function

**File**: `lib/logic/create/create_entry.dart`

Modify the `createTask` function to accept an optional `due` parameter:

```dart
Future<Task?> createTask({
  String? linkedId,
  String? categoryId,
  DateTime? due,  // NEW
}) async {
  final now = DateTime.now();

  final task = await getIt<PersistenceLogic>().createTaskEntry(
    data: TaskData(
      status: taskStatusFromString(''),
      title: '',
      statusHistory: [],
      dateTo: now,
      dateFrom: now,
      estimate: Duration.zero,
      due: due,  // NEW: pass through due date
    ),
    entryText: const EntryText(plainText: ''),
    linkedId: linkedId,
    categoryId: categoryId,
  );

  return task;
}
```

### Step 2: Add Quick Create Button to TimeBudgetCard

**File**: `lib/features/daily_os/ui/widgets/time_budget_card.dart`

#### 2a. Add required imports

```dart
import 'package:lotti/logic/create/create_entry.dart';
```

#### 2b. Add `selectedDate` parameter to TimeBudgetCard

The widget needs access to the selected date for setting the due date:

```dart
class TimeBudgetCard extends ConsumerStatefulWidget {
  const TimeBudgetCard({
    required this.progress,
    required this.selectedDate,  // NEW
    this.onTap,
    this.onLongPress,
    this.isExpanded = false,
    this.isFocusActive,
    super.key,
  });

  final TimeBudgetProgress progress;
  final DateTime selectedDate;  // NEW
  // ... rest unchanged
}
```

#### 2c. Add the quick create button in the header row

Insert a "+" button between the category name and the task completion indicator (Row 1, around line 168):

```dart
// Category name (flexible, can be long)
Expanded(
  child: Text(
    category?.name ?? context.messages.dailyOsUncategorized,
    style: context.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  ),
),

// NEW: Quick create task button
GestureDetector(
  onTap: () => _quickCreateTask(context),
  behavior: HitTestBehavior.opaque,
  child: Padding(
    padding: const EdgeInsets.all(4),
    child: Icon(
      Icons.add_circle_outline,
      size: 20,
      color: context.colorScheme.primary,
    ),
  ),
),

// Task completion indicator (if has tasks)
if (hasTasks) ...[
  const SizedBox(width: 8),
  _TaskCompletionIndicator(
    tasks: progress.taskProgressItems,
  ),
],
```

#### 2d. Add the quick create handler method in _TimeBudgetCardState

```dart
Future<void> _quickCreateTask(BuildContext context) async {
  final categoryId = widget.progress.category?.id;

  // Create task with category and due date pre-assigned
  final task = await createTask(
    categoryId: categoryId,
    due: widget.selectedDate,
  );

  // Navigate to the newly created task
  if (task != null && context.mounted) {
    beamToNamed('/tasks/${task.meta.id}');
  }
}
```

### Step 3: Update TimeBudgetList to Pass Selected Date

**File**: `lib/features/daily_os/ui/widgets/time_budget_list.dart`

Update the TimeBudgetCard instantiation to pass the selected date:

```dart
return TimeBudgetCard(
  key: ValueKey(progress.categoryId),
  progress: progress,
  selectedDate: selectedDate,  // NEW
  isFocusActive: isFocusActive,
  onTap: () {
    ref
        .read(dailyOsControllerProvider.notifier)
        .highlightCategory(progress.categoryId);
  },
);
```

### Step 4: Add Localization (Optional Enhancement)

**File**: `lib/l10n/app_en.arb` (and other locales)

Add tooltip text:

```json
"dailyOsQuickCreateTask": "Create task for this budget"
```

Update the button to use the tooltip:

```dart
Tooltip(
  message: context.messages.dailyOsQuickCreateTask,
  child: GestureDetector(
    onTap: () => _quickCreateTask(context),
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: Icon(
        Icons.add_circle_outline,
        size: 20,
        color: context.colorScheme.primary,
      ),
    ),
  ),
),
```

## Files to Modify

| File | Change |
|------|--------|
| `lib/logic/create/create_entry.dart` | Add `due` parameter to `createTask` |
| `lib/features/daily_os/ui/widgets/time_budget_card.dart` | Add `selectedDate` param, add "+" button, add handler |
| `lib/features/daily_os/ui/widgets/time_budget_list.dart` | Pass `selectedDate` to TimeBudgetCard |
| `lib/l10n/app_en.arb` | Add tooltip localization key |

## Verification Plan

1. **Unit Test**: Add test for `createTask` with due date parameter
2. **Manual Testing**:
   - Navigate to Daily OS screen with Time Budgets visible
   - Click the "+" button on a budget row
   - Verify: New task opens immediately
   - Verify: Task has correct category assigned
   - Verify: Task has due date set to the selected day
   - Verify: Task status is Open
3. **Run analyzer and formatter**: `fvm flutter analyze && fvm dart format .`
4. **Run existing tests**: Ensure no regressions

## Design Considerations

- **Button Placement**: The "+" button is placed after the category name and before task indicators to maintain visual hierarchy while being easily discoverable
- **Icon Choice**: `Icons.add_circle_outline` matches the existing "add budget" button style in the section header
- **Color**: Uses `primary` color to indicate an actionable item without being too prominent
- **No Confirmation**: Direct creation without dialog reduces friction (matching the "quick create" intent)
