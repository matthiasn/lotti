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
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/ai/repository/vector_search_repository.dart';
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
  StreamSubscription<
    ({
      bool events,
      bool habits,
      bool dashboards,
      bool vectorSearch,
      bool projects,
    })
  >?
  _configFlagsSub;
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
  bool _enableVectorSearch = false;
  bool _enableProjects = false;
  SearchMode _searchMode = SearchMode.fullText;
  String _query = '';
  bool _showPrivateEntries = false;
  late bool _showTasks;
  Set<String> _selectedCategoryIds = {};
  Set<String> _selectedProjectIds = {};
  Set<String> _selectedLabelIds = {};
  Set<String> _selectedPriorities = {};
  Set<String> _fullTextMatches = {};
  TaskSortOption _sortOption = TaskSortOption.byPriority;
  bool _showCreationDate = false;
  bool _showDueDate = true;
  bool _showCoverArt = true;
  bool _showProjectsHeader = true;
  bool _showDistances = false;
  AgentAssignmentFilter _agentAssignmentFilter = AgentAssignmentFilter.all;
  Set<String>? _cachedAgentLinkedIds;

  /// When post-filters (project/agent) are active, `_runQuery` may consume
  /// more raw DB rows than it returns filtered results. This field tracks
  /// the actual raw offset to resume from on the next page, avoiding
  /// duplicate or missed rows.
  int? _postFilterNextRawOffset;
  String? _persistedPerTabTasksFilterValue;
  String? _persistedLegacyTaskFilterValue;
  String? _persistedEntryTypesValue;
  bool _hasLoadedPerTabTasksFilterValue = false;
  bool _hasLoadedLegacyTaskFilterValue = false;
  bool _hasLoadedEntryTypesValue = false;
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
      final allCategoryIds = _entitiesCacheService.sortedCategories
          .map((e) => e.id)
          .toSet();

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

    // Clean up on dispose - capture controller directly to avoid accessing state
    ref.onDispose(() => _dispose(controller));

    return JournalPageState(
      showTasks: showTasks,
      pagingController: controller,
      selectedEntryTypes: _selectedEntryTypes.toList(),
      selectedCategoryIds: _selectedCategoryIds,
      selectedProjectIds: _selectedProjectIds,
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
      showCoverArt: _showCoverArt,
      showProjectsHeader: _showProjectsHeader,
      showDistances: _showDistances,
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
        // When post-filters consumed more raw rows than returned filtered
        // results, use the tracked raw offset so we don't re-read rows.
        if (_postFilterNextRawOffset != null) {
          final offset = _postFilterNextRawOffset!;
          _postFilterNextRawOffset = null;
          return offset;
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

    // Listen to feature flags needed by this controller without loading the
    // whole config flag table.
    _configFlagsSub =
        Rx.combineLatest5<
              bool,
              bool,
              bool,
              bool,
              bool,
              ({
                bool events,
                bool habits,
                bool dashboards,
                bool vectorSearch,
                bool projects,
              })
            >(
              _db.watchConfigFlag(enableEventsFlag),
              _db.watchConfigFlag(enableHabitsPageFlag),
              _db.watchConfigFlag(enableDashboardsPageFlag),
              _db.watchConfigFlag(enableVectorSearchFlag),
              _db.watchConfigFlag(enableProjectsFlag),
              (events, habits, dashboards, vectorSearch, projects) => (
                events: events,
                habits: habits,
                dashboards: dashboards,
                vectorSearch: vectorSearch,
                projects: projects,
              ),
            )
            .listen((flags) {
              // Compute previously allowed types before updating flags
              final oldAllowed = computeAllowedEntryTypes(
                events: _enableEvents,
                habits: _enableHabits,
                dashboards: _enableDashboards,
              ).toSet();

              // Update flags
              _enableEvents = flags.events;
              _enableHabits = flags.habits;
              _enableDashboards = flags.dashboards;
              _enableVectorSearch = flags.vectorSearch;
              _enableProjects = flags.projects;
              var shouldRefreshAfterModeFallback = false;
              if (!_enableVectorSearch && _searchMode == SearchMode.vector) {
                _searchMode = SearchMode.fullText;
                shouldRefreshAfterModeFallback = true;
              }
              if (!_enableProjects && _selectedProjectIds.isNotEmpty) {
                _selectedProjectIds = {};
                shouldRefreshAfterModeFallback = true;
              }

              // Compute newly allowed types based on updated flags
              final newAllowed = computeAllowedEntryTypes(
                events: _enableEvents,
                habits: _enableHabits,
                dashboards: _enableDashboards,
              ).toSet();

              // Determine if user had ALL previously-allowed types selected
              final hadAllPreviouslySelected =
                  oldAllowed.isNotEmpty &&
                  setEquals(_selectedEntryTypes, oldAllowed);

              // Store previous selection for comparison
              final prevSelection = _selectedEntryTypes;

              // Update selection based on user intent:
              // - If empty or had all previously: adopt newAllowed (maintain "select all" behavior)
              // - Otherwise: preserve user's partial selection by intersecting with newAllowed
              if (_selectedEntryTypes.isEmpty || hadAllPreviouslySelected) {
                _selectedEntryTypes = newAllowed;
              } else {
                _selectedEntryTypes = _selectedEntryTypes.intersection(
                  newAllowed,
                );
              }

              // Always emit state to update UI
              _emitState();

              if (shouldRefreshAfterModeFallback) {
                unawaited(refreshQuery());
              }

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
              // Probe call: save/restore offset so the probe doesn't
              // mutate pagination state consumed by the real fetch.
              final savedOffset = _postFilterNextRawOffset;
              final newIds = (await _runQuery(0)).map(idMapper).toSet();
              _postFilterNextRawOffset = savedOffset;
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

  void _dispose(PagingController<int, JournalEntity> controller) {
    _configFlagsSub?.cancel();
    _privateFlagSub?.cancel();
    _updatesSub?.cancel();
    controller.dispose();
  }

  void _emitState() {
    state = state.copyWith(
      match: _query,
      tagIds: <String>{},
      filters: _filters,
      showPrivateEntries: _showPrivateEntries,
      showTasks: _showTasks,
      selectedEntryTypes: _selectedEntryTypes.toList(),
      fullTextMatches: _fullTextMatches,
      selectedTaskStatuses: _selectedTaskStatuses,
      selectedCategoryIds: _selectedCategoryIds,
      selectedProjectIds: _selectedProjectIds,
      selectedLabelIds: _selectedLabelIds,
      selectedPriorities: _selectedPriorities,
      sortOption: _sortOption,
      showCreationDate: _showCreationDate,
      showDueDate: _showDueDate,
      showCoverArt: _showCoverArt,
      showProjectsHeader: _showProjectsHeader,
      showDistances: _showDistances,
      agentAssignmentFilter: _agentAssignmentFilter,
      searchMode: _searchMode,
      enableVectorSearch: _enableVectorSearch,
      enableProjects: _enableProjects,
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
      _selectedTaskStatuses = _selectedTaskStatuses.difference(<String>{
        status,
      });
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
    // Project filters are category-scoped — clear when categories change
    // to avoid invisible stale filters for a previous category.
    _selectedProjectIds = {};

    _emitState();
    await persistTasksFilter();
  }

  Future<void> selectedAllCategories() async {
    _selectedCategoryIds = {};
    _selectedProjectIds = {};

    _emitState();
    await persistTasksFilter();
  }

  Future<void> toggleProjectFilter(String projectId) async {
    if (_selectedProjectIds.contains(projectId)) {
      _selectedProjectIds = _selectedProjectIds.difference({projectId});
    } else {
      _selectedProjectIds = _selectedProjectIds.union({projectId});
    }
    _emitState();
    await persistTasksFilter();
  }

  Future<void> clearProjectFilter() async {
    _selectedProjectIds = {};

    _emitState();
    await persistTasksFilter();
  }

  /// Removes project IDs that are no longer valid (e.g. removed by sync).
  /// Called by the project filter chip when it detects stale selections.
  Future<void> removeStaleProjectFilters(Set<String> staleIds) async {
    if (staleIds.isEmpty) return;
    _selectedProjectIds = _selectedProjectIds.difference(staleIds);
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

  // Agent assignment filter handler
  Future<void> setAgentAssignmentFilter(AgentAssignmentFilter filter) async {
    _agentAssignmentFilter = filter;
    await persistTasksFilter();
  }

  // Sort option handlers
  Future<void> setSortOption(TaskSortOption option) async {
    _sortOption = option;
    await persistTasksFilter();
  }

  /// Switches between full-text and vector search modes.
  void setSearchMode(SearchMode mode) {
    _searchMode = _enableVectorSearch ? mode : SearchMode.fullText;
    refreshQuery();
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

  // Cover art display toggle (visual only, no query refresh needed)
  Future<void> setShowCoverArt({required bool show}) async {
    _showCoverArt = show;
    _emitState();
    await _persistTasksFilterWithoutRefresh();
  }

  // Projects header visibility toggle (visual only, no query refresh needed)
  Future<void> setShowProjectsHeader({required bool show}) async {
    _showProjectsHeader = show;
    _emitState();
    await _persistTasksFilterWithoutRefresh();
  }

  // Distance display toggle (visual only, no query refresh needed)
  Future<void> setShowDistances({required bool show}) async {
    _showDistances = show;
    _emitState();
    await _persistTasksFilterWithoutRefresh();
  }

  // Persistence methods

  /// Loads persisted filters with migration from legacy key
  Future<void> _loadPersistedFilters() async {
    final perTabKey = _getCategoryFiltersKey();
    final perTabValue = await _settingsDb.itemByKey(perTabKey);
    _persistedPerTabTasksFilterValue = _normalizeTasksFilterValue(perTabValue);
    _hasLoadedPerTabTasksFilterValue = true;

    final legacyValue = _showTasks
        ? await _settingsDb.itemByKey(taskFiltersKey)
        : null;
    if (_showTasks) {
      _persistedLegacyTaskFilterValue = _normalizeTasksFilterValue(legacyValue);
      _hasLoadedLegacyTaskFilterValue = true;
    }

    final value = perTabValue ?? legacyValue;

    if (value == null) {
      return;
    }

    try {
      final json = jsonDecode(value) as Map<String, dynamic>;
      final tasksFilter = TasksFilter.fromJson(json);

      // Only load task-related filters if we're in the tasks tab
      if (_showTasks) {
        _selectedTaskStatuses = tasksFilter.selectedTaskStatuses;
        _selectedProjectIds = tasksFilter.selectedProjectIds;
        _selectedLabelIds = tasksFilter.selectedLabelIds;
        _selectedPriorities = tasksFilter.selectedPriorities;
        _sortOption = tasksFilter.sortOption;
        _showCreationDate = tasksFilter.showCreationDate;
        _showDueDate = tasksFilter.showDueDate;
        _showCoverArt = tasksFilter.showCoverArt;
        _showProjectsHeader = tasksFilter.showProjectsHeader;
        _showDistances = tasksFilter.showDistances;
        _agentAssignmentFilter = tasksFilter.agentAssignmentFilter;
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
    _persistedEntryTypesValue = _normalizeEntryTypesValue(value);
    _hasLoadedEntryTypesValue = true;
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
      selectedProjectIds: _showTasks ? _selectedProjectIds : {},
      selectedTaskStatuses: _showTasks ? _selectedTaskStatuses : {},
      selectedLabelIds: _showTasks ? _selectedLabelIds : {},
      selectedPriorities: _showTasks ? _selectedPriorities : {},
      sortOption: _showTasks ? _sortOption : TaskSortOption.byPriority,
      showCreationDate: _showTasks && _showCreationDate,
      showDueDate: _showTasks && _showDueDate,
      showCoverArt: _showTasks && _showCoverArt,
      showProjectsHeader: _showTasks && _showProjectsHeader,
      showDistances: _showTasks && _showDistances,
      agentAssignmentFilter: _showTasks
          ? _agentAssignmentFilter
          : AgentAssignmentFilter.all,
    );
    final encodedFilter = _encodeTasksFilter(filter);
    final perTabKey = _getCategoryFiltersKey();

    if (!_hasLoadedPerTabTasksFilterValue) {
      _persistedPerTabTasksFilterValue = _normalizeTasksFilterValue(
        await _settingsDb.itemByKey(perTabKey),
      );
      _hasLoadedPerTabTasksFilterValue = true;
    }

    if (_persistedPerTabTasksFilterValue != encodedFilter) {
      await _settingsDb.saveSettingsItem(
        perTabKey,
        encodedFilter,
      );
      _persistedPerTabTasksFilterValue = encodedFilter;
    }

    // Mirror writes to the legacy key while the migration is in place.
    // Only do this on the tasks tab so journal actions never clobber task filters.
    if (_showTasks) {
      if (!_hasLoadedLegacyTaskFilterValue) {
        _persistedLegacyTaskFilterValue = _normalizeTasksFilterValue(
          await _settingsDb.itemByKey(taskFiltersKey),
        );
        _hasLoadedLegacyTaskFilterValue = true;
      }

      if (_persistedLegacyTaskFilterValue != encodedFilter) {
        await _settingsDb.saveSettingsItem(
          taskFiltersKey,
          encodedFilter,
        );
        _persistedLegacyTaskFilterValue = encodedFilter;
      }
    }
  }

  Future<void> persistEntryTypes() async {
    await refreshQuery();

    if (!_hasLoadedEntryTypesValue) {
      _persistedEntryTypesValue = _normalizeEntryTypesValue(
        await _settingsDb.itemByKey(selectedEntryTypesKey),
      );
      _hasLoadedEntryTypesValue = true;
    }

    final encodedEntryTypes = _encodeEntryTypes(_selectedEntryTypes);
    if (_persistedEntryTypesValue == encodedEntryTypes) {
      return;
    }

    await _settingsDb.saveSettingsItem(
      selectedEntryTypesKey,
      encodedEntryTypes,
    );
    _persistedEntryTypesValue = encodedEntryTypes;
  }

  String _encodeTasksFilter(TasksFilter filter) {
    return jsonEncode(<String, dynamic>{
      'selectedCategoryIds': _sortedStrings(filter.selectedCategoryIds),
      'selectedProjectIds': _sortedStrings(filter.selectedProjectIds),
      'selectedTaskStatuses': _sortedStrings(filter.selectedTaskStatuses),
      'selectedLabelIds': _sortedStrings(filter.selectedLabelIds),
      'selectedPriorities': _sortedStrings(filter.selectedPriorities),
      'sortOption': filter.sortOption.name,
      'showCreationDate': filter.showCreationDate,
      'showDueDate': filter.showDueDate,
      'showCoverArt': filter.showCoverArt,
      'showDistances': filter.showDistances,
      'agentAssignmentFilter': filter.agentAssignmentFilter.name,
    });
  }

  String _encodeEntryTypes(Set<String> entryTypes) {
    return jsonEncode(_sortedStrings(entryTypes));
  }

  String? _normalizeTasksFilterValue(String? value) {
    if (value == null) {
      return null;
    }

    try {
      final json = jsonDecode(value) as Map<String, dynamic>;
      return _encodeTasksFilter(TasksFilter.fromJson(json));
    } catch (_) {
      return value;
    }
  }

  String? _normalizeEntryTypesValue(String? value) {
    if (value == null) {
      return null;
    }

    try {
      final json = jsonDecode(value) as List<dynamic>;
      return _encodeEntryTypes(List<String>.from(json).toSet());
    } catch (_) {
      return value;
    }
  }

  List<String> _sortedStrings(Iterable<String> values) {
    final sorted = values.toList()..sort();
    return sorted;
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
    _cachedAgentLinkedIds = null;

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
    // Vector search: bypass FTS5 and DB pagination entirely.
    if (_enableVectorSearch &&
        _searchMode == SearchMode.vector &&
        _query.isNotEmpty &&
        pageKey == 0) {
      return _runVectorSearch();
    }

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

    final starredEntriesOnly = _filters.contains(
      DisplayFilter.starredEntriesOnly,
    );
    final privateEntriesOnly = _filters.contains(
      DisplayFilter.privateEntriesOnly,
    );
    final flaggedEntriesOnly = _filters.contains(
      DisplayFilter.flaggedEntriesOnly,
    );

    if (_showTasks) {
      final allCategoryIds = _entitiesCacheService.sortedCategories
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

      // For due date sorting, we need to fetch and sort in memory since
      // due dates are stored in serialized JSON, not a database column.
      // Use date ordering as a fallback base query.
      final sortByDateInDb =
          _sortOption == TaskSortOption.byDate ||
          _sortOption == TaskSortOption.byDueDate;

      final agentFilterActive =
          _agentAssignmentFilter != AgentAssignmentFilter.all;
      final projectFilterActive = _selectedProjectIds.isNotEmpty;
      final needsPostFilter = agentFilterActive || projectFilterActive;

      if (!needsPostFilter) {
        _postFilterNextRawOffset = null;
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
        if (_sortOption == TaskSortOption.byDueDate) {
          return _sortByDueDate(res);
        }
        return res;
      }

      // Pre-fetch filter sets so the loop doesn't re-query each iteration.
      final projectTaskIds = projectFilterActive
          ? await _db.getTaskIdsForProjects(_selectedProjectIds)
          : null;
      final agentLinkedIds = agentFilterActive
          ? await _getAgentLinkedTaskIds()
          : null;

      // When post-filters are active, keep fetching raw pages until we
      // accumulate pageSize filtered results or the DB is exhausted.
      // This avoids premature pagination termination when many raw
      // tasks are discarded by the filter.
      final filtered = <JournalEntity>[];
      var currentOffset = pageKey;
      const fetchChunk = 50; // Same as pageSize — fetch in normal-sized chunks

      var pageFilled = false;
      while (!pageFilled && filtered.length < pageSize) {
        final raw = await _db.getTasks(
          ids: ids,
          starredStatuses: starredEntriesOnly ? [true] : [true, false],
          taskStatuses: _selectedTaskStatuses.toList(),
          categoryIds: categoryIds.toList(),
          labelIds: labelIds.toList(),
          priorities: priorities.toList(),
          sortByDate: sortByDateInDb,
          limit: fetchChunk,
          offset: currentOffset,
        );

        var consumedInChunk = 0;
        for (final entity in raw) {
          consumedInChunk++;
          var keep = true;
          if (projectTaskIds != null &&
              !projectTaskIds.contains(entity.meta.id)) {
            keep = false;
          }
          if (keep && agentLinkedIds != null) {
            final hasLink = agentLinkedIds.contains(entity.meta.id);
            keep = _agentAssignmentFilter == AgentAssignmentFilter.hasAgent
                ? hasLink
                : !hasLink;
          }
          if (keep) filtered.add(entity);
          if (filtered.length == pageSize) {
            currentOffset += consumedInChunk;
            pageFilled = true;
            break;
          }
        }

        if (!pageFilled) {
          currentOffset += raw.length;
        }
        // DB returned fewer than requested — no more data exists.
        if (raw.length < fetchChunk) break;
      }

      // Record the raw offset so getNextPageKey resumes correctly.
      _postFilterNextRawOffset = currentOffset;

      // Sort before truncating so the page contains the correct items.
      if (_sortOption == TaskSortOption.byDueDate) {
        return _sortByDueDate(filtered).take(pageSize).toList();
      }

      return filtered.take(pageSize).toList();
    } else {
      return _db.getJournalEntities(
        types: types,
        ids: ids,
        starredStatuses: starredEntriesOnly ? [true] : [true, false],
        privateStatuses: privateEntriesOnly ? [true] : [true, false],
        flaggedStatuses: flaggedEntriesOnly ? [1] : [1, 0],
        categoryIds: _selectedCategoryIds.isNotEmpty
            ? _selectedCategoryIds
            : null,
        limit: pageSize,
        offset: pageKey,
      );
    }
  }

  /// Executes a vector search and returns the results.
  ///
  /// Updates state with timing information for the UI indicator.
  Future<List<JournalEntity>> _runVectorSearch() async {
    if (!getIt.isRegistered<VectorSearchRepository>()) {
      DevLogger.warning(
        name: 'JournalPageController',
        message:
            'VectorSearchRepository not registered — '
            'is the embedding pipeline available?',
      );
      state = state.copyWith(
        vectorSearchInFlight: false,
        vectorSearchElapsed: Duration.zero,
        vectorSearchResultCount: 0,
        vectorSearchDistances: const {},
      );
      return [];
    }

    state = state.copyWith(
      vectorSearchInFlight: true,
      vectorSearchElapsed: Duration.zero,
      vectorSearchResultCount: 0,
      vectorSearchDistances: const {},
    );

    try {
      final repo = getIt<VectorSearchRepository>();
      final categoryIds = _selectedCategoryIds.isNotEmpty
          ? _selectedCategoryIds
          : null;

      final result = _showTasks
          ? await repo.searchRelatedTasks(
              query: _query,
              categoryIds: categoryIds,
            )
          : await repo.searchRelatedEntries(
              query: _query,
              categoryIds: categoryIds,
            );

      state = state.copyWith(
        vectorSearchInFlight: false,
        vectorSearchElapsed: result.elapsed,
        vectorSearchResultCount: result.entities.length,
        vectorSearchDistances: result.distances,
      );

      return result.entities;
    } on Exception catch (e) {
      DevLogger.warning(
        name: 'JournalPageController',
        message: 'Vector search failed: $e',
      );
      state = state.copyWith(
        vectorSearchInFlight: false,
        vectorSearchElapsed: Duration.zero,
        vectorSearchResultCount: 0,
        vectorSearchDistances: const {},
      );
      return [];
    }
  }

  /// Fetches the set of task IDs that have an agent_task link.
  /// Only called when the agent assignment filter is active.
  /// Cached per refresh cycle to avoid repeated DB hits during pagination.
  Future<Set<String>> _getAgentLinkedTaskIds() async {
    if (_cachedAgentLinkedIds != null) return _cachedAgentLinkedIds!;
    final repo = AgentRepository(getIt<AgentDatabase>());
    final ids = await repo.getTaskIdsWithAgentLink();
    _cachedAgentLinkedIds = ids;
    return ids;
  }

  /// Sorts tasks by due date (soonest first, tasks without due dates at end).
  /// Preserves creation date order for tasks with the same due date or no due date.
  ///
  /// Note: This sorting is applied per-page after database fetch. Due dates are
  /// stored in serialized JSON, not as an indexed column, so global cross-page
  /// ordering is not guaranteed. Tasks are correctly sorted within each page.
  List<JournalEntity> _sortByDueDate(List<JournalEntity> entities) {
    return List<JournalEntity>.from(entities)..sort((a, b) {
      final dueA = a is Task ? a.data.due : null;
      final dueB = b is Task ? b.data.due : null;

      final aHasDue = dueA != null;
      final bHasDue = dueB != null;

      if (aHasDue && bHasDue) {
        final comparison = dueA.compareTo(dueB);
        if (comparison != 0) return comparison;
      } else if (aHasDue) {
        return -1; // a has due date, b doesn't -> a comes first
      } else if (bHasDue) {
        return 1; // b has due date, a doesn't -> b comes first
      }

      // Fallback: same due date or both null -> newest creation date first
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
  bool get enableVectorSearchInternal => _enableVectorSearch;
  SearchMode get searchModeInternal => _searchMode;
}
