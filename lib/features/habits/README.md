# Habits Module

This module contains the habits feature, including habit display, completion tracking, and settings management.

## Directory Structure

```
lib/features/habits/
├── state/                              # Riverpod state management
│   ├── habit_completion_controller.dart    # Habit completion tracking
│   ├── habit_completion_controller.g.dart  # Generated riverpod code
│   ├── habit_settings_controller.dart      # Habit settings form state
│   ├── habit_settings_controller.freezed.dart  # Generated freezed code
│   └── habit_settings_controller.g.dart    # Generated riverpod code
└── ui/
    ├── habits_page.dart                # Main habits list page
    └── widgets/                        # Reusable habit widgets
        ├── habit_category.dart             # Category selection for habits
        ├── habit_completion_card.dart      # Habit completion UI card
        ├── habit_completion_color_icon.dart  # Color-coded completion icon
        ├── habit_dashboard.dart            # Dashboard selection for habits
        ├── habit_page_app_bar.dart         # Habits page app bar
        ├── habit_streaks.dart              # Streak tracking display
        ├── habits_filter.dart              # Habit filtering controls
        ├── habits_search.dart              # Habit search functionality
        └── status_segmented_control.dart   # Status filter control
```

## State Management

### HabitSettingsController

Manages habit settings form state for create/edit flows.

**Provider:** `habitSettingsControllerProvider(habitId)`

- Uses `AutoDisposeNotifierProvider.family` with `habitId` (String) as key
- For **create flow**: new UUID is generated upfront, controller initializes with empty habit
- For **edit flow**: watches habit from database via `JournalDb.watchHabitById()`
- Watches `TagsService.watchTags()` for story tag updates
- Does not update from DB when form is dirty (prevents overwriting user changes)

**State:** `HabitSettingsState` (freezed)

| Field | Type | Description |
|-------|------|-------------|
| `habitDefinition` | `HabitDefinition` | Current habit being edited |
| `dirty` | `bool` | Whether form has unsaved changes |
| `formKey` | `GlobalKey<FormBuilderState>` | Key for FormBuilder validation |
| `storyTags` | `List<StoryTag>` | Available story tags for default story selection |
| `defaultStory` | `StoryTag?` | Currently selected default story tag |
| `autoCompleteRule` | `AutoCompleteRule?` | Autocomplete rules for habit (experimental) |

**Methods:**

| Method | Description |
|--------|-------------|
| `setDirty()` | Mark form as modified |
| `setCategory(String?)` | Update category assignment |
| `setDashboard(String?)` | Update dashboard assignment |
| `setActiveFrom(DateTime?)` | Set habit active from date |
| `setShowFrom(DateTime?)` | Set daily schedule show from time |
| `setAlertAtTime(DateTime?)` | Set daily schedule alert time |
| `clearAlertAtTime()` | Remove alert time from schedule |
| `onSavePressed()` | Validate and save habit (returns `bool`) |
| `delete()` | Soft-delete habit with deletedAt timestamp |
| `removeAutoCompleteRuleAt(List<int>)` | Remove autocomplete rule at path |

### HabitCompletionController

Fetches and caches habit completion data for a date range. Uses `@riverpod` annotation.

**Provider:** `habitCompletionControllerProvider(habitId, rangeStart, rangeEnd)`

- Family provider with three parameters: `habitId`, `rangeStart`, `rangeEnd`
- Returns `AsyncValue<List<HabitResult>>`
- Listens to `UpdateNotifications` stream to refresh when habit is modified
- Uses `cacheFor(entryCacheDuration)` for performance

**Usage:**

```dart
final completionsAsync = ref.watch(
  habitCompletionControllerProvider(
    habitId: habit.id,
    rangeStart: weekStart,
    rangeEnd: weekEnd,
  ),
);

completionsAsync.when(
  data: (results) => HabitChart(results: results),
  loading: () => const CircularProgressIndicator(),
  error: (e, _) => Text('Error: $e'),
);
```

### Supporting Providers

**`habitByIdProvider(habitId)`** - Stream provider for watching a habit by ID from database.

**`habitDashboardsProvider`** - Stream provider for watching all dashboards (used in dashboard selection).

## Related UI Pages

Habit settings pages are located in `lib/features/settings/ui/pages/habits/`:

| File | Description |
|------|-------------|
| `habit_details_page.dart` | Edit existing habit (uses `HabitDetailsPage`) |
| `habit_create_page.dart` | Create new habit (generates UUID, uses `HabitDetailsPage`) |
| `habits_page.dart` | List all habits in settings |

## Testing

| Test File | Coverage |
|-----------|----------|
| `test/features/habits/state/habit_settings_controller_test.dart` | Unit tests for HabitSettingsController (16 tests) |
| `test/features/settings/ui/pages/habits/habit_details_page_test.dart` | Widget tests for habit details UI (5 tests) |

## Migration Notes

The habit settings state was migrated from BLoC to Riverpod in v0.9.784:

- Replaced `HabitSettingsCubit` with `HabitSettingsController`
- Uses manual `AutoDisposeNotifierProvider.family` pattern (not `@riverpod` annotation) to avoid code generation issues with complex family parameters
- Pattern follows `CategoryDetailsController` implementation
