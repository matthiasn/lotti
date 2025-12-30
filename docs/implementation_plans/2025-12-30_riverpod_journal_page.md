# Refactor JournalPageCubit to Riverpod

## Status: PLANNING

## Overview

Migrate the journal page state management from BLoC (`lib/blocs/journal/journal_page_cubit.dart`) to Riverpod, following the patterns established in:
- **PR #2554**: Audio Player refactor (merged 2025-12-30) - *Gold Standard* - [GitHub](https://github.com/matthiasn/lotti/pull/2554)
- **PR #2553**: Habit Settings refactor (merged 2025-12-30) - [GitHub](https://github.com/matthiasn/lotti/pull/2553)
- **PR #2551**: Theming refactor (merged 2025-12-30) - [GitHub](https://github.com/matthiasn/lotti/pull/2551)
- **PR #2550**: Sync outbox refactor (merged 2025-12-30) - [GitHub](https://github.com/matthiasn/lotti/pull/2550)
- **PR #2548**: Dashboards refactor (merged 2025-12-29) - [GitHub](https://github.com/matthiasn/lotti/pull/2548)

This is part of the codebase-wide BLoC-to-Riverpod migration initiative.

---

## Key Architectural Decisions

These decisions address the review questions and guide implementation:

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Provider Lifecycle** | `keepAlive: true` | Preserves state when switching between Tasks and Journal tabs; user expects filters to persist during session |
| **Provider Scoping** | Scoped `ProviderScope` override at page level | Avoids explicit `showTasks` constructor threading through 13+ widgets; cleaner than InheritedWidget |
| **Scope Provider Type** | Plain `Provider<bool>` (not @riverpod) | Simpler for scoped overrides; no codegen needed |
| **Service Access** | Maintain GetIt for now, migrate incrementally | Changing all services to Riverpod in one PR is too risky; GetIt works for existing services |
| **Family Key** | `bool showTasks` | Simple, clear distinction between tabs |
| **entryTypes Location** | Move to shared constants file | Avoids import cycle with entry_type_gating.dart |
| **selectedTaskStatuses** | Same default for both tabs | Matches cubit behavior; tests verify journal tab has default statuses |
| **Initial fetchNextPage()** | Call immediately after controller creation | Matches cubit constructor behavior; required for first-load timing |

### Provider Scoping Strategy

Instead of threading `showTasks` through every widget constructor, use a scoped provider pattern.

**Decision: Use plain `Provider<bool>` (not @riverpod codegen)** - simpler for scoped overrides.

```dart
// lib/features/journal/state/journal_page_scope.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Scoped provider that holds the showTasks value for the current page subtree.
/// Must be overridden in a ProviderScope at the page level.
final journalPageScopeProvider = Provider<bool>((ref) {
  throw UnimplementedError(
    'journalPageScopeProvider must be overridden in a ProviderScope',
  );
});

// In InfiniteJournalPage:
class InfiniteJournalPage extends ConsumerWidget {
  const InfiniteJournalPage({required this.showTasks, super.key});
  final bool showTasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProviderScope(
      overrides: [
        journalPageScopeProvider.overrideWithValue(showTasks),
      ],
      child: const InfiniteJournalPageBody(),
    );
  }
}

// In any child widget (no showTasks parameter needed):
class TaskCategoryFilter extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTasks = ref.watch(journalPageScopeProvider);
    final state = ref.watch(journalPageControllerProvider(showTasks));
    final controller = ref.read(journalPageControllerProvider(showTasks).notifier);
    // ...
  }
}
```

This pattern:
- Eliminates explicit `showTasks` threading through 13+ widgets
- Widgets read `journalPageScopeProvider` to get the correct family key
- Matches the existing BlocProvider context-based approach

---

## Current State Analysis

### Files in lib/blocs/journal/

| File | Lines | Purpose |
|------|-------|---------|
| `journal_page_cubit.dart` | 648 | Complex cubit managing journal/task page state |
| `journal_page_state.dart` | 58 | Freezed state + DisplayFilter/TaskSortOption enums + TasksFilter |
| `journal_page_state.freezed.dart` | ~generated | Generated freezed code |
| `journal_page_state.g.dart` | ~generated | Generated JSON serialization |

### Critical: entryTypes Constant Location

**Problem:** `entryTypes` is defined in `journal_page_cubit.dart:633` and imported by `entry_type_gating.dart:1`. Moving it into the new controller while importing `entry_type_gating` creates an import cycle.

**Solution:** Move `entryTypes` to a dedicated shared constants file:

```dart
// lib/features/journal/utils/entry_types.dart
/// Entry types available for filtering journal entries.
/// Used by both the controller and entry_type_gating utilities.
const List<String> entryTypes = [
  'Task',
  'JournalEntry',
  'JournalEvent',
  'JournalAudio',
  'JournalImage',
  'MeasurementEntry',
  'SurveyEntry',
  'WorkoutEntry',
  'HabitCompletionEntry',
  'QuantitativeEntry',
  'Checklist',
  'ChecklistItem',
  'AiResponse',
];
```

Then update imports:
- `entry_type_gating.dart` imports from `entry_types.dart`
- `journal_page_controller.dart` imports from `entry_types.dart`
- Tests that reference `entryTypes` import from `entry_types.dart`

### Current JournalPageCubit Logic

The `JournalPageCubit` is the **most complex cubit** in the codebase, managing:

```dart
class JournalPageCubit extends Cubit<JournalPageState> {
  // Core State Management:
  // - Pagination with infinite_scroll_pagination PagingController
  // - Full-text search via FTS5 database
  // - Multiple filter dimensions (categories, labels, priorities, task statuses, entry types)
  // - Display filters (starred, flagged, private)
  // - Sort options (byPriority, byDate)
  // - Feature flag handling (events, habits, dashboards)

  // Stream Subscriptions:
  // - _configFlagsSub: Watches feature flags
  // - _privateFlagSub: Watches private mode toggle
  // - _updatesSub: Watches UpdateNotifications for entry changes

  // Platform Features:
  // - Desktop hotkey registration (Cmd+R for refresh)
  // - Visibility detection for smart refresh

  // Persistence:
  // - Filter state persisted to SettingsDb
  // - Per-tab category filters (tasks vs journal)
  // - Legacy migration support
}
```

### JournalPageState Structure

```dart
enum DisplayFilter { starredEntriesOnly, flaggedEntriesOnly, privateEntriesOnly }
enum TaskSortOption { byPriority, byDate }

@freezed
abstract class JournalPageState with _$JournalPageState {
  factory JournalPageState({
    required String match,
    required Set<String> tagIds,
    required Set<DisplayFilter> filters,
    required bool showPrivateEntries,
    required bool showTasks,
    required List<String> selectedEntryTypes,
    required Set<String> fullTextMatches,
    required PagingController<int, JournalEntity>? pagingController,
    required List<String> taskStatuses,
    required Set<String> selectedTaskStatuses,
    required Set<String?> selectedCategoryIds,
    required Set<String> selectedLabelIds,
    @Default(<String>{}) Set<String> selectedPriorities,
    @Default(TaskSortOption.byPriority) TaskSortOption sortOption,
    @Default(false) bool showCreationDate,
  }) = _JournalPageState;
}
```

### TasksFilter - Cross-Feature Dependency

**Important:** `TasksFilter` is not only used by the journal cubit but also by:

| Consumer | File | Usage |
|----------|------|-------|
| CalendarCategoryVisibilityController | `lib/features/calendar/state/calendar_category_visibility_controller.dart:4` | Reads `TasksFilter` from SettingsDb to share visibility state with Tasks page |
| Calendar tests | `test/features/calendar/state/calendar_category_visibility_controller_test.dart:6` | Tests filter parsing |

**Decision:** Keep `TasksFilter` in the new `journal_page_state.dart` location. Update imports in calendar feature.

---

## Pagination & Update Notification Logic (CRITICAL)

These behaviors **must be preserved exactly** as they are critical to performance and UX:

### Custom Pagination Key Logic (`journal_page_cubit.dart:70-101`)

```dart
// MUST PRESERVE: Custom getNextPageKey implementation
final controller = PagingController<int, JournalEntity>(
  getNextPageKey: (PagingState<int, JournalEntity> state) {
    final currentKeys = state.keys;
    if (currentKeys == null || currentKeys.isEmpty) {
      return 0; // First page key (offset)
    }
    if (!state.hasNextPage) {
      return null; // No next page if controller says so
    }
    final currentPages = state.pages;
    // If last page had fewer items than _pageSize, it's the last page
    if (currentPages != null &&
        currentPages.isNotEmpty &&
        currentPages.last.length < _pageSize) {
      return null; // No more pages
    }
    if (currentPages != null &&
        currentPages.isNotEmpty &&
        currentKeys.length == currentPages.length) {
      final lastFetchedItemsCount = currentPages.last.length;
      return currentKeys.last + lastFetchedItemsCount;
    }
    // Fallback: if keys exist but pages inconsistent or last page empty.
    return currentKeys.last +
        ((currentPages != null &&
                currentPages.isNotEmpty &&
                currentKeys.length == currentPages.length)
            ? currentPages.last.length
            : 0);
  },
  fetchPage: _fetchPage,
);
```

### Throttled UpdateNotifications with Task ID Comparison (`journal_page_cubit.dart:206-232`)

```dart
// MUST PRESERVE: Throttled update handling with smart refresh logic
_updatesSub = _updateNotifications.updateStream
    .throttleTime(
      const Duration(milliseconds: 500),
      leading: false,
      trailing: true,
    )
    .listen((affectedIds) async {
      if (_isVisible) {
        final displayedIds =
            state.pagingController?.value.items?.map(idMapper).toSet() ??
                <String>{};

        if (showTasks) {
          // For tasks: check if task list changed (new/removed tasks)
          final newIds = (await _runQuery(0)).map(idMapper).toSet();
          if (!setEquals(_lastIds, newIds)) {
            _lastIds = newIds;
            await refreshQuery();
          } else if (displayedIds.intersection(affectedIds).isNotEmpty) {
            await refreshQuery();
          }
        } else {
          // For journal: only refresh if displayed entries are affected
          if (displayedIds.intersection(affectedIds).isNotEmpty) {
            await refreshQuery();
          }
        }
      }
    });
```

**Key Behaviors:**
1. **500ms throttle** with trailing: Batches rapid updates
2. **Visibility check**: Only refreshes when page is visible
3. **Task ID comparison**: For tasks tab, compares current IDs to detect list changes
4. **Intersection check**: Only refreshes if displayed entries are affected

---

## Persistence & Migration Details (CRITICAL)

### Storage Keys

| Key | Purpose | Used By |
|-----|---------|---------|
| `TASK_FILTERS` | Legacy key for migration | Load only (fallback) |
| `TASKS_CATEGORY_FILTERS` | Per-tab filters for Tasks page | Tasks tab (save/load) |
| `JOURNAL_CATEGORY_FILTERS` | Per-tab filters for Journal page | Journal tab (save/load) |
| `SELECTED_ENTRY_TYPES` | Entry type selection | Both tabs (save/load) |

### Persistence Logic (`journal_page_cubit.dart:235-415`)

```dart
// Key selection based on tab
String _getCategoryFiltersKey() {
  return showTasks ? tasksCategoryFiltersKey : journalCategoryFiltersKey;
}

// Persistence includes:
// - selectedCategoryIds
// - selectedTaskStatuses (tasks tab only)
// - selectedLabelIds (tasks tab only)
// - selectedPriorities (tasks tab only)
// - sortOption (tasks tab only)
// - showCreationDate (tasks tab only)

// Migration: Falls back to legacy TASK_FILTERS key if per-tab key not found
```

### What Gets Persisted Per Tab

| Field | Tasks Tab | Journal Tab |
|-------|-----------|-------------|
| selectedCategoryIds | Yes | Yes |
| selectedTaskStatuses | Yes | No |
| selectedLabelIds | Yes | No |
| selectedPriorities | Yes | No |
| sortOption | Yes | No |
| showCreationDate | Yes | No |

---

## Feature Flag Alignment

### Current: EntryTypeFilter uses configFlagProvider

`lib/widgets/search/entry_type_filter.dart:20` already uses Riverpod:

```dart
final enableEventsAsync = ref.watch(configFlagProvider(enableEventsFlag));
final enableHabitsAsync = ref.watch(configFlagProvider(enableHabitsPageFlag));
final enableDashboardsAsync = ref.watch(configFlagProvider(enableDashboardsPageFlag));
```

### Strategy: Align with existing configFlagProvider

The new controller should **not** create a duplicate `activeConfigFlagsProvider`. Instead:

1. **Option A (Recommended):** Use the existing `configFlagProvider` for individual flags in the controller
2. **Option B:** Create an internal stream subscription as the cubit does (maintains current behavior)

For this migration, **Option B** is safer - maintain internal stream subscription to preserve exact behavior. The `activeConfigFlagsProvider` in the original plan can be removed; it's not needed if we keep the internal subscription.

---

## Complete File Inventory

### Files to Create

| File | Purpose |
|------|---------|
| `lib/features/journal/utils/entry_types.dart` | Shared `entryTypes` constant (fixes import cycle) |
| `lib/features/journal/state/journal_page_scope.dart` | Scoped provider for `showTasks` (plain Provider, no codegen) |
| `lib/features/journal/state/journal_page_controller.dart` | New Riverpod controller |
| `lib/features/journal/state/journal_page_controller.g.dart` | Generated (build_runner) |
| `lib/features/journal/state/journal_page_state.dart` | State class and enums |
| `lib/features/journal/state/journal_page_state.freezed.dart` | Generated (build_runner) |
| `lib/features/journal/state/journal_page_state.g.dart` | Generated (build_runner) |
| `test/features/journal/state/journal_page_controller_test.dart` | Comprehensive unit tests |

### Files to Modify - Complete Inventory

#### UI Components (13+ widgets)

| File | Changes |
|------|---------|
| `lib/features/journal/ui/pages/infinite_journal_page.dart:75` | BlocProvider → ProviderScope with scoped override |
| `lib/widgets/app_bar/journal_sliver_appbar.dart:22` | BlocBuilder → Consumer, read scope |
| `lib/features/tasks/ui/filtering/task_category_filter.dart` | BlocBuilder → Consumer, read scope |
| `lib/features/tasks/ui/filtering/task_status_filter.dart` | BlocBuilder → Consumer, read scope |
| `lib/features/tasks/ui/filtering/task_priority_filter.dart` | BlocBuilder → Consumer, read scope |
| `lib/features/tasks/ui/filtering/task_label_filter.dart` | BlocBuilder → Consumer, read scope |
| `lib/features/tasks/ui/filtering/task_label_quick_filter.dart` | BlocBuilder → Consumer, read scope |
| `lib/widgets/search/entry_type_filter.dart:50` | BlocBuilder → Consumer, read scope |
| `lib/features/tasks/ui/filtering/task_filter_icon.dart:25` | BlocBuilder → Consumer, read scope |
| `lib/features/tasks/ui/filtering/task_sort_filter.dart` | BlocBuilder → Consumer, read scope |
| `lib/features/tasks/ui/filtering/task_date_display_toggle.dart` | BlocBuilder → Consumer, read scope |
| `lib/features/ai_chat/ui/widgets/ai_chat_icon.dart:14` | BlocBuilder → Consumer, read scope |
| `lib/features/ai_chat/ui/pages/chat_modal_page.dart:8` | BlocBuilder → Consumer, read scope |

#### Utility Files

| File | Changes |
|------|---------|
| `lib/features/journal/utils/entry_type_gating.dart:1` | Update import from `journal_page_cubit.dart` to `entry_types.dart` |

#### Cross-Feature Dependencies

| File | Changes |
|------|---------|
| `lib/features/calendar/state/calendar_category_visibility_controller.dart:4` | Update import from `blocs/journal/journal_page_state.dart` to `features/journal/state/journal_page_state.dart` |

#### Documentation

| File | Changes |
|------|---------|
| `lib/features/tasks/README.md:12` | Update reference from `JournalPageCubit`/`JournalPageState` to new Riverpod controller |

#### Tests - Complete List

| Test File | Changes |
|-----------|---------|
| `test/blocs/journal/journal_page_cubit_test.dart` | Migrate to ProviderContainer |
| `test/blocs/journal/journal_page_cubit_persistence_test.dart` | Migrate to ProviderContainer |
| `test/blocs/journal/journal_page_cubit_priorities_test.dart` | Migrate to ProviderContainer |
| `test/blocs/journal/journal_page_state_test.dart` | Update imports only |
| `test/features/journal/ui/pages/infinite_journal_page_test.dart:6,46` | Update imports, use ProviderScope overrides, update `entryTypes` import |
| `test/features/calendar/state/calendar_category_visibility_controller_test.dart:6` | Update TasksFilter import path |
| `test/widgets/search/entry_type_filter_test.dart:6` | Update imports, use ProviderScope overrides |
| `test/features/ai_chat/ui/pages/chat_modal_page_test.dart:8` | Update imports, use ProviderScope overrides |
| Widget tests in `test/features/tasks/ui/filtering/` | Update imports, use ProviderScope overrides |

### Files to Delete

| File | Reason |
|------|--------|
| `lib/blocs/journal/journal_page_cubit.dart` | Replaced by controller |
| `lib/blocs/journal/journal_page_state.dart` | State moved to new location |
| `lib/blocs/journal/journal_page_state.freezed.dart` | Regenerated at new location |
| `lib/blocs/journal/journal_page_state.g.dart` | Regenerated at new location |
| `lib/blocs/journal/` directory | Empty after migration |

---

## Proposed Riverpod Implementation

### Provider Architecture

```
                    +---------------------------+
                    | journalPageScopeProvider  |
                    | (scoped bool showTasks)   |
                    +---------------------------+
                              |
                    +---------------------------+
                    | journalPageControllerProvider |
                    | (family: showTasks)       |
                    | keepAlive: true           |
                    +---------------------------+
                              |
        +--------------------+--------------------+
        |                    |                    |
  (internal)           (internal)           (internal)
  configFlags          privateFlag          updateNotifications
  subscription         subscription         subscription
```

### Step 1: Create Entry Types Constants

**File:** `lib/features/journal/utils/entry_types.dart`

```dart
/// Entry types available for filtering journal entries.
///
/// Used by:
/// - JournalPageController for filter state
/// - entry_type_gating.dart for computing allowed types
/// - Tests that reference entry types directly
const List<String> entryTypes = [
  'Task',
  'JournalEntry',
  'JournalEvent',
  'JournalAudio',
  'JournalImage',
  'MeasurementEntry',
  'SurveyEntry',
  'WorkoutEntry',
  'HabitCompletionEntry',
  'QuantitativeEntry',
  'Checklist',
  'ChecklistItem',
  'AiResponse',
];
```

### Step 2: Create Journal Page Scope Provider

**File:** `lib/features/journal/state/journal_page_scope.dart`

**Note:** Uses plain `Provider<bool>` (not @riverpod codegen) for simpler scoped overrides.

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Scoped provider that holds the showTasks value for the current page subtree.
///
/// Must be overridden in a ProviderScope at the page level:
/// ```dart
/// ProviderScope(
///   overrides: [journalPageScopeProvider.overrideWithValue(showTasks)],
///   child: ...,
/// )
/// ```
///
/// Child widgets can then read:
/// ```dart
/// final showTasks = ref.watch(journalPageScopeProvider);
/// final controller = ref.read(journalPageControllerProvider(showTasks).notifier);
/// ```
final journalPageScopeProvider = Provider<bool>((ref) {
  throw UnimplementedError(
    'journalPageScopeProvider must be overridden in a ProviderScope',
  );
});
```

### Step 3: Create Journal Page State Model

**File:** `lib/features/journal/state/journal_page_state.dart`

```dart
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/classes/journal_entities.dart';

part 'journal_page_state.freezed.dart';
part 'journal_page_state.g.dart';

/// Display filter options for journal entries
enum DisplayFilter {
  starredEntriesOnly,
  flaggedEntriesOnly,
  privateEntriesOnly,
}

/// Sort order options for task lists
enum TaskSortOption {
  /// Sort by priority first (P0 > P1 > P2 > P3), then by date
  byPriority,
  /// Sort by creation date (newest first)
  byDate,
}

/// Immutable state for the journal page controller.
@freezed
abstract class JournalPageState with _$JournalPageState {
  const factory JournalPageState({
    @Default('') String match,
    @Default(<String>{}) Set<String> tagIds,
    @Default(<DisplayFilter>{}) Set<DisplayFilter> filters,
    @Default(false) bool showPrivateEntries,
    @Default(false) bool showTasks,
    @Default([]) List<String> selectedEntryTypes,
    @Default(<String>{}) Set<String> fullTextMatches,
    @JsonKey(includeFromJson: false, includeToJson: false)
    PagingController<int, JournalEntity>? pagingController,
    @Default([]) List<String> taskStatuses,
    @Default(<String>{}) Set<String> selectedTaskStatuses,
    @Default(<String?>{}) Set<String?> selectedCategoryIds,
    @Default(<String>{}) Set<String> selectedLabelIds,
    @Default(<String>{}) Set<String> selectedPriorities,
    @Default(TaskSortOption.byPriority) TaskSortOption sortOption,
    @Default(false) bool showCreationDate,
  }) = _JournalPageState;
}

/// Filter configuration for persistence.
///
/// Used by:
/// - JournalPageController for persisting filter state
/// - CalendarCategoryVisibilityController for reading shared category visibility
@freezed
abstract class TasksFilter with _$TasksFilter {
  const factory TasksFilter({
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

### Step 4: Create Journal Page Controller

**File:** `lib/features/journal/state/journal_page_controller.dart`

```dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/journal/utils/entry_type_gating.dart';
import 'package:lotti/features/journal/utils/entry_types.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/platform.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:visibility_detector/visibility_detector.dart';

part 'journal_page_controller.g.dart';

/// Controller for managing journal/tasks page state.
///
/// Uses a family provider pattern with showTasks as the family key.
/// keepAlive: true to preserve state when switching tabs.
@Riverpod(keepAlive: true)
class JournalPageController extends _$JournalPageController {
  // Storage keys
  static const taskFiltersKey = 'TASK_FILTERS'; // Legacy key for migration
  static const tasksCategoryFiltersKey = 'TASKS_CATEGORY_FILTERS';
  static const journalCategoryFiltersKey = 'JOURNAL_CATEGORY_FILTERS';
  static const selectedEntryTypesKey = 'SELECTED_ENTRY_TYPES';
  static const _pageSize = 50;

  // Services (via GetIt for now)
  late final JournalDb _db;
  late final SettingsDb _settingsDb;
  late final Fts5Db _fts5Db;
  late final UpdateNotifications _updateNotifications;
  late final EntitiesCacheService _entitiesCacheService;

  // Stream subscriptions
  StreamSubscription<Set<String>>? _configFlagsSub;
  StreamSubscription<bool>? _privateFlagSub;
  StreamSubscription<Set<String>>? _updatesSub;
  StreamSubscription<List<String>>? _fts5Sub;

  // Internal state (mutable for efficiency, exposed via immutable state)
  bool _isVisible = false;
  Set<String> _lastIds = {};
  Set<String> _selectedEntryTypes = entryTypes.toSet();
  Set<DisplayFilter> _filters = {};
  bool _enableEvents = false;
  bool _enableHabits = false;
  bool _enableDashboards = false;
  String _query = '';
  bool _showPrivateEntries = false;
  Set<String> _selectedCategoryIds = {};
  Set<String> _selectedLabelIds = {};
  Set<String> _selectedPriorities = {};
  Set<String> _fullTextMatches = {};
  TaskSortOption _sortOption = TaskSortOption.byPriority;
  bool _showCreationDate = false;

  @override
  JournalPageState build(bool showTasks) {
    // Initialize services
    _db = getIt<JournalDb>();
    _settingsDb = getIt<SettingsDb>();
    _fts5Db = getIt<Fts5Db>();
    _updateNotifications = getIt<UpdateNotifications>();
    _entitiesCacheService = getIt<EntitiesCacheService>();

    // Initialize category selection for tasks tab
    if (showTasks) {
      final allCategoryIds = _entitiesCacheService.sortedCategories
          .map((e) => e.id)
          .toSet();
      if (allCategoryIds.isEmpty) {
        _selectedCategoryIds = {''};
      }
    }

    // Create pagination controller with custom key logic
    final controller = _createPagingController();

    // CRITICAL: Trigger initial load immediately after controller creation
    // (matches cubit behavior at journal_page_cubit.dart:124-125)
    controller.fetchNextPage();

    // Set up subscriptions
    _setupSubscriptions(showTasks);

    // Load persisted filters
    _loadPersistedFilters(showTasks);
    _loadPersistedEntryTypes();

    // Register hotkeys (desktop only)
    _registerHotkeys();

    // Clean up on dispose
    ref.onDispose(_dispose);

    // IMPORTANT: selectedTaskStatuses uses same default for BOTH tabs
    // (matches cubit behavior at journal_page_cubit.dart:266-270)
    // Tests verify journal tab still has default statuses (persistence_test.dart:262-265)
    return JournalPageState(
      showTasks: showTasks,
      pagingController: controller,
      selectedCategoryIds: _selectedCategoryIds,
      selectedLabelIds: _selectedLabelIds,
      selectedPriorities: _selectedPriorities,
      taskStatuses: const ['OPEN', 'GROOMED', 'IN PROGRESS', 'BLOCKED', 'ON HOLD', 'DONE', 'REJECTED'],
      selectedTaskStatuses: const {'OPEN', 'GROOMED', 'IN PROGRESS'}, // Same default for both tabs
    );
  }

  // ... implement all methods from cubit, preserving exact behavior
  // Including: _createPagingController, _setupSubscriptions, _fetchPage,
  // refreshQuery, visibility handling, filter methods, persistence, etc.
}
```

---

## Implementation Order

1. **Create shared entry_types.dart**
   - Move `entryTypes` constant
   - Update `entry_type_gating.dart` import

2. **Create new state files**
   - `lib/features/journal/state/journal_page_scope.dart`
   - `lib/features/journal/state/journal_page_state.dart`
   - Move enums, state classes, and `TasksFilter` from old location

3. **Create Riverpod controller**
   - `lib/features/journal/state/journal_page_controller.dart`
   - Implement all methods from cubit **exactly**
   - Preserve pagination key logic
   - Preserve update notification throttling and ID comparison
   - Preserve persistence key logic and migration

4. **Run code generation**
   ```bash
   fvm flutter pub run build_runner build --delete-conflicting-outputs
   ```

5. **Update cross-feature dependencies**
   - `CalendarCategoryVisibilityController` import path

6. **Update UI components** (in order of dependency):
   - `infinite_journal_page.dart` - Add ProviderScope with scoped override
   - `journal_sliver_appbar.dart` - Convert to Consumer
   - All filter widgets in `lib/features/tasks/ui/filtering/`
   - All filter widgets in `lib/widgets/search/`
   - AI chat widgets

7. **Update documentation**
   - `lib/features/tasks/README.md`

8. **Migrate tests** to Riverpod patterns
   - Use `ProviderContainer` for unit tests
   - Use `ProviderScope` overrides for widget tests
   - Update `entryTypes` imports

9. **Run analyzer and all tests**
   ```bash
   fvm flutter analyze
   fvm flutter test
   ```

10. **Delete old BLoC files**

11. **Final verification**
    ```bash
    fvm dart fix --apply
    fvm dart format lib/ test/
    ```

---

## Test Strategy

### Unit Tests for JournalPageController

```dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JournalPageController', () {
    late MockJournalDb mockJournalDb;
    late MockSettingsDb mockSettingsDb;
    late MockFts5Db mockFts5Db;
    late MockUpdateNotifications mockUpdateNotifications;
    late MockEntitiesCacheService mockEntitiesCacheService;
    late ProviderContainer container;

    setUp(() {
      // Setup mocks and container with overrides
    });

    tearDown(() async {
      container.dispose();
      await getIt.reset();
    });

    group('initialization', () {
      test('initializes with default state for tasks tab', () {...});
      test('initializes with default state for journal tab', () {...});
      test('loads persisted filters on creation', () {...});
      test('sets up stream subscriptions', () {...});
      test('defaults to unassigned category when no categories exist (tasks)', () {...});
    });

    group('pagination - CRITICAL', () {
      test('creates PagingController with custom getNextPageKey', () {...});
      test('getNextPageKey returns 0 for first page', () {...});
      test('getNextPageKey returns null when no more pages', () {...});
      test('getNextPageKey calculates correct offset', () {...});
      test('fetchPage returns correct entities for offset', () {...});
      test('refreshQuery resets controller and fetches', () {...});
    });

    group('update notifications - CRITICAL', () {
      test('throttles updates at 500ms with trailing', () {...});
      test('only refreshes when visible', () {...});
      test('tasks tab compares IDs before refreshing', () {...});
      test('journal tab checks intersection with affected IDs', () {...});
    });

    group('filter management', () {
      test('toggleSelectedTaskStatus adds/removes status', () {...});
      test('toggleSelectedCategoryIds adds/removes category', () {...});
      test('toggleSelectedLabelId adds/removes label', () {...});
      test('toggleSelectedPriority adds/removes priority', () {...});
      test('toggleSelectedEntryTypes adds/removes entry type', () {...});
      test('setFilters updates display filters', () {...});
      test('setSortOption updates sort order', () {...});
      test('setShowCreationDate toggles date display', () {...});
    });

    group('feature flags', () {
      test('filters entry types based on enabled flags', () {...});
      test('preserves partial selection when flags change', () {...});
      test('selects all when had all previously selected', () {...});
    });

    group('persistence - CRITICAL', () {
      test('uses TASKS_CATEGORY_FILTERS key for tasks tab', () {...});
      test('uses JOURNAL_CATEGORY_FILTERS key for journal tab', () {...});
      test('falls back to legacy TASK_FILTERS key', () {...});
      test('persists task statuses only for tasks tab', () {...});
      test('persists priorities only for tasks tab', () {...});
      test('persists sortOption only for tasks tab', () {...});
      test('persists SELECTED_ENTRY_TYPES separately', () {...});
      test('handles invalid JSON gracefully', () {...});
    });

    group('cleanup', () {
      test('cancels all subscriptions on dispose', () {...});
      test('disposes PagingController', () {...});
    });
  });
}
```

### Test Coverage Targets

| Requirement | Target |
|-------------|--------|
| Minimum coverage | **85%** |
| Goal coverage | **90%** |
| Existing test count | ~100 tests |
| Expected final count | 100+ tests |

---

## Migration Complexity Assessment

| Aspect | Complexity | Notes |
|--------|------------|-------|
| Cubit Logic | **HIGH** | Multiple streams, pagination, filters, feature flags |
| UI Dependencies | **HIGH** | 13+ widgets use BlocBuilder directly |
| Cross-Feature Impact | **MEDIUM** | CalendarCategoryVisibilityController imports TasksFilter |
| Service Impact | **LOW** | Uses existing services (JournalDb, SettingsDb, Fts5Db) |
| Test Effort | **HIGH** | ~100 existing tests to migrate |
| Platform Concerns | **MEDIUM** | Desktop hotkey registration |

**Overall: HIGH COMPLEXITY** - The most complex migration in the BLoC-to-Riverpod initiative.

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Breaking pagination | Port `getNextPageKey` logic exactly; add dedicated pagination tests |
| Breaking update refresh | Port throttling and ID comparison exactly; add timing tests |
| Breaking filters | Preserve all persistence keys and migration logic |
| Import cycle with entryTypes | Move to shared constants file first |
| Widget scoping confusion | Use ProviderScope with scoped provider pattern |
| Calendar feature breakage | Update import early; run calendar tests |
| Missing test coverage | Compare test counts before/after; ensure 85%+ coverage |

---

## CHANGELOG Entry (Draft)

```markdown
## [0.9.7XX] - YYYY-MM-DD
### Changed
- Migrated journal page state management from Bloc to Riverpod
  - Replaced `JournalPageCubit` with `JournalPageController` notifier
  - Moved `entryTypes` to shared constants file
  - Updated 13+ filter widgets to use Riverpod patterns
  - Updated CalendarCategoryVisibilityController import path
  - Consistent with codebase-wide Riverpod adoption
```

---

## Approval Checklist

- [ ] entryTypes relocation strategy approved
- [ ] Provider scoping strategy (ProviderScope override) approved
- [ ] keepAlive: true decision approved
- [ ] Complete file inventory reviewed
- [ ] Pagination/update notification preservation understood
- [ ] Persistence key handling understood
- [ ] Cross-feature (calendar) impact addressed
- [ ] Test strategy approved (85% minimum, 90% goal)
- [ ] Ready to proceed with implementation
