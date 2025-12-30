# Habits Module

This module contains the habits feature, including habit display, completion tracking, and settings management.

## Directory Structure

```
lib/features/habits/
├── state/                    # Riverpod state management
│   ├── habit_completion_controller.dart  # Habit completion tracking
│   └── habit_settings_controller.dart    # Habit settings form state
└── ui/
    ├── habits_page.dart      # Main habits list page
    └── widgets/              # Reusable habit widgets
        ├── habit_category.dart           # Category selection for habits
        ├── habit_completion_card.dart    # Habit completion UI card
        ├── habit_completion_color_icon.dart  # Color-coded completion icon
        ├── habit_dashboard.dart          # Dashboard selection for habits
        ├── habit_page_app_bar.dart       # Habits page app bar
        ├── habit_streaks.dart            # Streak tracking display
        ├── habits_filter.dart            # Habit filtering controls
        ├── habits_search.dart            # Habit search functionality
        └── status_segmented_control.dart # Status filter control
```

## State Management

### HabitSettingsController

Manages habit settings form state for create/edit flows.

**Provider:** `habitSettingsControllerProvider(habitId)`

- Uses family provider pattern with `habitId` as key
- For **create flow**: new UUID is generated, controller initializes with empty habit
- For **edit flow**: watches habit from database via `JournalDb.watchHabitById()`
- Watches `TagsService.watchTags()` for story tag updates

**State:** `HabitSettingsState` (freezed)
- `habitDefinition` - Current habit being edited
- `dirty` - Whether form has unsaved changes
- `formKey` - GlobalKey for FormBuilder validation
- `storyTags` - Available story tags for default story selection
- `defaultStory` - Currently selected default story tag
- `autoCompleteRule` - Autocomplete rules for habit (experimental)

**Methods:**
- `setDirty()` - Mark form as modified
- `setCategory(String?)` - Update category assignment
- `setDashboard(String?)` - Update dashboard assignment
- `setActiveFrom(DateTime?)` - Set habit active from date
- `setShowFrom(DateTime?)` - Set daily schedule show from time
- `setAlertAtTime(DateTime?)` - Set daily schedule alert time
- `clearAlertAtTime()` - Remove alert time from schedule
- `onSavePressed()` - Validate and save habit (returns bool)
- `delete()` - Soft-delete habit with deletedAt timestamp

### HabitCompletionController

Manages habit completion state and tracking.

**Provider:** `habitCompletionControllerProvider`

## Related UI Pages

Habit settings pages are located in `lib/features/settings/ui/pages/habits/`:
- `habit_details_page.dart` - Edit existing habit
- `habit_create_page.dart` - Create new habit
- `habits_page.dart` - List all habits in settings

## Testing

Unit tests: `test/features/habits/state/habit_settings_controller_test.dart`
Widget tests: `test/features/settings/ui/pages/habits/habit_details_page_test.dart`
