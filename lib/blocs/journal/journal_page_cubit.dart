import 'dart:async';
import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/journal/utils/entry_type_gating.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/platform.dart';
import 'package:rxdart/rxdart.dart';
import 'package:visibility_detector/visibility_detector.dart';

class JournalPageCubit extends Cubit<JournalPageState> {
  JournalPageCubit({required this.showTasks})
      : _db = getIt<JournalDb>(),
        _updateNotifications = getIt<UpdateNotifications>(),
        super(
          JournalPageState(
            match: '',
            tagIds: <String>{},
            filters: {},
            showPrivateEntries: false,
            selectedEntryTypes: entryTypes,
            fullTextMatches: {},
            showTasks: showTasks,
            pagingController: null,
            taskStatuses: [
              'OPEN',
              'GROOMED',
              'IN PROGRESS',
              'BLOCKED',
              'ON HOLD',
              'DONE',
              'REJECTED',
            ],
            selectedTaskStatuses: {
              'OPEN',
              'GROOMED',
              'IN PROGRESS',
            },
            selectedCategoryIds: {},
            selectedLabelIds: {},
            selectedPriorities: {},
          ),
        ) {
    // Check if we need to set default category selection for tasks
    if (showTasks) {
      final allCategoryIds = getIt<EntitiesCacheService>()
          .sortedCategories
          .map((e) => e.id)
          .toSet();

      // If no categories exist, default to showing unassigned tasks
      if (allCategoryIds.isEmpty) {
        _selectedCategoryIds = {''};
      }
    }

    // Create the controller right after initialization
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
        // Controller handles hasNextPage based on fetchPage results.
        return currentKeys.last +
            ((currentPages != null &&
                    currentPages.isNotEmpty &&
                    currentKeys.length == currentPages.length)
                ? currentPages.last.length
                : 0);
      },
      fetchPage: _fetchPage, // Now we can directly use the method reference
    );

    // Set the controller and trigger initial load
    emit(
      JournalPageState(
        match: state.match,
        tagIds: state.tagIds,
        filters: state.filters,
        showPrivateEntries: state.showPrivateEntries,
        selectedEntryTypes: state.selectedEntryTypes,
        fullTextMatches: state.fullTextMatches,
        showTasks: state.showTasks,
        pagingController: controller,
        taskStatuses: state.taskStatuses,
        selectedTaskStatuses: state.selectedTaskStatuses,
        selectedCategoryIds: _selectedCategoryIds,
        selectedLabelIds: _selectedLabelIds,
        selectedPriorities: _selectedPriorities,
      ),
    );

    // Call fetchNextPage to trigger the initial load
    controller.fetchNextPage();

    _privateFlagSub =
        getIt<JournalDb>().watchConfigFlag('private').listen((showPrivate) {
      _showPrivateEntries = showPrivate;
      emitState();
    });

    // Load persisted filters with migration from legacy key
    _loadPersistedFilters();

    getIt<SettingsDb>().itemByKey(selectedEntryTypesKey).then((value) {
      if (value == null) {
        return;
      }
      final json = jsonDecode(value) as List<dynamic>;
      _selectedEntryTypes = List<String>.from(json).toSet();
      emitState();
      refreshQuery();
    });

    // Listen to active feature flags and update local cache
    _configFlagsSub =
        getIt<JournalDb>().watchActiveConfigFlagNames().listen((configFlags) {
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
      emitState();

      // Only persist if selection actually changed
      if (!setEquals(prevSelection, _selectedEntryTypes)) {
        persistEntryTypes();
      }
    });

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

  static const taskFiltersKey = 'TASK_FILTERS'; // Legacy key for migration
  static const tasksCategoryFiltersKey = 'TASKS_CATEGORY_FILTERS';
  static const journalCategoryFiltersKey = 'JOURNAL_CATEGORY_FILTERS';
  static const selectedEntryTypesKey = 'SELECTED_ENTRY_TYPES';

  final JournalDb _db;
  final UpdateNotifications _updateNotifications;
  StreamSubscription<Set<String>>? _configFlagsSub;
  StreamSubscription<bool>? _privateFlagSub;
  StreamSubscription<Set<String>>? _updatesSub;
  bool _isVisible = false;
  static const _pageSize = 50;
  Set<String> _selectedEntryTypes = entryTypes.toSet();
  Set<DisplayFilter> _filters = {};

  // Feature flags cached in the cubit
  bool _enableEvents = false;
  bool _enableHabits = false;
  bool _enableDashboards = false;

  String _query = '';
  bool _showPrivateEntries = false;
  bool showTasks = false;
  Set<String> _selectedCategoryIds = {};
  Set<String> _selectedLabelIds = {};
  Set<String> _selectedPriorities = {};
  TaskSortOption _sortOption = TaskSortOption.byPriority;
  bool _showCreationDate = false;

  Set<String> _fullTextMatches = {};
  Set<String> _lastIds = {};
  Set<String> _selectedTaskStatuses = {
    'OPEN',
    'GROOMED',
    'IN PROGRESS',
  };

  /// Returns the appropriate storage key for category filters based on current tab
  String _getCategoryFiltersKey() {
    return showTasks ? tasksCategoryFiltersKey : journalCategoryFiltersKey;
  }

  void emitState() {
    emit(
      JournalPageState(
        match: _query,
        tagIds: <String>{},
        filters: _filters,
        showPrivateEntries: _showPrivateEntries,
        showTasks: showTasks,
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
      ),
    );
  }

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
    emitState();
    await persistTasksFilter();
  }

  Future<void> selectedAllCategories() async {
    _selectedCategoryIds = {};
    emitState();
    await persistTasksFilter();
  }

  Future<void> toggleSelectedLabelId(String labelId) async {
    if (_selectedLabelIds.contains(labelId)) {
      _selectedLabelIds = _selectedLabelIds.difference({labelId});
    } else {
      _selectedLabelIds = _selectedLabelIds.union({labelId});
    }
    emitState();
    await persistTasksFilter();
  }

  Future<void> clearSelectedLabelIds() async {
    _selectedLabelIds = {};
    emitState();
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
    emitState();
    await _persistTasksFilterWithoutRefresh();
  }

  /// Loads persisted filters with migration from legacy key
  Future<void> _loadPersistedFilters() async {
    final settingsDb = getIt<SettingsDb>();

    // Try to read from the per-tab key first
    final perTabKey = _getCategoryFiltersKey();
    var value = await settingsDb.itemByKey(perTabKey);

    // If the new key doesn't exist, fall back to legacy key for migration
    value ??= await settingsDb.itemByKey(taskFiltersKey);

    if (value == null) {
      return;
    }

    try {
      final json = jsonDecode(value) as Map<String, dynamic>;
      final tasksFilter = TasksFilter.fromJson(json);

      // Only load task-related filters if we're in the tasks tab
      if (showTasks) {
        _selectedTaskStatuses = tasksFilter.selectedTaskStatuses;
        _selectedLabelIds = tasksFilter.selectedLabelIds;
        _selectedPriorities = tasksFilter.selectedPriorities;
        _sortOption = tasksFilter.sortOption;
        _showCreationDate = tasksFilter.showCreationDate;
      } else {
        _selectedLabelIds = {};
        _selectedPriorities = {};
      }

      // Load category filters for both tabs
      _selectedCategoryIds = tasksFilter.selectedCategoryIds;

      emitState();
      await refreshQuery();
    } catch (e) {
      DevLogger.warning(
        name: 'JournalPageCubit',
        message: 'Error loading persisted filters: $e',
      );
    }
  }

  Future<void> persistTasksFilter() async {
    await refreshQuery();
    await _persistTasksFilterWithoutRefresh();
  }

  /// Persists filter state without triggering a query refresh.
  /// Use for visual-only settings like showCreationDate.
  Future<void> _persistTasksFilterWithoutRefresh() async {
    final settingsDb = getIt<SettingsDb>();

    final filter = TasksFilter(
      selectedCategoryIds: _selectedCategoryIds,
      selectedTaskStatuses: showTasks ? _selectedTaskStatuses : {},
      selectedLabelIds: showTasks ? _selectedLabelIds : {},
      selectedPriorities: showTasks ? _selectedPriorities : {},
      sortOption: showTasks ? _sortOption : TaskSortOption.byPriority,
      showCreationDate: showTasks && _showCreationDate,
    );
    final encodedFilter = jsonEncode(filter);

    // Write to the new per-tab key
    await settingsDb.saveSettingsItem(
      _getCategoryFiltersKey(),
      encodedFilter,
    );

    // Mirror writes to the legacy key while the migration is in place.
    // Only do this on the tasks tab so journal actions never clobber task filters.
    if (showTasks) {
      await settingsDb.saveSettingsItem(
        taskFiltersKey,
        encodedFilter,
      );
    }
  }

  Future<void> persistEntryTypes() async {
    await refreshQuery();

    await getIt<SettingsDb>().saveSettingsItem(
      selectedEntryTypesKey,
      jsonEncode(_selectedEntryTypes.toList()),
    );
  }

  Future<void> _fts5Search() async {
    if (_query.isEmpty) {
      _fullTextMatches = {};
    } else {
      final res = await getIt<Fts5Db>().watchFullTextMatches(_query).first;
      _fullTextMatches = res.toSet();
    }
  }

  Future<void> setSearchString(String query) async {
    _query = query;
    await refreshQuery();
  }

  Future<void> refreshQuery() async {
    emitState();

    if (state.pagingController == null) {
      DevLogger.warning(
        name: 'JournalPageCubit',
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
      // Rethrow the error. The PagingController will catch it
      // and update its state.error field.
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
    final types = state.selectedEntryTypes.where(allowed.contains).toList();
    await _fts5Search();
    final fullTextMatches = _fullTextMatches.toList();
    final ids = _query.isNotEmpty ? fullTextMatches : null;

    final starredEntriesOnly =
        _filters.contains(DisplayFilter.starredEntriesOnly);
    final privateEntriesOnly =
        _filters.contains(DisplayFilter.privateEntriesOnly);
    final flaggedEntriesOnly =
        _filters.contains(DisplayFilter.flaggedEntriesOnly);

    if (showTasks) {
      final allCategoryIds = getIt<EntitiesCacheService>()
          .sortedCategories
          .map((e) => e.id)
          .toSet();

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

      final res = await _db.getTasks(
        ids: ids,
        starredStatuses: starredEntriesOnly ? [true] : [true, false],
        taskStatuses: _selectedTaskStatuses.toList(),
        categoryIds: categoryIds.toList(),
        labelIds: labelIds.toList(),
        priorities: priorities.toList(),
        sortByDate: _sortOption == TaskSortOption.byDate,
        limit: _pageSize,
        offset: pageKey,
      );

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
        limit: _pageSize,
        offset: pageKey,
      );
    }
  }

  @override
  Future<void> close() async {
    try {
      await _configFlagsSub?.cancel();
      await _privateFlagSub?.cancel();
      await _updatesSub?.cancel();
    } catch (_) {
      // ignore cancellation errors
    }
    state.pagingController?.dispose();
    return super.close();
  }
}

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
