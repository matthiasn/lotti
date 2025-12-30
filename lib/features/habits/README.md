# Habits Module

This module contains the habits feature, including habit display, completion tracking, and settings management.

## Architecture

The habits module follows a repository pattern with three layers:

1. **Repository Layer** - Abstracts data access from the database
2. **State Layer** - Riverpod controllers managing UI state
3. **UI Layer** - Flutter widgets consuming state

```
┌─────────────────────────────────────────────────────────────┐
│                         UI Layer                            │
│     (ConsumerWidget, ConsumerStatefulWidget)                │
└──────────────────────────┬──────────────────────────────────┘
                           │ ref.watch / ref.read
┌──────────────────────────▼──────────────────────────────────┐
│                       State Layer                           │
│  (HabitsController, HabitSettingsController, etc.)          │
└──────────────────────────┬──────────────────────────────────┘
                           │ ref.read(habitsRepositoryProvider)
┌──────────────────────────▼──────────────────────────────────┐
│                    Repository Layer                         │
│               (HabitsRepository)                            │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                    Database Layer                           │
│         (JournalDb, UpdateNotifications)                    │
└─────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
lib/features/habits/
├── repository/                             # Data access layer
│   ├── habits_repository.dart                 # Repository interface and implementation
│   └── habits_repository.g.dart               # Generated riverpod code
├── state/                                  # Riverpod state management
│   ├── habits_controller.dart                 # Main habits page state controller
│   ├── habits_controller.g.dart               # Generated riverpod code
│   ├── habits_state.dart                      # Freezed state class with helpers
│   ├── habits_state.freezed.dart              # Generated freezed code
│   ├── habit_completion_controller.dart       # Habit completion tracking
│   ├── habit_completion_controller.g.dart     # Generated riverpod code
│   ├── habit_settings_controller.dart         # Habit settings form state
│   ├── habit_settings_controller.freezed.dart # Generated freezed code
│   └── habit_settings_controller.g.dart       # Generated riverpod code
└── ui/
    ├── habits_page.dart                # Main habits list page (ConsumerStatefulWidget)
    └── widgets/                        # Reusable habit widgets
        ├── habit_category.dart             # Category selection for habits
        ├── habit_completion_card.dart      # Habit completion UI card
        ├── habit_completion_color_icon.dart  # Color-coded completion icon
        ├── habit_dashboard.dart            # Dashboard selection for habits
        ├── habit_page_app_bar.dart         # Habits page app bar (ConsumerWidget)
        ├── habit_streaks.dart              # Streak tracking display (ConsumerWidget)
        ├── habits_filter.dart              # Habit filtering controls (ConsumerWidget)
        ├── habits_search.dart              # Habit search (ConsumerStatefulWidget)
        └── status_segmented_control.dart   # Status filter control
```

## Repository Layer

### HabitsRepository

Abstracts all habit-related database operations, making controllers easier to test and more modular.

**Provider:** `habitsRepositoryProvider`

- Uses `@Riverpod(keepAlive: true)` for app-wide persistence
- Bridges `getIt` service locator and Riverpod for dependency injection
- Can be easily overridden in tests with `ProviderScope` overrides

**Interface Methods:**

| Method | Return Type | Description |
|--------|-------------|-------------|
| `watchHabitDefinitions()` | `Stream<List<HabitDefinition>>` | Watch all habit definitions |
| `watchHabitById(id)` | `Stream<HabitDefinition?>` | Watch a specific habit by ID |
| `getHabitCompletionsInRange(rangeStart)` | `Future<List<JournalEntity>>` | Get completions from date to now |
| `getHabitCompletionsByHabitId(...)` | `Future<List<JournalEntity>>` | Get completions for specific habit |
| `upsertHabitDefinition(habit)` | `Future<int>` | Save or update a habit |
| `watchDashboards()` | `Stream<List<DashboardDefinition>>` | Watch all dashboards |
| `updateStream` | `Stream<Set<String>>` | Stream of notification IDs |

**Testing:**

```dart
// Override repository in tests
final container = ProviderContainer(
  overrides: [
    habitsRepositoryProvider.overrideWithValue(mockRepository),
  ],
);
```

## State Management

### HabitsController

Main controller managing the complete habits page state. Uses `@Riverpod(keepAlive: true)` for app-wide persistence.

**Provider:** `habitsControllerProvider`

- Marked `keepAlive: true` since habits state should persist across navigation
- Uses `HabitsRepository` for all data access (no direct `getIt` usage)
- Subscribes to habit definitions and completion notifications via repository
- Manages visibility updates via `VisibilityDetector`

**State:** `HabitsState` (freezed)

| Field | Type | Description |
|-------|------|-------------|
| `habitDefinitions` | `List<HabitDefinition>` | All active habit definitions |
| `habitCompletions` | `List<JournalEntity>` | Habit completions in time range |
| `completedToday` | `Set<String>` | Habit IDs completed today |
| `successfulToday` | `Set<String>` | Habit IDs successful today |
| `openHabits` | `List<HabitDefinition>` | Habits not yet completed today |
| `openNow` | `List<HabitDefinition>` | Open habits filtered by category (due now) |
| `pendingLater` | `List<HabitDefinition>` | Open habits filtered by category (due later) |
| `completed` | `List<HabitDefinition>` | Completed habits filtered by category |
| `days` | `List<String>` | Date strings for chart display |
| `successfulByDay` | `Map<String, Set<String>>` | Habit IDs successful by day |
| `skippedByDay` | `Map<String, Set<String>>` | Habit IDs skipped by day |
| `failedByDay` | `Map<String, Set<String>>` | Habit IDs failed by day |
| `allByDay` | `Map<String, Set<String>>` | All habit IDs by day |
| `selectedInfoYmd` | `String` | Selected day for chart info display |
| `successPercentage` | `int` | Success rate for selected day |
| `skippedPercentage` | `int` | Skip rate for selected day |
| `failedPercentage` | `int` | Fail rate for selected day |
| `shortStreakCount` | `int` | Habits with 3+ day streaks |
| `longStreakCount` | `int` | Habits with 7+ day streaks |
| `timeSpanDays` | `int` | Chart time span (7 or 14 days) |
| `minY` | `double` | Chart Y-axis minimum value |
| `zeroBased` | `bool` | Whether chart starts at 0% |
| `isVisible` | `bool` | Whether habits page is visible |
| `showTimeSpan` | `bool` | Show time span selector |
| `showSearch` | `bool` | Show search input |
| `searchString` | `String` | Current search filter |
| `selectedCategoryIds` | `Set<String>` | Selected category filter IDs |
| `displayFilter` | `HabitDisplayFilter` | Tab filter (openNow/pendingLater/completed/all) |

**Methods:**

| Method | Description |
|--------|-------------|
| `updateVisibility(VisibilityInfo)` | Update visibility state from `VisibilityDetector` |
| `setTimeSpan(int)` | Set chart time span (refetches completions) |
| `setDisplayFilter(HabitDisplayFilter?)` | Set tab display filter |
| `setSearchString(String)` | Set search filter (lowercased) |
| `toggleZeroBased()` | Toggle chart zero-based mode |
| `toggleShowSearch()` | Toggle search UI visibility |
| `toggleShowTimeSpan()` | Toggle time span selector visibility |
| `toggleSelectedCategoryIds(String)` | Toggle category in filter set |
| `setInfoYmd(String)` | Set selected day for chart info (auto-clears after 15s) |

**Helper Functions:**

| Function | Description |
|----------|-------------|
| `completionRate(HabitsState, Map)` | Calculate completion percentage for selected day |
| `totalForDay(String, HabitsState)` | Count total habits that should be tracked for a day |
| `activeBy(List<HabitDefinition>, String)` | Filter habits active by a given date |
| `habitMinY(List<String>, HabitsState)` | Calculate chart Y-axis minimum |
| `getHabitDays(int)` | Generate date strings for time span |

### HabitSettingsController

Manages habit settings form state for create/edit flows.

**Provider:** `habitSettingsControllerProvider(habitId)`

- Uses `AutoDisposeNotifierProvider.family` with `habitId` (String) as key
- For **create flow**: new UUID is generated upfront, controller initializes with empty habit
- For **edit flow**: watches habit from database via `habitByIdProvider` (uses repository)
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
- Uses `HabitsRepository` for data access
- Listens to `UpdateNotifications` stream (via repository) to refresh when habit is modified
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

**`habitByIdProvider(habitId)`** - Stream provider for watching a habit by ID. Uses repository.

**`habitDashboardsProvider`** - Stream provider for watching all dashboards. Uses repository.

## Related UI Pages

Habit settings pages are located in `lib/features/settings/ui/pages/habits/`:

| File | Description |
|------|-------------|
| `habit_details_page.dart` | Edit existing habit (uses `HabitDetailsPage`) |
| `habit_create_page.dart` | Create new habit (generates UUID, uses `HabitDetailsPage`) |
| `habits_page.dart` | List all habits in settings |

Chart widget is located at `lib/widgets/charts/habits/`:

| File | Description |
|------|-------------|
| `habit_completion_rate_chart.dart` | Completion rate line chart (ConsumerWidget) |

## Testing

| Test File | Coverage |
|-----------|----------|
| `test/features/habits/repository/habits_repository_test.dart` | Unit tests for HabitsRepository (13 tests) |
| `test/features/habits/state/habits_controller_test.dart` | Unit tests for HabitsController (20 tests) |
| `test/features/habits/state/habit_settings_controller_test.dart` | Unit tests for HabitSettingsController (16 tests) |
| `test/features/habits/ui/pages/habits_tab_page_test.dart` | Widget tests for habits page (4 tests) |
| `test/features/habits/ui/widgets/habits_search_test.dart` | Widget tests for search widget (7 tests) |
| `test/widgets/charts/habits/habit_completion_rate_chart_test.dart` | Widget tests for chart (4 tests) |
| `test/features/settings/ui/pages/habits/habit_details_page_test.dart` | Widget tests for habit details UI (5 tests) |

**Testing with Repository Overrides:**

```dart
// Create mock repository
final mockRepository = MockHabitsRepository();
when(mockRepository.watchHabitDefinitions())
    .thenAnswer((_) => definitionsController.stream);

// Use provider override instead of getIt registration
final container = ProviderContainer(
  overrides: [
    habitsRepositoryProvider.overrideWithValue(mockRepository),
  ],
);
```

## Migration Notes

### v0.9.786 - Habits Page State Migration & Repository Layer

The habits page state was migrated from BLoC to Riverpod:

- Replaced `HabitsCubit` with `HabitsController` using `@Riverpod(keepAlive: true)`
- Created Freezed-based `HabitsState` with helper functions for chart calculations
- Updated all UI widgets to use Riverpod (`ConsumerWidget` / `ConsumerStatefulWidget`)
- Fixed `HabitsSearchWidget` TextEditingController lifecycle (proper init/dispose/sync with `ref.listen`)
- Fixed chart touch handling to defer state modification via `addPostFrameCallback`
- Added comprehensive test coverage for controller, state helpers, and widgets

Added repository layer to separate data access from state management:

- Created `HabitsRepository` interface and `HabitsRepositoryImpl`
- All controllers now use repository via `ref.read(habitsRepositoryProvider)` instead of direct `getIt`
- Repository provider bridges `getIt` service locator with Riverpod DI
- Tests updated to use `habitsRepositoryProvider.overrideWithValue()` instead of `getIt` registration
- Improves testability - mock repository instead of individual database/notification services

### v0.9.784 - Habit Settings State Migration

The habit settings state was migrated from BLoC to Riverpod:

- Replaced `HabitSettingsCubit` with `HabitSettingsController`
- Uses manual `AutoDisposeNotifierProvider.family` pattern (not `@riverpod` annotation) to avoid code generation issues with complex family parameters
- Pattern follows `CategoryDetailsController` implementation
