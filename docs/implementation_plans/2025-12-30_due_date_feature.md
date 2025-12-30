# Due Date Feature Implementation Plan

**Date:** 2025-12-30
**Status:** Planned
**Coverage Target:** 95%+

## Overview

Implement enhanced Due Date functionality for task management, including:
- Refactored card layout (creation date LEFT, due date RIGHT)
- Visual indicators for overdue/today status
- Due date editing in task details
- Filter toggle for due date visibility

## Key Insight: Data Layer Already Exists

`TaskData` already has a `due` field (DateTime?) at `lib/classes/task.dart:137`. No schema changes needed.

---

## Implementation Phases

### Phase 1: State Layer Updates

#### 1.1 JournalPageState
**File:** `lib/features/journal/state/journal_page_state.dart`

Add to `JournalPageState`:
```dart
@Default(true) bool showDueDate,
```

Add to `TasksFilter`:
```dart
@Default(true) bool showDueDate,
```

#### 1.2 JournalPageController
**File:** `lib/features/journal/state/journal_page_controller.dart`

Changes:
- Add `bool _showDueDate = true;` (line ~68 area)
- Add `setShowDueDate({required bool show})` method (similar to line 416-420)
- Update `_loadPersistedFilters()` to load `showDueDate`
- Update `_persistTasksFilterWithoutRefresh()` to persist `showDueDate`
- Update `_emitState()` to include `showDueDate`
- Update `build()` initial state to include `showDueDate`

---

### Phase 2: Localization Strings

**File:** `lib/l10n/app_en.arb` (and other locale files)

Add strings:
```json
"tasksShowDueDate": "Show due date on cards",
"taskDueToday": "Due Today",
"taskDueDateLabel": "Due Date",
"taskNoDueDateLabel": "No due date",
"clearButton": "Clear"
```

---

### Phase 3: ModernTaskCard UI Refactoring

**File:** `lib/features/journal/ui/widgets/list_cards/modern_task_card.dart`

**Current structure:**
- Status row (lines 73-111) contains inline due date display (lines 90-107)
- `_buildCreationDateRow()` (lines 55-69) shows creation date at bottom-right

**Target structure:**
- Status row: Remove inline due date (lines 90-107)
- Refactor `_buildCreationDateRow()` → `_buildDateRow()` showing both dates

#### 3.1 Add `showDueDate` prop
```dart
const ModernTaskCard({
  required this.task,
  this.showCreationDate = false,
  this.showDueDate = true,  // NEW - default ON per user preference
  super.key,
});
final bool showDueDate;
```

#### 3.2 Remove inline due date from status row
Remove lines 90-107 (the inline due date icon/text in `_buildSubtitleWidget`)

#### 3.3 Refactor existing `_buildCreationDateRow` to `_buildDateRow`
Keep the same location in the widget tree, but change layout from right-aligned to row with both dates:
```dart
Widget _buildDateRow(BuildContext context) {
  final hasCreationDate = showCreationDate;
  final hasDueDate = showDueDate && task.data.due != null;

  if (!hasCreationDate && !hasDueDate) return const SizedBox.shrink();

  return Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // LEFT: Creation date
        if (hasCreationDate)
          _buildCreationDateText(context)
        else
          const SizedBox.shrink(),
        // RIGHT: Due date
        if (hasDueDate)
          _DueDateText(dueDate: task.data.due!)
        else
          const SizedBox.shrink(),
      ],
    ),
  );
}
```

#### 3.4 Create `_DueDateText` widget
```dart
class _DueDateText extends StatelessWidget {
  const _DueDateText({required this.dueDate});
  final DateTime dueDate;

  Color _getColor(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDateDay = DateTime(dueDate.year, dueDate.month, dueDate.day);

    if (dueDateDay.isBefore(today)) return taskStatusRed;  // Overdue
    if (dueDateDay == today) return taskStatusOrange;       // Due Today
    return context.colorScheme.onSurfaceVariant.withValues(alpha: 0.7);
  }

  String _getText(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDateDay = DateTime(dueDate.year, dueDate.month, dueDate.day);

    if (dueDateDay == today) return context.messages.taskDueToday;
    return DateFormat.MMMd().format(dueDate);
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.event_rounded, size: fontSizeSmall, color: color),
        const SizedBox(width: 4),
        Text(_getText(context), style: TextStyle(color: color, ...)),
      ],
    );
  }
}
```

---

### Phase 4: Prop Passing Chain Updates

#### 4.1 AnimatedModernTaskCard
**File:** `lib/features/journal/ui/widgets/list_cards/animated_modern_task_card.dart`

Add `showDueDate` prop and pass to `ModernTaskCard`.

#### 4.2 CardWrapperWidget
**File:** `lib/features/journal/ui/widgets/list_cards/card_wrapper_widget.dart`

Add `showDueDate` prop and pass to `AnimatedModernTaskCard`.

#### 4.3 InfiniteJournalPage
**File:** `lib/features/journal/ui/pages/infinite_journal_page.dart` (line 141)

Pass `showDueDate: state.showDueDate` to `CardWrapperWidget`.

---

### Phase 5: Filter Modal - Due Date Toggle

#### 5.1 Create TaskDueDateDisplayToggle
**New File:** `lib/features/tasks/ui/filtering/task_due_date_display_toggle.dart`

Pattern follows `task_date_display_toggle.dart`:
```dart
class TaskDueDateDisplayToggle extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch state.showDueDate
    // Call controller.setShowDueDate(show: value) on change
    return SwitchListTile(
      title: Text(context.messages.tasksShowDueDate),
      value: state.showDueDate,
      onChanged: (value) => controller.setShowDueDate(show: value),
    );
  }
}
```

#### 5.2 Update TaskFilterContent
**File:** `lib/features/tasks/ui/filtering/task_filter_content.dart`

Add `TaskDueDateDisplayToggle()` after `TaskDateDisplayToggle()`.

---

### Phase 6: Task Details - Due Date Editing

#### 6.1 Update EntryController
**File:** `lib/features/journal/state/entry_controller.dart`

Update `save()` method to accept due date:
```dart
Future<void> save({
  Duration? estimate,
  String? title,
  DateTime? dueDate,           // NEW
  bool clearDueDate = false,   // NEW - to allow clearing
  bool stopRecording = false,
}) async {
  // ... in Task handling:
  taskData: task.data.copyWith(
    due: clearDueDate ? null : (dueDate ?? task.data.due),
  ),
}
```

#### 6.2 Create TaskDueDateWidget
**New File:** `lib/features/tasks/ui/header/task_due_date_widget.dart`

Due date picker modal with:
- CupertinoDatePicker for date selection
- Cancel/Clear/Done buttons
- Clear button to remove due date

```dart
Future<void> showDueDatePicker({
  required BuildContext context,
  required DateTime? initialDate,
  required Future<void> Function(DateTime?) onDueDateChanged,
}) async {
  // Show modal with date picker
  // onDone: call onDueDateChanged with selected date
  // onClear: call onDueDateChanged with null
}
```

#### 6.3 Create TaskDueDateWrapper
**New File:** `lib/features/tasks/ui/header/task_due_date_wrapper.dart`

Display widget for task details header:
```dart
class TaskDueDateWrapper extends ConsumerWidget {
  // Shows due date with icon
  // Color coded: red=overdue, orange=today, normal=future
  // Tappable to open picker
  // Shows "No due date" placeholder when null
}
```

#### 6.4 Update TaskHeaderMetaCard
**File:** `lib/features/tasks/ui/header/task_header_meta_card.dart`

Add `TaskDueDateWrapper(taskId: taskId)` to the metadata Wrap.

---

### Phase 7: Tests (95%+ Coverage)

#### 7.1 ModernTaskCard Tests
**File:** `test/features/journal/ui/widgets/list_cards/modern_task_card_test.dart`

Add test group `showDueDate`:
- Does not show due date when `showDueDate` is false
- Shows due date when `showDueDate` is true and due is set
- Shows red color for overdue tasks (due date in past)
- Shows "Due Today" text when due == today
- Creation date on LEFT, due date on RIGHT (position verification)
- Does not show due date when due is null

#### 7.2 TaskDueDateDisplayToggle Tests
**New File:** `test/features/tasks/ui/filtering/task_due_date_display_toggle_test.dart`

Pattern follows `task_date_display_toggle_test.dart`:
- Renders SwitchListTile with correct label
- Switch reflects state.showDueDate
- Calls setShowDueDate on toggle

#### 7.3 TaskDueDateWrapper Tests
**New File:** `test/features/tasks/ui/header/task_due_date_wrapper_test.dart`

- Shows placeholder when no due date
- Shows formatted date when due date set
- Shows red color for overdue
- Opens picker on tap

#### 7.4 Due Date Picker Tests
**New File:** `test/features/tasks/ui/header/task_due_date_widget_test.dart`

- Picker opens with initial date
- Done button calls callback with selected date
- Clear button calls callback with null
- Cancel button dismisses without callback

#### 7.5 JournalPageController Tests
Update existing tests to cover `showDueDate`:
- `setShowDueDate` updates state
- `showDueDate` persists correctly
- `showDueDate` loads from persistence

---

## Files Summary

### New Files
- `lib/features/tasks/ui/filtering/task_due_date_display_toggle.dart`
- `lib/features/tasks/ui/header/task_due_date_widget.dart`
- `lib/features/tasks/ui/header/task_due_date_wrapper.dart`
- `test/features/tasks/ui/filtering/task_due_date_display_toggle_test.dart`
- `test/features/tasks/ui/header/task_due_date_wrapper_test.dart`
- `test/features/tasks/ui/header/task_due_date_widget_test.dart`

### Modified Files
- `lib/features/journal/state/journal_page_state.dart`
- `lib/features/journal/state/journal_page_controller.dart`
- `lib/features/journal/state/entry_controller.dart`
- `lib/features/journal/ui/widgets/list_cards/modern_task_card.dart`
- `lib/features/journal/ui/widgets/list_cards/animated_modern_task_card.dart`
- `lib/features/journal/ui/widgets/list_cards/card_wrapper_widget.dart`
- `lib/features/journal/ui/pages/infinite_journal_page.dart`
- `lib/features/tasks/ui/filtering/task_filter_content.dart`
- `lib/features/tasks/ui/header/task_header_meta_card.dart`
- `lib/l10n/app_en.arb` (and other locale files)
- `test/features/journal/ui/widgets/list_cards/modern_task_card_test.dart`

---

## Implementation Order

1. State Layer (Phase 1) - Run codegen
2. Localization (Phase 2) - Run codegen
3. Filter Toggle (Phase 5) - Simple, isolated
4. ModernTaskCard (Phase 3) - Main UI change
5. Prop Passing (Phase 4) - Wire showDueDate through
6. Entry Controller (Phase 6.1) - Save method
7. Task Details (Phase 6.2-6.4) - Editing UI
8. Tests (Phase 7) - Throughout, aim for 95%+

Run after each phase:
```bash
fvm flutter pub run build_runner build --delete-conflicting-outputs
fvm dart fix --apply
fvm dart format .
fvm flutter analyze
```

---

## Testing Guidelines

- Use specific dates (e.g., `DateTime(2025, 11, 3)`) NOT `DateTime.now()`
- For overdue tests, use a date clearly in the past (e.g., `DateTime(2024, 1, 1)`)
- For "Due Today" tests, match the task creation date used in test setup
- Verify color assertions using `taskStatusRed` and `taskStatusOrange` constants
- Follow existing patterns in `modern_task_card_test.dart`
