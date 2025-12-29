# Task Chronological Sorting and Date Display Plan

## Summary

- Add configurable sort order for task lists: **By Priority** (current default) or **By Date** (newest first)
- Display creation date on task cards in the bottom-right corner with subtle styling
- Add filter modal settings for:
  - Sort order selection (Priority vs. Date) via **SegmentedButton**
  - Toggle to show/hide creation date on cards
- Persist user preferences using existing `SettingsDb` infrastructure

## Design Decisions

1. **Date Field**: Use `meta.dateFrom` (entry start date) for "creation date"
2. **Date Format**: `DateFormat.yMMMd()` → "Dec 29, 2024" (includes year)
3. **Sort Toggle UI**: SegmentedButton with "Priority" and "Date" segments
4. **Default Sort**: By Priority (preserves current behavior)

## Goals

- **Sorting**: Users can choose between:
  - **By Priority**: Sort by priority rank (P0→P3), then by `date_from` DESC within each priority level
  - **By Date**: Sort purely by `date_from` DESC (newest entries at top)
- **Date Display**: Show creation date on task cards in:
  - Position: Bottom-right corner of the card
  - Typography: Smallest available font size (`fontSizeSmall = 11.0`)
  - Color: Low contrast (use `onSurfaceVariant` with reduced alpha)
  - Spacing: Close to the border to minimize space usage
- **Configuration**: Add UI in the existing filter modal to:
  - Toggle sort order (segmented button or similar)
  - Toggle date display visibility (switch)
- **Persistence**: Save both settings in `SettingsDb` and restore on app launch

## Non-Goals

- Due dates feature (future scope, mentioned in requirements but explicitly deferred)
- Timeline view with oldest-to-newest (mentioned as future scope)
- Any changes to the journal/non-task entries sorting

## Current Architecture

### Sorting

- Task queries in `lib/database/database.drift`:
  - `filteredTasks` and `filteredTasks2` both use:
    ```sql
    ORDER BY COALESCE(task_priority_rank, 2) ASC, date_from DESC
    ```
  - `filteredTaskIds` and `filteredTaskIds2` use:
    ```sql
    ORDER BY date_from DESC
    ```

### Task Card

- Located in `lib/features/journal/ui/widgets/list_cards/modern_task_card.dart`
- Uses `ModernBaseCard` with `ModernCardContent` for layout
- Currently displays: title, priority chip, status chip, category icon, due date (if set), labels, task progress

### Filter Modal

- Located in `lib/features/tasks/ui/filtering/task_filter_icon.dart`
- Opens a modal with: `JournalFilter`, `TaskStatusFilter`, `TaskPriorityFilter`, `TaskCategoryFilter`, `TaskLabelFilter`

### State Management

- `JournalPageState` in `lib/blocs/journal/journal_page_state.dart`
- `TasksFilter` freezed class with category, status, label, and priority selections
- `JournalPageCubit` handles filter persistence via `persistTasksFilter()` using `SettingsDb`

## Data Model

### New Enum: TaskSortOption

Add to `lib/blocs/journal/journal_page_state.dart`:

```dart
/// Sort order options for task lists
enum TaskSortOption {
  /// Sort by priority first (P0 > P1 > P2 > P3), then by date within each priority
  byPriority,

  /// Sort by creation date (newest first)
  byDate,
}
```

### Extended TasksFilter

Update `TasksFilter` to include:

```dart
@freezed
abstract class TasksFilter with _$TasksFilter {
  factory TasksFilter({
    @Default(<String>{}) Set<String> selectedCategoryIds,
    @Default(<String>{}) Set<String> selectedTaskStatuses,
    @Default(<String>{}) Set<String> selectedLabelIds,
    @Default(<String>{}) Set<String> selectedPriorities,
    @Default(TaskSortOption.byPriority) TaskSortOption sortOption,
    @Default(false) bool showCreationDate,
  }) = _TasksFilter;
  // ...
}
```

## Database Changes

### New Query Variant

Add a date-sorted query variant in `lib/database/database.drift`:

```sql
filteredTasksByDate:
SELECT * FROM journal
  WHERE type IN :types
  AND deleted = false
  -- ... (same filters as filteredTasks)
  ORDER BY date_from DESC
  LIMIT :limit
  OFFSET :offset;
```

**Alternative approach** (preferred for simplicity):

Rather than duplicate queries, pass the sort option to the repository and build dynamic ordering. However, since Drift queries are compile-time checked, we'll use two separate queries and select based on the sort option in the repository layer.

### Repository Layer

Update `JournalDb.getTasks()` in `lib/database/database.dart` to accept `sortByDate` parameter:

```dart
Future<List<JournalEntity>> getTasks({
  required List<bool> starredStatuses,
  required List<String> taskStatuses,
  required List<String> categoryIds,
  List<String>? labelIds,
  List<String>? priorities,
  List<String>? ids,
  bool sortByDate = false,  // NEW
  int limit = 500,
  int offset = 0,
})
```

## UI Changes

### Task Card Date Display

Update `ModernTaskCard` to accept and display creation date:

```dart
class ModernTaskCard extends StatelessWidget {
  const ModernTaskCard({
    required this.task,
    this.showCreationDate = false,  // NEW
    super.key,
  });

  final Task task;
  final bool showCreationDate;
  // ...
}
```

Add date display in the build method:

```dart
Widget build(BuildContext context) {
  return ModernBaseCard(
    onTap: onTap,
    margin: ...,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ModernCardContent(
          title: task.data.title,
          maxTitleLines: 3,
          subtitleWidget: _buildSubtitleWidget(context),
          trailing: TimeRecordingIcon(taskId: task.meta.id),
        ),
        if (showCreationDate) _buildCreationDateRow(context),
      ],
    ),
  );
}

Widget _buildCreationDateRow(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Align(
      alignment: Alignment.bottomRight,
      child: Text(
        DateFormat.yMMMd().format(task.meta.dateFrom),  // "Dec 29, 2024"
        style: context.textTheme.bodySmall?.copyWith(
          fontSize: fontSizeSmall,  // 11.0
          color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    ),
  );
}
```

### Filter Modal Updates

Create `lib/features/tasks/ui/filtering/task_sort_filter.dart`:

```dart
class TaskSortFilter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.messages.tasksSortByLabel,
              style: context.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SegmentedButton<TaskSortOption>(
              segments: [
                ButtonSegment(
                  value: TaskSortOption.byPriority,
                  label: Text(context.messages.tasksSortByPriority),
                  icon: Icon(Icons.priority_high_rounded),
                ),
                ButtonSegment(
                  value: TaskSortOption.byDate,
                  label: Text(context.messages.tasksSortByDate),
                  icon: Icon(Icons.calendar_today_rounded),
                ),
              ],
              selected: {state.sortOption},
              onSelectionChanged: (selection) {
                context.read<JournalPageCubit>().setSortOption(selection.first);
              },
            ),
          ],
        );
      },
    );
  }
}
```

Create `lib/features/tasks/ui/filtering/task_date_display_toggle.dart`:

```dart
class TaskDateDisplayToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, state) {
        return Row(
          children: [
            Expanded(
              child: Text(
                context.messages.tasksShowCreationDate,
                style: context.textTheme.bodySmall,
              ),
            ),
            Switch(
              value: state.showCreationDate,
              onChanged: (value) {
                context.read<JournalPageCubit>().setShowCreationDate(value);
              },
            ),
          ],
        );
      },
    );
  }
}
```

Update filter modal in `task_filter_icon.dart`:

```dart
builder: (_) => const Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    // Existing filters...
    TaskSortFilter(),           // NEW
    SizedBox(height: 10),
    TaskDateDisplayToggle(),    // NEW
    SizedBox(height: 10),
    TaskStatusFilter(),
    TaskPriorityFilter(),
    TaskCategoryFilter(),
    TaskLabelFilter(),
  ],
),
```

## State Management Updates

### JournalPageState

Add fields to track sort option and date display preference:

```dart
factory JournalPageState({
  // ... existing fields ...
  @Default(TaskSortOption.byPriority) TaskSortOption sortOption,
  @Default(false) bool showCreationDate,
}) = _JournalPageState;
```

### JournalPageCubit

Add methods:

```dart
// Member variables
TaskSortOption _sortOption = TaskSortOption.byPriority;
bool _showCreationDate = false;

// Setter methods
Future<void> setSortOption(TaskSortOption option) async {
  _sortOption = option;
  await persistTasksFilter();
}

Future<void> setShowCreationDate(bool show) async {
  _showCreationDate = show;
  await persistTasksFilter();
}

// Update emitState() to include new fields
void emitState() {
  emit(
    JournalPageState(
      // ... existing fields ...
      sortOption: _sortOption,
      showCreationDate: _showCreationDate,
    ),
  );
}

// Update _loadPersistedFilters() to restore sort option and date display
// Update persistTasksFilter() to save new fields
```

### TasksFilter Updates

Extend the freezed class:

```dart
@freezed
abstract class TasksFilter with _$TasksFilter {
  factory TasksFilter({
    @Default(<String>{}) Set<String> selectedCategoryIds,
    @Default(<String>{}) Set<String> selectedTaskStatuses,
    @Default(<String>{}) Set<String> selectedLabelIds,
    @Default(<String>{}) Set<String> selectedPriorities,
    @Default(TaskSortOption.byPriority) TaskSortOption sortOption,
    @Default(false) bool showCreationDate,
  }) = _TasksFilter;

  factory TasksFilter.fromJson(Map<String, dynamic> json) =>
      _$TasksFilterFromJson(json);
}
```

## i18n

Add to `lib/l10n/app_en.arb`:

```json
"tasksSortByLabel": "Sort by",
"tasksSortByPriority": "Priority",
"tasksSortByDate": "Date",
"tasksShowCreationDate": "Show creation date on cards"
```

Add equivalent entries to other locale ARB files.

## Testing Strategy

### Unit Tests

- `TaskSortOption` enum values and JSON serialization
- `TasksFilter` with new fields: serialization round-trip
- `JournalPageCubit` sort option and date display toggles

### Repository/DB Tests

- `getTasks()` with `sortByDate: true` returns results ordered by `date_from DESC`
- `getTasks()` with `sortByDate: false` returns results ordered by priority then date

### Widget Tests

- `TaskSortFilter` displays correct segments and responds to selection
- `TaskDateDisplayToggle` displays switch and responds to toggle
- `ModernTaskCard` shows/hides creation date based on prop
- Filter modal includes new components

### Test Data Best Practices

- Use fixed timestamps (per CLAUDE.local.md)
- Create tasks with varied priorities and dates to verify sort order

## Implementation Phases

### Phase 1: State and Data Model

1. Add `TaskSortOption` enum to `journal_page_state.dart`
2. Extend `TasksFilter` with `sortOption` and `showCreationDate`
3. Run `make build_runner` to regenerate freezed/JSON

### Phase 2: Database Queries

1. Add `filteredTasksByDate` query to `database.drift`
2. Update `JournalDb.getTasks()` to accept `sortByDate` parameter
3. Update `_selectTasks()` to use appropriate query based on parameter

### Phase 3: Cubit Updates

1. Add `_sortOption` and `_showCreationDate` member variables
2. Add setter methods with persistence
3. Update `emitState()` to include new fields
4. Update `_loadPersistedFilters()` and `persistTasksFilter()`
5. Pass sort option to `getTasks()` calls

### Phase 4: UI - Task Card

1. Add `showCreationDate` parameter to `ModernTaskCard`
2. Add `_buildCreationDateRow()` method
3. Update card layout to include date row when enabled
4. Update `AnimatedModernTaskCard` and callers to pass the prop

### Phase 5: UI - Filter Modal

1. Create `TaskSortFilter` widget
2. Create `TaskDateDisplayToggle` widget
3. Update filter modal to include new components
4. Add i18n strings

### Phase 6: Testing

1. Add unit tests for new state and enums
2. Add repository tests for sort order
3. Add widget tests for new UI components
4. Run analyzer, formatter, and full test suite

### Phase 7: Documentation

1. Update CHANGELOG.md with feature entry

## Risks & Mitigations

### Risk: Query Duplication

Adding a separate query for date sorting duplicates SQL logic.

**Mitigation**: Keep queries aligned; consider extracting common filter logic if drift supports it. For now, duplication is acceptable given drift's compile-time safety.

### Risk: Performance with Large Task Lists

Changing sort order may affect pagination behavior.

**Mitigation**: Both sort orders use indexed columns (`task_priority_rank`, `date_from`). Monitor query performance.

### Risk: Migration Complexity

New fields in `TasksFilter` need JSON compatibility with existing persisted data.

**Mitigation**: Use `@Default` annotations to handle missing fields gracefully during deserialization.

## Acceptance Criteria

- [ ] Users can toggle between "By Priority" and "By Date" sort in the filter modal
- [ ] "By Priority" sorts by priority rank, then by date within each priority (existing behavior)
- [ ] "By Date" sorts purely by creation date, newest first
- [ ] Users can toggle creation date visibility on task cards
- [ ] When enabled, creation date appears in bottom-right with small, low-contrast styling
- [ ] Both settings persist across app restarts
- [ ] Analyzer shows zero warnings
- [ ] All tests pass

---

This plan implements configurable task sorting and date display while maintaining backward compatibility with existing functionality. The approach reuses existing patterns (filter persistence, freezed state, chip-based filter UI) for consistency.
