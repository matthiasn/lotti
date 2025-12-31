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
import 'package:lotti/services/dev_logger.dart';
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
  static const pageSize = 50;

  // Services (via GetIt)
  late final JournalDb _db;
  late final SettingsDb _settingsDb;
  late final Fts5Db _fts5Db;
  late final UpdateNotifications _updateNotifications;
  late final EntitiesCacheService _entitiesCacheService;

  // Stream subscriptions
  StreamSubscription<Set<String>>? _configFlagsSub;
  StreamSubscription<bool>? _privateFlagSub;
  StreamSubscription<Set<String>>? _updatesSub;

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
  late bool _showTasks;
  Set<String> _selectedCategoryIds = {};
  Set<String> _selectedLabelIds = {};
  Set<String> _selectedPriorities = {};
  Set<String> _fullTextMatches = {};
  TaskSortOption _sortOption = TaskSortOption.byPriority;
  bool _showCreationDate = false;
  bool _showDueDate = true;
  // Same default for both tabs (matches cubit behavior at journal_page_cubit.dart:266-270)
  Set<String> _selectedTaskStatuses = {
    'OPEN',
    'GROOMED',
    'IN PROGRESS',
  };

  @override
  JournalPageState build(bool showTasks) {
    _showTasks = showTasks;

    // Initialize services
    _db = getIt<JournalDb>();
    _settingsDb = getIt<SettingsDb>();
    _fts5Db = getIt<Fts5Db>();
    _updateNotifications = getIt<UpdateNotifications>();
    _entitiesCacheService = getIt<EntitiesCacheService>();

    // Initialize category selection for tasks tab
    if (showTasks) {
      final allCategoryIds =
          _entitiesCacheService.sortedCategories.map((e) => e.id).toSet();

      // If no categories exist, default to showing unassigned tasks
      if (allCategoryIds.isEmpty) {
        _selectedCategoryIds = {''};
      }
    }

    // Create pagination controller with custom key logic
    // CRITICAL: Trigger initial load immediately after controller creation
    // (matches cubit behavior at journal_page_cubit.dart:124-125)
    final controller = _createPagingController()..fetchNextPage();

    // Set up subscriptions
    _setupSubscriptions(showTasks);

    // Load persisted filters
    _loadPersistedFilters();
    _loadPersistedEntryTypes();

    // Register hotkeys (desktop only)
    _registerHotkeys();

    // Clean up on dispose
    ref.onDispose(_dispose);

    return JournalPageState(
      showTasks: showTasks,
      pagingController: controller,
      selectedEntryTypes: _selectedEntryTypes.toList(),
      selectedCategoryIds: _selectedCategoryIds,
      selectedLabelIds: _selectedLabelIds,
      selectedPriorities: _selectedPriorities,
      taskStatuses: const [
        'OPEN',
        'GROOMED',
        'IN PROGRESS',
        'BLOCKED',
        'ON HOLD',
        'DONE',
        'REJECTED',
      ],
      // Same default for both tabs (tests verify journal tab has default statuses)
      selectedTaskStatuses: _selectedTaskStatuses,
      sortOption: _sortOption,
      showCreationDate: _showCreationDate,
      showDueDate: _showDueDate,
    );
  }

  PagingController<int, JournalEntity> _createPagingController() {
    return PagingController<int, JournalEntity>(
      getNextPageKey: (PagingState<int, JournalEntity> pagingState) {
        final currentKeys = pagingState.keys;
        if (currentKeys == null || currentKeys.isEmpty) {
          return 0; // First page key (offset)
        }
        if (!pagingState.hasNextPage) {
          return null; // No next page if controller says so
        }
        final currentPages = pagingState.pages;
        // If last page had fewer items than pageSize, it's the last page
        if (currentPages != null &&
            currentPages.isNotEmpty &&
            currentPages.last.length < pageSize) {
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
  }

  void _setupSubscriptions(bool showTasks) {
    // Watch private flag
    _privateFlagSub = _db.watchConfigFlag('private').listen((showPrivate) {
      _showPrivateEntries = showPrivate;
      _emitState();
    });

    // Listen to active feature flags and update local cache
    _configFlagsSub = _db.watchActiveConfigFlagNames().listen((configFlags) {
      // Compute previously allowed types before updating flags
      final oldAllowed = computeAllowedEntryTypes(
        events: _enableEvents,
        habits: _enableHabits,
        dashboards: _enableDashboards,
      ).toSet();

      // Update flags
      _enableEvents = configFlags.contains(enableEventsFlag);
      _enableHabits = configFlags.contains(enableHabitsPageFlag);
      _enableDashboards = configFlags.contains(enableDashboardsPageFlag);

      // Compute newly allowed types based on updated flags
      final newAllowed = computeAllowedEntryTypes(
        events: _enableEvents,
        habits: _enableHabits,
        dashboards: _enableDashboards,
      ).toSet();

      // Determine if user had ALL previously-allowed types selected
      final hadAllPreviouslySelected =
          oldAllowed.isNotEmpty && setEquals(_selectedEntryTypes, oldAllowed);

      // Store previous selection for comparison
      final prevSelection = _selectedEntryTypes;

      // Update selection based on user intent:
      // - If empty or had all previously: adopt newAllowed (maintain "select all" behavior)
      // - Otherwise: preserve user's partial selection by intersecting with newAllowed
      if (_selectedEntryTypes.isEmpty || hadAllPreviouslySelected) {
        _selectedEntryTypes = newAllowed;
      } else {
        _selectedEntryTypes = _selectedEntryTypes.intersection(newAllowed);
      }

      // Always emit state to update UI
      _emitState();

      // Only persist if selection actually changed
      if (!setEquals(prevSelection, _selectedEntryTypes)) {
        persistEntryTypes();
      }
    });

    // Setup update notifications with throttling
    String idMapper(JournalEntity entity) => entity.meta.id;

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
          final newIds = (await _runQuery(0)).map(idMapper).toSet();
          if (!setEquals(_lastIds, newIds)) {
            _lastIds = newIds;
            await refreshQuery();
          } else if (displayedIds.intersection(affectedIds).isNotEmpty) {
            await refreshQuery();
          }
        } else {
          if (displayedIds.intersection(affectedIds).isNotEmpty) {
            await refreshQuery();
          }
        }
      }
    });
  }

  void _registerHotkeys() {
    if (isDesktop) {
      hotKeyManager.register(
        HotKey(
          key: LogicalKeyboardKey.keyR,
          modifiers: [HotKeyModifier.meta],
          scope: HotKeyScope.inapp,
        ),
        keyDownHandler: (hotKey) => refreshQuery(),
      );
    }
  }

  void _dispose() {
    _configFlagsSub?.cancel();
    _privateFlagSub?.cancel();
    _updatesSub?.cancel();
    state.pagingController?.dispose();
  }

  void _emitState() {
    state = JournalPageState(
      match: _query,
      tagIds: <String>{},
      filters: _filters,
      showPrivateEntries: _showPrivateEntries,
      showTasks: _showTasks,
      selectedEntryTypes: _selectedEntryTypes.toList(),
      fullTextMatches: _fullTextMatches,
      pagingController: state.pagingController,
      taskStatuses: state.taskStatuses,
      selectedTaskStatuses: _selectedTaskStatuses,
      selectedCategoryIds: _selectedCategoryIds,
      selectedLabelIds: _selectedLabelIds,
      selectedPriorities: _selectedPriorities,
      sortOption: _sortOption,
      showCreationDate: _showCreationDate,
      showDueDate: _showDueDate,
    );
  }

  /// Returns the appropriate storage key for category filters based on current tab
  String _getCategoryFiltersKey() {
    return _showTasks ? tasksCategoryFiltersKey : journalCategoryFiltersKey;
  }

  // Public API methods

  void setFilters(Set<DisplayFilter> filters) {
    _filters = filters;
    refreshQuery();
  }

  Future<void> toggleSelectedTaskStatus(String status) async {
    if (_selectedTaskStatuses.contains(status)) {
      _selectedTaskStatuses =
          _selectedTaskStatuses.difference(<String>{status});
    } else {
      _selectedTaskStatuses = _selectedTaskStatuses.union({status});
    }

    await persistTasksFilter();
  }

  Future<void> toggleSelectedCategoryIds(String categoryId) async {
    if (_selectedCategoryIds.contains(categoryId)) {
      _selectedCategoryIds = _selectedCategoryIds.difference({categoryId});
    } else {
      _selectedCategoryIds = _selectedCategoryIds.union({categoryId});
    }
    _emitState();
    await persistTasksFilter();
  }

  Future<void> selectedAllCategories() async {
    _selectedCategoryIds = {};
    _emitState();
    await persistTasksFilter();
  }

  Future<void> toggleSelectedLabelId(String labelId) async {
    if (_selectedLabelIds.contains(labelId)) {
      _selectedLabelIds = _selectedLabelIds.difference({labelId});
    } else {
      _selectedLabelIds = _selectedLabelIds.union({labelId});
    }
    _emitState();
    await persistTasksFilter();
  }

  Future<void> clearSelectedLabelIds() async {
    _selectedLabelIds = {};
    _emitState();
    await persistTasksFilter();
  }

  void toggleSelectedEntryTypes(String entryType) {
    if (_selectedEntryTypes.contains(entryType)) {
      _selectedEntryTypes = _selectedEntryTypes.difference(<String>{entryType});
    } else {
      _selectedEntryTypes = _selectedEntryTypes.union({entryType});
    }

    persistEntryTypes();
  }

  void selectSingleEntryType(String entryType) {
    _selectedEntryTypes = {entryType};
    persistEntryTypes();
  }

  void selectAllEntryTypes([List<String>? types]) {
    _selectedEntryTypes = (types ?? entryTypes).toSet();
    persistEntryTypes();
  }

  void clearSelectedEntryTypes() {
    _selectedEntryTypes = {};
    persistEntryTypes();
  }

  Future<void> selectSingleTaskStatus(String taskStatus) async {
    _selectedTaskStatuses = {taskStatus};
    await persistTasksFilter();
  }

  Future<void> selectAllTaskStatuses() async {
    _selectedTaskStatuses = state.taskStatuses.toSet();
    await persistTasksFilter();
  }

  Future<void> clearSelectedTaskStatuses() async {
    _selectedTaskStatuses = {};
    await persistTasksFilter();
  }

  // Priority selection handlers
  Future<void> toggleSelectedPriority(String priority) async {
    if (_selectedPriorities.contains(priority)) {
      _selectedPriorities = _selectedPriorities.difference({priority});
    } else {
      _selectedPriorities = _selectedPriorities.union({priority});
    }
    await persistTasksFilter();
  }

  Future<void> clearSelectedPriorities() async {
    _selectedPriorities = {};
    await persistTasksFilter();
  }

  // Sort option handlers
  Future<void> setSortOption(TaskSortOption option) async {
    _sortOption = option;
    await persistTasksFilter();
  }

  // Creation date display toggle (visual only, no query refresh needed)
  Future<void> setShowCreationDate({required bool show}) async {
    _showCreationDate = show;
    _emitState();
    await _persistTasksFilterWithoutRefresh();
  }

  // Due date display toggle (visual only, no query refresh needed)
  Future<void> setShowDueDate({required bool show}) async {
    _showDueDate = show;
    _emitState();
    await _persistTasksFilterWithoutRefresh();
  }

  // Persistence methods

  /// Loads persisted filters with migration from legacy key
  Future<void> _loadPersistedFilters() async {
    // Try to read from the per-tab key first
    final perTabKey = _getCategoryFiltersKey();
    var value = await _settingsDb.itemByKey(perTabKey);

    // If the new key doesn't exist, fall back to legacy key for migration
    value ??= await _settingsDb.itemByKey(taskFiltersKey);

    if (value == null) {
      return;
    }

    try {
      final json = jsonDecode(value) as Map<String, dynamic>;
      final tasksFilter = TasksFilter.fromJson(json);

      // Only load task-related filters if we're in the tasks tab
      if (_showTasks) {
        _selectedTaskStatuses = tasksFilter.selectedTaskStatuses;
        _selectedLabelIds = tasksFilter.selectedLabelIds;
        _selectedPriorities = tasksFilter.selectedPriorities;
        _sortOption = tasksFilter.sortOption;
        _showCreationDate = tasksFilter.showCreationDate;
        _showDueDate = tasksFilter.showDueDate;
      } else {
        _selectedLabelIds = {};
        _selectedPriorities = {};
      }

      // Load category filters for both tabs
      _selectedCategoryIds = tasksFilter.selectedCategoryIds;

      _emitState();
      await refreshQuery();
    } catch (e) {
      DevLogger.warning(
        name: 'JournalPageController',
        message: 'Error loading persisted filters: $e',
      );
    }
  }

  Future<void> _loadPersistedEntryTypes() async {
    final value = await _settingsDb.itemByKey(selectedEntryTypesKey);
    if (value == null) {
      return;
    }
    final json = jsonDecode(value) as List<dynamic>;
    _selectedEntryTypes = List<String>.from(json).toSet();
    _emitState();
    await refreshQuery();
  }

  Future<void> persistTasksFilter() async {
    await refreshQuery();
    await _persistTasksFilterWithoutRefresh();
  }

  /// Persists filter state without triggering a query refresh.
  /// Use for visual-only settings like showCreationDate.
  Future<void> _persistTasksFilterWithoutRefresh() async {
    final filter = TasksFilter(
      selectedCategoryIds: _selectedCategoryIds,
      selectedTaskStatuses: _showTasks ? _selectedTaskStatuses : {},
      selectedLabelIds: _showTasks ? _selectedLabelIds : {},
      selectedPriorities: _showTasks ? _selectedPriorities : {},
      sortOption: _showTasks ? _sortOption : TaskSortOption.byPriority,
      showCreationDate: _showTasks && _showCreationDate,
      showDueDate: _showTasks && _showDueDate,
    );
    final encodedFilter = jsonEncode(filter);

    // Write to the new per-tab key
    await _settingsDb.saveSettingsItem(
      _getCategoryFiltersKey(),
      encodedFilter,
    );

    // Mirror writes to the legacy key while the migration is in place.
    // Only do this on the tasks tab so journal actions never clobber task filters.
    if (_showTasks) {
      await _settingsDb.saveSettingsItem(
        taskFiltersKey,
        encodedFilter,
      );
    }
  }

  Future<void> persistEntryTypes() async {
    await refreshQuery();

    await _settingsDb.saveSettingsItem(
      selectedEntryTypesKey,
      jsonEncode(_selectedEntryTypes.toList()),
    );
  }

  // Search and query methods

  Future<void> _fts5Search() async {
    if (_query.isEmpty) {
      _fullTextMatches = {};
    } else {
      final res = await _fts5Db.watchFullTextMatches(_query).first;
      _fullTextMatches = res.toSet();
    }
  }

  Future<void> setSearchString(String query) async {
    _query = query;
    await refreshQuery();
  }

  Future<void> refreshQuery() async {
    _emitState();

    if (state.pagingController == null) {
      DevLogger.warning(
        name: 'JournalPageController',
        message: 'refreshQuery called but pagingController is null',
      );
      return;
    }

    state.pagingController!.refresh();
    state.pagingController!.fetchNextPage();
  }

  void updateVisibility(VisibilityInfo visibilityInfo) {
    final isVisible = visibilityInfo.visibleBounds.size.width > 0;
    if (!_isVisible && isVisible) {
      refreshQuery();
    }
    _isVisible = isVisible;
  }

  Future<List<JournalEntity>> _fetchPage(int pageKey) async {
    try {
      return _runQuery(pageKey);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        print('Error in _fetchPage: $error\n$stackTrace');
      }
      rethrow;
    }
  }

  Future<List<JournalEntity>> _runQuery(int pageKey) async {
    // Intersect selected types with allowed based on feature flags
    final allowed = computeAllowedEntryTypes(
      events: _enableEvents,
      habits: _enableHabits,
      dashboards: _enableDashboards,
    );
    // Use internal field instead of state to avoid accessing state during build
    final types = _selectedEntryTypes.where(allowed.contains).toList();
    await _fts5Search();
    final fullTextMatches = _fullTextMatches.toList();
    final ids = _query.isNotEmpty ? fullTextMatches : null;

    final starredEntriesOnly =
        _filters.contains(DisplayFilter.starredEntriesOnly);
    final privateEntriesOnly =
        _filters.contains(DisplayFilter.privateEntriesOnly);
    final flaggedEntriesOnly =
        _filters.contains(DisplayFilter.flaggedEntriesOnly);

    if (_showTasks) {
      final allCategoryIds =
          _entitiesCacheService.sortedCategories.map((e) => e.id).toSet();

      Set<String> categoryIds;
      if (_selectedCategoryIds.isEmpty) {
        // If no categories are selected and no categories exist,
        // default to showing unassigned tasks for better onboarding
        categoryIds = allCategoryIds.isEmpty ? {''} : allCategoryIds;
      } else {
        categoryIds = _selectedCategoryIds;
      }

      final labelIds = _selectedLabelIds;
      final priorities = _selectedPriorities;

      // For due date sorting, we need to fetch and sort in memory since
      // due dates are stored in serialized JSON, not a database column.
      // Use date ordering as a fallback base query.
      final sortByDateInDb = _sortOption == TaskSortOption.byDate ||
          _sortOption == TaskSortOption.byDueDate;

      final res = await _db.getTasks(
        ids: ids,
        starredStatuses: starredEntriesOnly ? [true] : [true, false],
        taskStatuses: _selectedTaskStatuses.toList(),
        categoryIds: categoryIds.toList(),
        labelIds: labelIds.toList(),
        priorities: priorities.toList(),
        sortByDate: sortByDateInDb,
        limit: pageSize,
        offset: pageKey,
      );

      // Apply in-memory due date sorting if needed
      if (_sortOption == TaskSortOption.byDueDate) {
        return _sortByDueDate(res);
      }

      return res;
    } else {
      return _db.getJournalEntities(
        types: types,
        ids: ids,
        starredStatuses: starredEntriesOnly ? [true] : [true, false],
        privateStatuses: privateEntriesOnly ? [true] : [true, false],
        flaggedStatuses: flaggedEntriesOnly ? [1] : [1, 0],
        categoryIds:
            _selectedCategoryIds.isNotEmpty ? _selectedCategoryIds : null,
        limit: pageSize,
        offset: pageKey,
      );
    }
  }

  /// Sorts tasks by due date (soonest first, tasks without due dates at end).
  /// Preserves creation date order for tasks with the same due date or no due date.
  List<JournalEntity> _sortByDueDate(List<JournalEntity> entities) {
    return List<JournalEntity>.from(entities)
      ..sort((a, b) {
        // Extract due dates from Task entities
        DateTime? dueA;
        DateTime? dueB;

        if (a case Task(data: final dataA)) {
          dueA = dataA.due;
        }
        if (b case Task(data: final dataB)) {
          dueB = dataB.due;
        }

        // Tasks with due dates come before tasks without
        if (dueA != null && dueB == null) return -1;
        if (dueA == null && dueB != null) return 1;

        // Both have due dates: sort by due date ascending (soonest first)
        if (dueA != null && dueB != null) {
          final comparison = dueA.compareTo(dueB);
          if (comparison != 0) return comparison;
        }

        // Same due date or both null: preserve creation date order (newest first)
        return b.meta.dateFrom.compareTo(a.meta.dateFrom);
      });
  }

  // Getters for testing
  bool get isVisible => _isVisible;
  Set<String> get selectedEntryTypesInternal => _selectedEntryTypes;
  Set<DisplayFilter> get filtersInternal => _filters;
  bool get enableEvents => _enableEvents;
  bool get enableHabits => _enableHabits;
  bool get enableDashboards => _enableDashboards;
}
