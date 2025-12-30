# Refactor HabitsCubit to Riverpod

## Status: COMPLETED (2025-12-30)

## Overview

Migrate the habits page state management from BLoC (`lib/blocs/habits/habits_cubit.dart`) to Riverpod, following the established patterns from recent migrations.

## Related Refactoring Plans

This is the fifth phase of the codebase-wide BLoC-to-Riverpod migration:

| Plan | Status | PR |
|------|--------|-----|
| [Theming Refactor](./2025-12-30_riverpod_theming_state.md) | Completed | [#2551](https://github.com/matthiasn/lotti/pull/2551) |
| [Habit Settings Refactor](./2025-12-30_riverpod_habit_settings.md) | Completed | [#2553](https://github.com/matthiasn/lotti/pull/2553) |
| [Audio Player Refactor](./2025-12-30_audio_player_riverpod_refactor.md) | Completed | [#2554](https://github.com/matthiasn/lotti/pull/2554) |

## Current State Analysis

### Files to Migrate/Delete

| File | Lines | Purpose |
|------|-------|---------|
| `lib/blocs/habits/habits_cubit.dart` | 444 | Cubit managing habits page state |
| `lib/blocs/habits/habits_state.dart` | 47 | Freezed state definition + HabitDisplayFilter enum |
| `lib/blocs/habits/habits_state.freezed.dart` | ~250 | Generated freezed code |

### Current HabitsCubit Logic

```dart
class HabitsCubit extends Cubit<HabitsState> {
  // Manages:
  // - Habit definitions list (from JournalDb stream)
  // - Habit completions in date range (from JournalDb)
  // - Computed habit lists: openNow, pendingLater, completed
  // - Completion tracking by day (successfulByDay, skippedByDay, failedByDay, allByDay)
  // - UI state: displayFilter, showSearch, showTimeSpan, searchString, selectedCategoryIds
  // - Chart state: timeSpanDays, zeroBased, minY, selectedInfoYmd, percentages
  // - Streak counts: shortStreakCount, longStreakCount
  // - Visibility tracking for performance optimization

  // Key subscriptions:
  // - _definitionsStream: watches active habit definitions
  // - _updateSubscription: listens for habit completion updates

  // Key methods:
  // - updateVisibility(VisibilityInfo) - tracks page visibility
  // - setTimeSpan(int days) - changes date range
  // - setDisplayFilter(HabitDisplayFilter?) - changes display mode
  // - setSearchString(String) - filters by search text
  // - toggleZeroBased() - chart axis toggle
  // - toggleShowSearch() - UI toggle
  // - toggleShowTimeSpan() - UI toggle
  // - toggleSelectedCategoryIds(String) - category filter toggle
  // - setInfoYmd(String) - sets selected day for chart info
}
```

### HabitsState Structure (Freezed)

```dart
enum HabitDisplayFilter { openNow, pendingLater, completed, all }

@freezed
abstract class HabitsState with _$HabitsState {
  factory HabitsState({
    required List<HabitDefinition> habitDefinitions,
    required List<HabitDefinition> openHabits,
    required List<HabitDefinition> openNow,
    required List<HabitDefinition> pendingLater,
    required List<HabitDefinition> completed,
    required List<JournalEntity> habitCompletions,
    required Set<String> completedToday,
    required Set<String> successfulToday,
    required Set<String> selectedCategoryIds,
    required List<String> days,
    required Map<String, Set<String>> successfulByDay,
    required Map<String, Set<String>> skippedByDay,
    required Map<String, Set<String>> failedByDay,
    required Map<String, Set<String>> allByDay,
    required int successPercentage,
    required int skippedPercentage,
    required int failedPercentage,
    required String selectedInfoYmd,
    required int shortStreakCount,
    required int longStreakCount,
    required int timeSpanDays,
    required double minY,
    required bool zeroBased,
    required bool isVisible,
    required bool showTimeSpan,
    required bool showSearch,
    required String searchString,
    required HabitDisplayFilter displayFilter,
  }) = _HabitsStateSaved;
}
```

### Current Registration & Provision

**BlocProvider (in `lib/beamer/locations/habits_location.dart:21-24`):**
```dart
BlocProvider<HabitsCubit>(
  create: (BuildContext context) => HabitsCubit(),
  child: const HabitsTabPage(),
)
```

Note: HabitsCubit is NOT registered in GetIt - it's created directly in the BlocProvider.

### Current Usage in Codebase

| Location | Usage Pattern |
|----------|---------------|
| `lib/beamer/locations/habits_location.dart` | Creates BlocProvider |
| `lib/features/habits/ui/habits_page.dart` | BlocBuilder + context.read, VisibilityDetector |
| `lib/features/habits/ui/widgets/habit_page_app_bar.dart` | BlocBuilder + context.read for app bar controls |
| `lib/features/habits/ui/widgets/habit_streaks.dart` | BlocBuilder for streak display |
| `lib/features/habits/ui/widgets/habits_filter.dart` | BlocBuilder + context.read for category filter |
| `lib/features/habits/ui/widgets/habits_search.dart` | BlocBuilder + context.read for search |
| `lib/widgets/charts/habits/habit_completion_rate_chart.dart` | BlocBuilder + context.read for chart |

### Existing Tests

| Test File | Tests | Purpose |
|-----------|-------|---------|
| `test/features/habits/ui/pages/habits_tab_page_test.dart` | 1 | Widget test for habits page |
| `test/beamer/locations/habits_location_test.dart` | 2 | Beamer location tests |

### Helper Functions (to keep as standalone)

These functions in `habits_cubit.dart` are pure utilities also used by the chart widget:
- `completionRate(HabitsState, Map<String, Set<String>>)` - calculates completion percentage
- `totalForDay(String ymd, HabitsState)` - counts active habits for a day
- `activeBy(List<HabitDefinition>, String ymd)` - filters habits active on date
- `minY(List<String> days, HabitsState)` - calculates chart Y-axis minimum
- `getDays(int timeSpanDays)` - generates list of date strings

## Proposed Riverpod Implementation

### Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Provider Type | `@Riverpod(keepAlive: true)` | Habits state should persist for app lifecycle, manages DB subscriptions |
| State Class | Freezed with `@freezed` | User preference, provides equality, copyWith, pattern matching |
| Helper Functions | Keep as standalone | Pure utilities used by chart widget |
| Visibility Tracking | Keep with VisibilityDetector | Same pattern, adapted for Riverpod |

### Step 1: Create Habits State Model

**File:** `lib/features/habits/state/habits_state.dart`

```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/charts/utils.dart';

part 'habits_state.freezed.dart';

enum HabitDisplayFilter { openNow, pendingLater, completed, all }

@freezed
abstract class HabitsState with _$HabitsState {
  factory HabitsState({
    required List<HabitDefinition> habitDefinitions,
    required List<HabitDefinition> openHabits,
    required List<HabitDefinition> openNow,
    required List<HabitDefinition> pendingLater,
    required List<HabitDefinition> completed,
    required List<JournalEntity> habitCompletions,
    required Set<String> completedToday,
    required Set<String> successfulToday,
    required Set<String> selectedCategoryIds,
    required List<String> days,
    required Map<String, Set<String>> successfulByDay,
    required Map<String, Set<String>> skippedByDay,
    required Map<String, Set<String>> failedByDay,
    required Map<String, Set<String>> allByDay,
    required int successPercentage,
    required int skippedPercentage,
    required int failedPercentage,
    required String selectedInfoYmd,
    required int shortStreakCount,
    required int longStreakCount,
    required int timeSpanDays,
    required double minY,
    required bool zeroBased,
    required bool isVisible,
    required bool showTimeSpan,
    required bool showSearch,
    required String searchString,
    required HabitDisplayFilter displayFilter,
  }) = _HabitsState;

  factory HabitsState.initial() => HabitsState(
        habitDefinitions: [],
        habitCompletions: [],
        completedToday: <String>{},
        openHabits: [],
        openNow: [],
        pendingLater: [],
        completed: [],
        days: getDays(isDesktop ? 14 : 7),
        successfulToday: <String>{},
        successfulByDay: <String, Set<String>>{},
        skippedByDay: <String, Set<String>>{},
        failedByDay: <String, Set<String>>{},
        allByDay: <String, Set<String>>{},
        selectedInfoYmd: '',
        successPercentage: 0,
        skippedPercentage: 0,
        failedPercentage: 0,
        shortStreakCount: 0,
        longStreakCount: 0,
        timeSpanDays: isDesktop ? 14 : 7,
        zeroBased: false,
        minY: 0,
        displayFilter: HabitDisplayFilter.openNow,
        showSearch: false,
        showTimeSpan: false,
        searchString: '',
        selectedCategoryIds: <String>{},
        isVisible: true,
      );
}

// Helper functions (kept as standalone, also used by chart widget)
int completionRate(HabitsState state, Map<String, Set<String>> byDay) {...}
int totalForDay(String ymd, HabitsState state) {...}
List<HabitDefinition> activeBy(List<HabitDefinition> habitDefinitions, String ymd) {...}
double minY({required List<String> days, required HabitsState state}) {...}
List<String> getDays(int timeSpanDays) {...}
```

### Step 2: Create Habits Controller

**File:** `lib/features/habits/state/habits_controller.dart`

```dart
import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:visibility_detector/visibility_detector.dart';

part 'habits_controller.g.dart';

/// Notifier managing the complete habits page state.
/// Marked as keepAlive since habits state should persist across navigation.
@Riverpod(keepAlive: true)
class HabitsController extends _$HabitsController {
  StreamSubscription<List<HabitDefinition>>? _definitionsSubscription;
  StreamSubscription<Set<String>>? _updateSubscription;

  List<HabitDefinition> _habitDefinitions = [];
  Map<String, HabitDefinition> _habitDefinitionsMap = {};
  List<JournalEntity> _habitCompletions = [];

  @override
  HabitsState build() {
    ref.onDispose(_cleanup);
    _init();
    return HabitsState.initial();
  }

  void _cleanup() {
    _definitionsSubscription?.cancel();
    _updateSubscription?.cancel();
    EasyDebounce.cancel('clearInfoYmd');
  }

  Future<void> _init() async {
    final journalDb = getIt<JournalDb>();

    _definitionsSubscription = journalDb.watchHabitDefinitions().listen(
      (habitDefinitions) {
        _habitDefinitions = habitDefinitions.where((h) => h.active).toList();
        _habitDefinitionsMap = {for (final h in _habitDefinitions) h.id: h};
        _determineHabitSuccessByDays();
      },
    );

    await _fetchHabitCompletions();
    _startWatchingUpdates();
  }

  // ... all methods from HabitsCubit converted to Riverpod patterns

  void updateVisibility(VisibilityInfo visibilityInfo) {...}
  Future<void> setTimeSpan(int timeSpanDays) async {...}
  void setDisplayFilter(HabitDisplayFilter? displayFilter) {...}
  void setSearchString(String searchString) {...}
  void toggleZeroBased() {...}
  void toggleShowSearch() {...}
  void toggleShowTimeSpan() {...}
  void toggleSelectedCategoryIds(String categoryId) {...}
  void setInfoYmd(String ymd) {...}
}
```

### Step 3: Update UI Components

#### 3a. HabitsLocation

**File:** `lib/beamer/locations/habits_location.dart`

Remove BlocProvider wrapper:

```dart
// Before
child: BlocProvider<HabitsCubit>(
  create: (BuildContext context) => HabitsCubit(),
  child: const HabitsTabPage(),
)

// After
child: const HabitsTabPage()
```

#### 3b. HabitsTabPage

**File:** `lib/features/habits/ui/habits_page.dart`

Convert to `ConsumerStatefulWidget`:

```dart
class HabitsTabPage extends ConsumerStatefulWidget {
  const HabitsTabPage({super.key});

  @override
  ConsumerState<HabitsTabPage> createState() => _HabitsTabPageState();
}

class _HabitsTabPageState extends ConsumerState<HabitsTabPage> {
  final _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(habitsControllerProvider);
    final controller = ref.read(habitsControllerProvider.notifier);

    return VisibilityDetector(
      key: const Key('habits_page'),
      onVisibilityChanged: controller.updateVisibility,
      child: // ... rest of build using state and controller
    );
  }
}
```

#### 3c. HabitsSliverAppBar

**File:** `lib/features/habits/ui/widgets/habit_page_app_bar.dart`

Convert to `ConsumerWidget`:

```dart
class HabitsSliverAppBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(habitsControllerProvider);
    final controller = ref.read(habitsControllerProvider.notifier);
    // ...
  }
}
```

#### 3d. HabitStreaksCounter

**File:** `lib/features/habits/ui/widgets/habit_streaks.dart`

Convert to `ConsumerWidget`:

```dart
class HabitStreaksCounter extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(habitsControllerProvider);
    // ...
  }
}
```

#### 3e. HabitsFilter

**File:** `lib/features/habits/ui/widgets/habits_filter.dart`

Convert to `ConsumerWidget`, handle modal sheet provider access:

```dart
class HabitsFilter extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(habitsControllerProvider);
    final controller = ref.read(habitsControllerProvider.notifier);

    // For modal bottom sheet, use Consumer inside
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return Consumer(
          builder: (context, ref, child) {
            final modalState = ref.watch(habitsControllerProvider);
            // ...
          },
        );
      },
    );
  }
}
```

#### 3f. HabitsSearchWidget

**File:** `lib/features/habits/ui/widgets/habits_search.dart`

Convert to `ConsumerWidget`:

```dart
class HabitsSearchWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(habitsControllerProvider);
    final controller = ref.read(habitsControllerProvider.notifier);
    // ...
  }
}
```

#### 3g. HabitCompletionRateChart

**File:** `lib/widgets/charts/habits/habit_completion_rate_chart.dart`

Convert to `ConsumerWidget`:

```dart
class HabitCompletionRateChart extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(habitsControllerProvider);
    final controller = ref.read(habitsControllerProvider.notifier);
    // ...
  }
}
```

### Step 4: Delete Legacy Files

After migration:
- `lib/blocs/habits/habits_cubit.dart`
- `lib/blocs/habits/habits_state.dart`
- `lib/blocs/habits/habits_state.freezed.dart`
- `lib/blocs/habits/` directory

### Step 5: Update Tests

#### 5a. habits_tab_page_test.dart

Replace `BlocProvider<HabitsCubit>` with `ProviderScope` and provider overrides:

```dart
testWidgets('habits page is rendered', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        habitsControllerProvider.overrideWith(() => MockHabitsController()),
      ],
      child: makeTestableWidgetWithScaffold(
        const HabitsTabPage(),
      ),
    ),
  );
  // ...
});
```

#### 5b. habits_location_test.dart

Update expectations for new widget structure (no BlocProvider wrapper):

```dart
test('buildPages builds HabitsTabPage', () {
  final pages = location.buildPages(mockBuildContext, beamState);
  expect(pages.length, 1);
  expect(pages[0].child, isA<HabitsTabPage>()); // No longer wrapped in BlocProvider
});
```

## Implementation Order

1. **Create state file** - `lib/features/habits/state/habits_state.dart`
2. **Create controller file** - `lib/features/habits/state/habits_controller.dart`
3. **Run code generation** - `fvm dart run build_runner build --delete-conflicting-outputs`
4. **Update habits_location.dart** - Remove BlocProvider
5. **Update habits_page.dart** - ConsumerStatefulWidget
6. **Update habit_page_app_bar.dart** - ConsumerWidget
7. **Update habit_streaks.dart** - ConsumerWidget
8. **Update habits_filter.dart** - ConsumerWidget
9. **Update habits_search.dart** - ConsumerWidget
10. **Update habit_completion_rate_chart.dart** - ConsumerWidget
11. **Update tests** - Riverpod patterns
12. **Run analyzer and tests**
13. **Delete old bloc files**
14. **Final verification** - dart fix, dart format

## Files to Create

| File | Purpose |
|------|---------|
| `lib/features/habits/state/habits_state.dart` | Freezed state class + HabitDisplayFilter enum + helper functions |
| `lib/features/habits/state/habits_state.freezed.dart` | Generated freezed code |
| `lib/features/habits/state/habits_controller.dart` | Riverpod controller |
| `lib/features/habits/state/habits_controller.g.dart` | Generated Riverpod code |

## Files to Modify

| File | Changes |
|------|---------|
| `lib/beamer/locations/habits_location.dart` | Remove BlocProvider wrapper |
| `lib/features/habits/ui/habits_page.dart` | BlocBuilder → ConsumerStatefulWidget |
| `lib/features/habits/ui/widgets/habit_page_app_bar.dart` | BlocBuilder → ConsumerWidget |
| `lib/features/habits/ui/widgets/habit_streaks.dart` | BlocBuilder → ConsumerWidget |
| `lib/features/habits/ui/widgets/habits_filter.dart` | BlocBuilder → ConsumerWidget + Consumer |
| `lib/features/habits/ui/widgets/habits_search.dart` | BlocBuilder → ConsumerWidget |
| `lib/widgets/charts/habits/habit_completion_rate_chart.dart` | BlocBuilder → ConsumerWidget |
| `test/features/habits/ui/pages/habits_tab_page_test.dart` | BlocProvider → ProviderScope |
| `test/beamer/locations/habits_location_test.dart` | Update expectations |

## Files to Delete

| File | Reason |
|------|--------|
| `lib/blocs/habits/habits_cubit.dart` | Replaced by controller |
| `lib/blocs/habits/habits_state.dart` | Moved to features/habits/state |
| `lib/blocs/habits/habits_state.freezed.dart` | Regenerated in new location |
| `lib/blocs/habits/` directory | Empty after deletion |

## Test Strategy

### Unit Tests for HabitsController

Following established patterns with `ProviderContainer` and `fakeAsync`:

```dart
void main() {
  group('HabitsController', () {
    late MockJournalDb mockJournalDb;
    late MockUpdateNotifications mockUpdateNotifications;
    late ProviderContainer container;
    late StreamController<List<HabitDefinition>> definitionsController;
    late StreamController<Set<String>> updateController;

    setUp(() {
      mockJournalDb = MockJournalDb();
      mockUpdateNotifications = MockUpdateNotifications();
      definitionsController = StreamController.broadcast();
      updateController = StreamController.broadcast();

      when(mockJournalDb.watchHabitDefinitions)
          .thenAnswer((_) => definitionsController.stream);
      when(mockUpdateNotifications.updateStream)
          .thenAnswer((_) => updateController.stream);

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications);

      container = ProviderContainer();
    });

    test('initial state has expected defaults', () {...});
    test('setDisplayFilter updates filter', () {...});
    test('setTimeSpan updates days and refetches completions', () {...});
    test('toggleSelectedCategoryIds adds and removes categories', () {...});
    // ... more tests
  });
}
```

### Coverage Targets

| Requirement | Target |
|-------------|--------|
| Minimum coverage | **90%** |
| Goal coverage | **95%** |

## Migration Complexity Assessment

| Aspect | Complexity | Notes |
|--------|------------|-------|
| Cubit Logic | **High** | 444 lines, complex state calculations, multiple streams |
| UI Dependencies | **High** | 7 widgets use BlocBuilder/context.read |
| Service Impact | **Low** | Uses existing JournalDb and UpdateNotifications |
| Test Effort | **Medium** | 3 existing tests to migrate |

**Overall: HIGH COMPLEXITY** - Most complex migration so far due to extensive state calculations.

## Quality Gates

### Pre-Implementation
- [x] Implementation plan reviewed and approved

### During Implementation
- [ ] Run analyzer after each file change: `fvm flutter analyze`
- [ ] Run tests frequently: `fvm flutter test test/features/habits/`
- [ ] Run dart fix: `fvm dart fix --apply`
- [ ] Run dart format: `fvm dart format lib/features/habits/ lib/widgets/charts/habits/`

### Post-Implementation
- [ ] All existing tests pass (no regressions)
- [ ] New controller tests achieve ≥90% coverage
- [ ] Analyzer shows zero issues
- [ ] dart format shows no changes needed
- [ ] Manual testing of habits page in app

## CHANGELOG Entry (Draft)

```markdown
## [0.9.7XX] - YYYY-MM-DD
### Changed
- Migrated habits page state management from Bloc to Riverpod
  - Replaced `HabitsCubit` with `HabitsController` notifier
  - Consistent with codebase-wide Riverpod adoption
```

---

## Approval Checklist

- [x] Implementation plan reviewed
- [x] State class to use Freezed (user preference)
- [x] Test strategy approved
- [x] File structure approved
- [x] Ready to proceed with implementation
- [x] Implementation completed
- [x] All tests pass
- [x] Analyzer clean
- [x] Formatter clean

## Completion Summary

### Files Created
- `lib/features/habits/state/habits_state.dart` - Freezed state with HabitDisplayFilter enum and helper functions
- `lib/features/habits/state/habits_state.freezed.dart` - Generated code
- `lib/features/habits/state/habits_controller.dart` - Riverpod controller with keepAlive
- `lib/features/habits/state/habits_controller.g.dart` - Generated code

### Files Modified
- `lib/beamer/locations/habits_location.dart` - Removed BlocProvider wrapper
- `lib/features/habits/ui/habits_page.dart` - ConsumerStatefulWidget
- `lib/features/habits/ui/widgets/habit_page_app_bar.dart` - ConsumerWidget
- `lib/features/habits/ui/widgets/habit_streaks.dart` - ConsumerWidget
- `lib/features/habits/ui/widgets/habits_filter.dart` - ConsumerWidget with Consumer for modal
- `lib/features/habits/ui/widgets/habits_search.dart` - ConsumerWidget
- `lib/features/habits/ui/widgets/status_segmented_control.dart` - Updated import
- `lib/widgets/charts/habits/habit_completion_rate_chart.dart` - ConsumerWidget
- `test/features/habits/ui/pages/habits_tab_page_test.dart` - Riverpod overrides
- `test/beamer/locations/habits_location_test.dart` - Updated expectations

### Files Deleted
- `lib/blocs/habits/habits_cubit.dart`
- `lib/blocs/habits/habits_state.dart`
- `lib/blocs/habits/habits_state.freezed.dart`
- `lib/blocs/habits/` directory
