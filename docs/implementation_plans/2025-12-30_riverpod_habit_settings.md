# Refactor Habit Settings BLoC to Riverpod

## Status: COMPLETED (2025-12-30)

## Overview

Migrate the habit settings state management from BLoC (`lib/blocs/settings/habits/`) to Riverpod (`lib/features/habits/state/`), following the patterns established in:
- **PR #2548**: Dashboards refactor (merged 2025-12-29) - [GitHub](https://github.com/matthiasn/lotti/pull/2548)
- **PR #2550**: Sync outbox refactor (merged 2025-12-30) - [GitHub](https://github.com/matthiasn/lotti/pull/2550)
- **PR #2551**: Theming refactor (merged 2025-12-30) - [GitHub](https://github.com/matthiasn/lotti/pull/2551)

This is the fourth phase of the codebase-wide BLoC-to-Riverpod migration.

## Current State Analysis

### Files in lib/blocs/settings/habits/

| File | Lines | Purpose |
|------|-------|---------|
| `habit_settings_cubit.dart` | 204 | Cubit managing habit settings form state |
| `habit_settings_state.dart` | 19 | Freezed state definition |
| `habit_settings_state.freezed.dart` | ~150 | Generated freezed code |

### Current HabitSettingsCubit Logic

```dart
class HabitSettingsCubit extends Cubit<HabitSettingsState> {
  // Manages:
  // - HabitDefinition (name, description, category, dashboard, schedule, etc.)
  // - Form dirty state
  // - Form key (GlobalKey<FormBuilderState>)
  // - Story tags list (from TagsService stream)
  // - Default story selection
  // - AutoCompleteRule for habit suggestions

  // Key subscriptions:
  // - TagsService.watchTags() - watches for story tags updates

  // Key methods:
  // - setDirty() - marks form as modified
  // - setCategory(String? categoryId)
  // - setDashboard(String? dashboardId)
  // - setActiveFrom(DateTime? activeFrom)
  // - setShowFrom(DateTime? showFrom)
  // - setAlertAtTime(DateTime? alertAtTime)
  // - clearAlertAtTime()
  // - onSavePressed() - validates and persists habit
  // - delete() - soft-deletes habit
  // - removeAutoCompleteRuleAt(List<int> path)
}
```

### HabitSettingsState Structure (Freezed)

```dart
@freezed
abstract class HabitSettingsState with _$HabitSettingsState {
  factory HabitSettingsState({
    required HabitDefinition habitDefinition,
    required bool dirty,
    required GlobalKey<FormBuilderState> formKey,
    required List<StoryTag> storyTags,
    required AutoCompleteRule? autoCompleteRule,
    StoryTag? defaultStory,
  }) = _HabitSettingsStateSaved;
}
```

### Current Usage in Codebase

| Location | Usage |
|----------|-------|
| `lib/features/settings/ui/pages/habits/habit_details_page.dart` | BlocBuilder for form UI, BlocProvider creation |
| `lib/features/settings/ui/pages/habits/habit_create_page.dart` | BlocProvider creation for new habit |
| `lib/features/habits/ui/widgets/habit_category.dart` | BlocBuilder + context.read for category selection |
| `lib/features/habits/ui/widgets/habit_dashboard.dart` | BlocBuilder + context.read for dashboard selection |
| `lib/features/settings/ui/widgets/habits/habit_autocomplete_widget.dart` | Uses cubit state for autocomplete rule |

### Existing Tests

| Test File | Test Cases | Purpose |
|-----------|------------|---------|
| `test/features/settings/ui/pages/habits/habit_details_page_test.dart` | 5 tests | Widget tests for details page UI |

## Key Differences from Previous Migrations

### Comparison with ThemingController (PR #2551)

| Aspect | ThemingController | HabitSettingsController |
|--------|-------------------|-------------------------|
| Lifecycle | `keepAlive: true` (app-wide) | Auto-dispose (per-form instance) |
| Provider Type | Singleton notifier | Family-style (per habit ID) |
| Persistence | Saves to SettingsDb | Saves to JournalDb via PersistenceLogic |
| Sync | Enqueues sync messages | No sync (handled by PersistenceLogic) |
| Form State | No form | FormBuilderState key |

### Special Considerations

1. **Per-Instance State**: Unlike ThemingController which is app-wide, HabitSettingsController needs to manage state for a specific habit being edited.

2. **Form Key Management**: The controller holds a `GlobalKey<FormBuilderState>` which is widget-specific. This requires careful handling.

3. **Context for Navigation**: The cubit uses `BuildContext` for `Navigator.maybePop()`. With Riverpod, we'll pass callbacks instead.

4. **TagsService Subscription**: Watches for story tags updates to populate the dropdown.

## Proposed Riverpod Implementation

### Option A: Stateful Widget with Local Provider

Create the provider locally within the widget's lifecycle:

```dart
class HabitDetailsPage extends ConsumerStatefulWidget {
  const HabitDetailsPage({required this.habitDefinition, super.key});
  final HabitDefinition habitDefinition;

  @override
  ConsumerState<HabitDetailsPage> createState() => _HabitDetailsPageState();
}

class _HabitDetailsPageState extends ConsumerState<HabitDetailsPage> {
  late final HabitSettingsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = HabitSettingsController(widget.habitDefinition);
  }
  // ...
}
```

**Pros**: Simple, no family provider complexity
**Cons**: Not truly Riverpod, loses benefits of provider architecture

### Option B: Family Provider (Recommended)

Use a family provider pattern with habit definition as parameter:

```dart
@riverpod
class HabitSettingsController extends _$HabitSettingsController {
  @override
  HabitSettingsState build({required HabitDefinition habitDefinition}) {
    // Initialize state with habitDefinition
    _watchTags(habitDefinition);

    return HabitSettingsState(
      habitDefinition: habitDefinition,
      dirty: false,
      formKey: GlobalKey<FormBuilderState>(),
      storyTags: [],
      autoCompleteRule: testAutoComplete,
    );
  }
  // ... methods
}

// Usage in widget:
final state = ref.watch(habitSettingsControllerProvider(habitDefinition: habit));
final controller = ref.read(habitSettingsControllerProvider(habitDefinition: habit).notifier);
```

**Pros**: Follows established Riverpod patterns, testable, cacheable
**Cons**: GlobalKey in state is unusual (but works)

### Recommendation: Option B (Family Provider)

This matches the established patterns while accommodating the per-habit-instance requirement.

## Step-by-Step Implementation

### Step 1: Create State and Controller

**File:** `lib/features/habits/state/habit_settings_controller.dart`

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/features/settings/ui/widgets/habits/habit_autocomplete_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/habits/autocomplete_update.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'habit_settings_controller.g.dart';

/// Immutable state for the habit settings form.
@immutable
class HabitSettingsState {
  const HabitSettingsState({
    required this.habitDefinition,
    required this.dirty,
    required this.formKey,
    required this.storyTags,
    required this.autoCompleteRule,
    this.defaultStory,
  });

  final HabitDefinition habitDefinition;
  final bool dirty;
  final GlobalKey<FormBuilderState> formKey;
  final List<StoryTag> storyTags;
  final StoryTag? defaultStory;
  final AutoCompleteRule? autoCompleteRule;

  HabitSettingsState copyWith({
    HabitDefinition? habitDefinition,
    bool? dirty,
    GlobalKey<FormBuilderState>? formKey,
    List<StoryTag>? storyTags,
    StoryTag? defaultStory,
    AutoCompleteRule? autoCompleteRule,
    bool clearDefaultStory = false,
  }) {
    return HabitSettingsState(
      habitDefinition: habitDefinition ?? this.habitDefinition,
      dirty: dirty ?? this.dirty,
      formKey: formKey ?? this.formKey,
      storyTags: storyTags ?? this.storyTags,
      defaultStory: clearDefaultStory ? null : (defaultStory ?? this.defaultStory),
      autoCompleteRule: autoCompleteRule ?? this.autoCompleteRule,
    );
  }
}

/// Controller for managing habit settings form state.
/// Uses a family provider pattern with habitDefinition as parameter.
@riverpod
class HabitSettingsController extends _$HabitSettingsController {
  StreamSubscription<List<TagEntity>>? _tagsSubscription;

  @override
  HabitSettingsState build({required HabitDefinition habitDefinition}) {
    ref.onDispose(() {
      _tagsSubscription?.cancel();
    });

    _watchTags(habitDefinition);

    return HabitSettingsState(
      habitDefinition: habitDefinition,
      dirty: false,
      formKey: GlobalKey<FormBuilderState>(),
      storyTags: [],
      autoCompleteRule: testAutoComplete,
    );
  }

  void _watchTags(HabitDefinition habitDefinition) {
    _tagsSubscription = getIt<TagsService>().watchTags().listen((tags) {
      final storyTags = tags.whereType<StoryTag>().toList();
      final defaultStory = habitDefinition.defaultStoryId != null
          ? storyTags
              .where((tag) => tag.id == habitDefinition.defaultStoryId)
              .firstOrNull
          : null;

      state = state.copyWith(
        storyTags: storyTags,
        defaultStory: defaultStory,
        clearDefaultStory: defaultStory == null,
      );
    });
  }

  /// Marks the form as dirty (modified).
  void setDirty() {
    state = state.copyWith(dirty: true);
  }

  /// Sets the category ID for the habit.
  void setCategory(String? categoryId) {
    state = state.copyWith(
      dirty: true,
      habitDefinition: state.habitDefinition.copyWith(categoryId: categoryId),
    );
  }

  /// Sets the dashboard ID for the habit.
  void setDashboard(String? dashboardId) {
    state = state.copyWith(
      dirty: true,
      habitDefinition: state.habitDefinition.copyWith(dashboardId: dashboardId),
    );
  }

  /// Sets the active from date for the habit.
  void setActiveFrom(DateTime? activeFrom) {
    state = state.copyWith(
      dirty: true,
      habitDefinition: state.habitDefinition.copyWith(activeFrom: activeFrom),
    );
  }

  /// Sets the show from time for a daily habit schedule.
  void setShowFrom(DateTime? showFrom) {
    final currentSchedule = state.habitDefinition.habitSchedule;

    final newSchedule = currentSchedule.maybeMap(
      daily: (daily) => HabitSchedule.daily(
        requiredCompletions: daily.requiredCompletions,
        showFrom: showFrom,
        alertAtTime: daily.alertAtTime,
      ),
      orElse: () => HabitSchedule.daily(
        requiredCompletions: 1,
        showFrom: showFrom,
      ),
    );

    state = state.copyWith(
      dirty: true,
      habitDefinition: state.habitDefinition.copyWith(habitSchedule: newSchedule),
    );
  }

  /// Sets the alert time for a daily habit schedule.
  void setAlertAtTime(DateTime? alertAtTime) {
    final currentSchedule = state.habitDefinition.habitSchedule;

    final newSchedule = currentSchedule.maybeMap(
      daily: (daily) => HabitSchedule.daily(
        requiredCompletions: daily.requiredCompletions,
        showFrom: daily.showFrom,
        alertAtTime: alertAtTime,
      ),
      orElse: () => HabitSchedule.daily(
        requiredCompletions: 1,
        alertAtTime: alertAtTime,
      ),
    );

    state = state.copyWith(
      dirty: true,
      habitDefinition: state.habitDefinition.copyWith(habitSchedule: newSchedule),
    );
  }

  /// Clears the alert time for a daily habit schedule.
  void clearAlertAtTime() {
    final currentSchedule = state.habitDefinition.habitSchedule;

    final newSchedule = currentSchedule.maybeMap(
      daily: (daily) => HabitSchedule.daily(
        requiredCompletions: daily.requiredCompletions,
        showFrom: daily.showFrom,
      ),
      orElse: () => const HabitSchedule.daily(
        requiredCompletions: 1,
      ),
    );

    state = state.copyWith(
      dirty: true,
      habitDefinition: state.habitDefinition.copyWith(habitSchedule: newSchedule),
    );
  }

  /// Saves the habit and schedules notifications.
  /// Returns true if save was successful.
  Future<bool> onSavePressed() async {
    state.formKey.currentState!.save();
    if (state.formKey.currentState!.validate()) {
      final formData = state.formKey.currentState?.value;
      final private = formData?['private'] as bool? ?? false;
      final active = !(formData?['archived'] as bool? ?? false);
      final priority = formData?['priority'] as bool? ?? false;
      final defaultStory = formData?['default_story_id'] as StoryTag?;

      final dataType = state.habitDefinition.copyWith(
        name: '${formData!['name']}'.trim(),
        description: '${formData['description']}'.trim(),
        private: private,
        active: active,
        priority: priority,
        defaultStoryId: defaultStory?.id,
      );

      await getIt<PersistenceLogic>().upsertEntityDefinition(dataType);
      state = state.copyWith(dirty: false);

      await getIt<NotificationService>().scheduleHabitNotification(dataType);

      return true;
    }
    return false;
  }

  /// Deletes the habit by marking it with a deletedAt timestamp.
  Future<void> delete() async {
    await getIt<PersistenceLogic>().upsertEntityDefinition(
      state.habitDefinition.copyWith(deletedAt: DateTime.now()),
    );
  }

  /// Removes an autocomplete rule at the specified path.
  void removeAutoCompleteRuleAt(List<int> replaceAtPath) {
    state = state.copyWith(
      autoCompleteRule: replaceAt(
        state.autoCompleteRule,
        replaceAtPath: replaceAtPath,
        replaceWith: null,
      ),
    );
  }
}
```

### Step 2: Update UI Components

#### 2.1 HabitDetailsPage

**File:** `lib/features/settings/ui/pages/habits/habit_details_page.dart`

Convert to `ConsumerWidget` and use the family provider:

```dart
class HabitDetailsPage extends ConsumerWidget {
  const HabitDetailsPage({required this.habitDefinition, super.key});
  final HabitDefinition habitDefinition;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      habitSettingsControllerProvider(habitDefinition: habitDefinition),
    );
    final controller = ref.read(
      habitSettingsControllerProvider(habitDefinition: habitDefinition).notifier,
    );

    // ... rest of build method using state and controller
  }
}
```

#### 2.2 EditHabitPage

**File:** `lib/features/settings/ui/pages/habits/habit_details_page.dart`

Simplify by passing HabitDefinition directly:

```dart
class EditHabitPage extends ConsumerWidget {
  const EditHabitPage({required this.habitId, super.key});
  final String habitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitAsync = ref.watch(habitByIdProvider(habitId));

    return habitAsync.when(
      data: (habitDefinition) {
        if (habitDefinition == null) {
          return const EmptyScaffoldWithTitle('');
        }
        return HabitDetailsPage(habitDefinition: habitDefinition);
      },
      loading: () => const EmptyScaffoldWithTitle(''),
      error: (_, __) => const EmptyScaffoldWithTitle(''),
    );
  }
}
```

Add a stream provider for watching habit by ID:

```dart
@riverpod
Stream<HabitDefinition?> habitById(Ref ref, String habitId) {
  return getIt<JournalDb>().watchHabitById(habitId);
}
```

#### 2.3 CreateHabitPage

**File:** `lib/features/settings/ui/pages/habits/habit_create_page.dart`

```dart
class CreateHabitPage extends StatelessWidget {
  CreateHabitPage({super.key});

  final _habitDefinition = HabitDefinition(
    id: uuid.v1(),
    name: '',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    description: '',
    private: false,
    vectorClock: null,
    habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
    version: '',
    active: true,
  );

  @override
  Widget build(BuildContext context) {
    return HabitDetailsPage(habitDefinition: _habitDefinition);
  }
}
```

#### 2.4 SelectCategoryWidget

**File:** `lib/features/habits/ui/widgets/habit_category.dart`

Convert to `ConsumerWidget`:

```dart
class SelectCategoryWidget extends ConsumerWidget {
  const SelectCategoryWidget({required this.habitDefinition, super.key});
  final HabitDefinition habitDefinition;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      habitSettingsControllerProvider(habitDefinition: habitDefinition),
    );

    return CategoryField(
      categoryId: state.habitDefinition.categoryId,
      onSave: (category) {
        ref
            .read(habitSettingsControllerProvider(habitDefinition: habitDefinition).notifier)
            .setCategory(category?.id);
      },
    );
  }
}
```

#### 2.5 SelectDashboardWidget

**File:** `lib/features/habits/ui/widgets/habit_dashboard.dart`

Convert to `ConsumerWidget`, also replace `StreamBuilder` with a provider:

```dart
@riverpod
Stream<List<DashboardDefinition>> habitDashboards(Ref ref) {
  return getIt<JournalDb>().watchDashboards();
}

class SelectDashboardWidget extends ConsumerWidget {
  const SelectDashboardWidget({required this.habitDefinition, super.key});
  final HabitDefinition habitDefinition;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardsAsync = ref.watch(habitDashboardsProvider);
    final state = ref.watch(
      habitSettingsControllerProvider(habitDefinition: habitDefinition),
    );

    // ... rest using dashboardsAsync.valueOrNull and state
  }
}
```

### Step 3: Clean Up Old Files

Delete after migration complete:
- `lib/blocs/settings/habits/habit_settings_cubit.dart`
- `lib/blocs/settings/habits/habit_settings_state.dart`
- `lib/blocs/settings/habits/habit_settings_state.freezed.dart`
- `lib/blocs/settings/habits/` directory (if empty)

Check if `lib/blocs/settings/` directory becomes empty and delete if so.

## Implementation Order

1. **Create new provider file**
   - `lib/features/habits/state/habit_settings_controller.dart`
2. **Run code generation** (`fvm flutter pub run build_runner build`)
3. **Update habit_details_page.dart** - Remove BlocProvider/BlocBuilder, pass habitDefinition as parameter
4. **Update habit_create_page.dart** - Simplify to just create habitDefinition and render page
5. **Update habit_category.dart** - Convert to ConsumerWidget
6. **Update habit_dashboard.dart** - Convert to ConsumerWidget, add dashboards provider
7. **Migrate tests** to Riverpod patterns
8. **Run analyzer and all tests**
9. **Delete old bloc files**
10. **Final verification**

## Files to Create

- `lib/features/habits/state/habit_settings_controller.dart`
- `lib/features/habits/state/habit_settings_controller.g.dart` (generated)
- `test/features/habits/state/habit_settings_controller_test.dart` (new tests)

## Files to Modify

- `lib/features/settings/ui/pages/habits/habit_details_page.dart` - Remove BlocProvider/BlocBuilder, use ConsumerWidget
- `lib/features/settings/ui/pages/habits/habit_create_page.dart` - Simplify to StatelessWidget
- `lib/features/habits/ui/widgets/habit_category.dart` - Convert to ConsumerWidget
- `lib/features/habits/ui/widgets/habit_dashboard.dart` - Convert to ConsumerWidget
- `test/features/settings/ui/pages/habits/habit_details_page_test.dart` - Update to use Riverpod overrides

## Files to Delete

- `lib/blocs/settings/habits/habit_settings_cubit.dart`
- `lib/blocs/settings/habits/habit_settings_state.dart`
- `lib/blocs/settings/habits/habit_settings_state.freezed.dart`
- `lib/blocs/settings/habits/` directory

## Test Strategy

### Unit Tests for New Controller

Following the established pattern with `ProviderContainer` and `fakeAsync`:

```dart
void main() {
  group('HabitSettingsController', () {
    late MockTagsService mockTagsService;
    late MockPersistenceLogic mockPersistenceLogic;
    late MockNotificationService mockNotificationService;
    late ProviderContainer container;
    late StreamController<List<TagEntity>> tagsController;

    setUp(() {
      mockTagsService = MockTagsService();
      mockPersistenceLogic = MockPersistenceLogic();
      mockNotificationService = MockNotificationService();
      tagsController = StreamController<List<TagEntity>>.broadcast();

      when(mockTagsService.watchTags).thenAnswer((_) => tagsController.stream);

      getIt
        ..registerSingleton<TagsService>(mockTagsService)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<NotificationService>(mockNotificationService);

      container = ProviderContainer();
    });

    tearDown(() async {
      await tagsController.close();
      container.dispose();
      await getIt.reset();
    });

    test('initializes with provided habit definition', () {
      fakeAsync((async) {
        final habit = testHabitDefinition;
        final state = container.read(
          habitSettingsControllerProvider(habitDefinition: habit),
        );

        expect(state.habitDefinition, equals(habit));
        expect(state.dirty, isFalse);
        expect(state.storyTags, isEmpty);
      });
    });

    test('setDirty marks form as dirty', () {
      fakeAsync((async) {
        final habit = testHabitDefinition;
        final controller = container.read(
          habitSettingsControllerProvider(habitDefinition: habit).notifier,
        );

        controller.setDirty();
        async.flushMicrotasks();

        final state = container.read(
          habitSettingsControllerProvider(habitDefinition: habit),
        );
        expect(state.dirty, isTrue);
      });
    });

    test('setCategory updates category and marks dirty', () {
      fakeAsync((async) {
        final habit = testHabitDefinition;
        final controller = container.read(
          habitSettingsControllerProvider(habitDefinition: habit).notifier,
        );

        controller.setCategory('new-category-id');
        async.flushMicrotasks();

        final state = container.read(
          habitSettingsControllerProvider(habitDefinition: habit),
        );
        expect(state.habitDefinition.categoryId, equals('new-category-id'));
        expect(state.dirty, isTrue);
      });
    });

    // ... more tests for setDashboard, setActiveFrom, setShowFrom, etc.
  });
}
```

### Widget Tests

Update existing tests to use Riverpod overrides:

```dart
testWidgets('habit details page is displayed & updated', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Override if needed
      ],
      child: makeTestableWidget(
        ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: 1000,
            maxWidth: 1000,
          ),
          child: HabitDetailsPage(habitDefinition: habitFlossing),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
  // ... assertions
});
```

### Test Coverage Targets

| Provider | Test Cases |
|----------|------------|
| `habitSettingsControllerProvider` | initial state, dirty flag, category/dashboard changes, schedule changes, save, delete, autocomplete rule removal |
| `habitByIdProvider` | habit found, habit not found, stream updates |
| `habitDashboardsProvider` | list loading, filtering |

**Target:** Match previous refactors with ~85%+ coverage on new provider code.

## Migration Complexity Assessment

| Aspect | Complexity | Notes |
|--------|------------|-------|
| Bloc Logic | **Medium** | Form state, tag subscription, schedule manipulation |
| UI Dependencies | **Medium** | 5 files use BlocBuilder/BlocProvider |
| Service Impact | **Low** | Uses existing PersistenceLogic and TagsService |
| Test Effort | **Medium** | Existing tests need Riverpod adaptation |

**Overall: MEDIUM COMPLEXITY** - Similar to Theming migration (PR #2551).

## Consistency with Previous Patterns

| Pattern | Dashboards | Theming | Habit Settings (Proposed) |
|---------|------------|---------|---------------------------|
| Stream Provider | `dashboardsProvider` | `enableTooltipsProvider` | `habitByIdProvider`, `habitDashboardsProvider` |
| Stateful Notifier | `SelectedCategoryIds` | `ThemingController` | `HabitSettingsController` |
| File Location | `lib/features/dashboards/state/` | `lib/features/theming/state/` | `lib/features/habits/state/` |
| Test Pattern | `fakeAsync` + `ProviderContainer` | Same | Same |
| keepAlive | No (auto-dispose) | **Yes** (app-wide) | No (per-form instance) |
| Family Provider | No | No | **Yes** (per habitDefinition) |

## CHANGELOG Entry (Draft)

```markdown
## [0.9.7XX] - YYYY-MM-DD
### Changed
- Migrated habit settings state management from Bloc to Riverpod
  - Replaced `HabitSettingsCubit` with `HabitSettingsController` notifier
  - Added `habitByIdProvider` for watching habit by ID
  - Added `habitDashboardsProvider` for dashboards in habit settings
  - Consistent with codebase-wide Riverpod adoption
```

---

## Workflow Phases

### Phase 1: Implementation

1. Create Riverpod providers following the patterns above
2. Update UI components to use Riverpod
3. Migrate existing tests to Riverpod patterns
4. Delete old BLoC files
5. Ensure all tests pass and analyzer is clean

### Phase 2: Pull Request

1. Create PR with title: `refactor: use Riverpod for habit settings state`
2. Include summary of changes following PR #2548, #2550, #2551 format
3. Reference this implementation plan in PR description

### Phase 3: Review

1. Address review comments from:
   - **Gemini** - AI code review
   - **CodeRabbit** - Automated review bot
2. Iterate until reviews are satisfied

### Phase 4: Merge

1. Ensure CI passes (all tests green)
2. Squash and merge to main branch

---

## Questions/Decisions (RESOLVED)

1. **Family Provider Parameter**: Use `habitId` (String) as parameter instead of `habitDefinition`. ✅
   - **Update**: Using `HabitDefinition` as parameter caused `InvalidType` in code generator
   - **Solution**: Followed `CategoryDetailsController` pattern with manual `AutoDisposeNotifierProvider.family`
   - For **edit** flow: habitId references existing habit in DB (watched via stream)
   - For **create** flow: habitId is a new UUID, controller initializes with empty habit

2. **Navigation Handling**: Return `bool` from `onSavePressed()` and handle navigation in the widget. ✅

3. **Widget Prop Drilling**: Pass `habitId` as a prop to child widgets (`SelectCategoryWidget`, `SelectDashboardWidget`). ✅

4. **Feature Directory**: All habit-related state files go in `lib/features/habits/state/`. UI pages in `lib/features/settings/` can import from there. ✅

## Implementation Notes

### Key Implementation Choices

1. **Manual Provider Definition**: Used `AutoDisposeNotifierProvider.family` instead of `@riverpod` annotation to avoid `InvalidType` code generation issue when using complex types as family parameters.

2. **Freezed State**: Used freezed for immutable state class with `copyWith` support.

3. **DB Watch on Build**: Controller watches `JournalDb.watchHabitById(habitId)` and updates state when habit changes (for edit flow). For create flow, returns null and uses empty habit definition.

4. **Mock Update**: Updated `mockJournalDbWithHabits` to provide fallback for any habit ID (returns null stream for create flow).

### Files Modified

- `lib/features/habits/state/habit_settings_controller.dart` - New controller with freezed state
- `lib/features/settings/ui/pages/habits/habit_details_page.dart` - Uses habitId, ConsumerWidget
- `lib/features/settings/ui/pages/habits/habit_create_page.dart` - Generates UUID upfront
- `lib/features/habits/ui/widgets/habit_category.dart` - Uses habitId
- `lib/features/habits/ui/widgets/habit_dashboard.dart` - Uses habitId
- `lib/features/settings/ui/widgets/habits/habit_autocomplete_widget.dart` - Uses habitId
- `test/mocks/mocks.dart` - Added fallback for any habitId in mock

### Files Deleted

- `lib/blocs/settings/habits/habit_settings_cubit.dart`
- `lib/blocs/settings/habits/habit_settings_state.dart`
- `lib/blocs/settings/habits/habit_settings_state.freezed.dart`
- `lib/blocs/settings/habits/` directory

## Approval Checklist

- [x] Implementation plan reviewed
- [x] Test strategy approved
- [x] File structure approved
- [x] Ready to proceed with implementation
- [x] All tests pass (10/10)
- [x] Analyzer clean
- [x] Formatter clean
