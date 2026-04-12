import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/journal/state/journal_filter_persistence.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/journal/state/journal_paging_controller.dart';
import 'package:lotti/features/journal/state/journal_query_runner.dart';
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
  static const tasksCategoryFiltersKey = 'TASKS_CATEGORY_FILTERS';
  static const journalCategoryFiltersKey = 'JOURNAL_CATEGORY_FILTERS';
  static const int pageSize = JournalQueryRunner.pageSize;

  // Delegates
  late final JournalFilterPersistence _persistence;
  late final JournalQueryRunner _queryRunner;

  // Services (via GetIt)
  late final JournalDb _db;
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
  bool _needsRefreshOnVisible = false;
  Set<String> _lastIds = {};
  Set<String> _selectedEntryTypes = entryTypes.toSet();
  Set<DisplayFilter> _filters = {};
  bool _enableEvents = false;
  bool _enableHabits = false;
  bool _enableDashboards = false;
  bool _enableVectorSearch = false;
  bool _enableProjects = false;
  SearchMode _searchMode = SearchMode.fullText;
  bool _hasExplicitSearchModeSelection = false;
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

  /// When post-filters (project/agent) are active, `_runQuery` may consume
  /// more raw DB rows than it returns filtered results. This field tracks
  /// the actual raw offset to resume from on the next page, avoiding
  /// duplicate or missed rows.
  int? _postFilterNextRawOffset;

  // Same default for both tabs
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
    final settingsDb = getIt<SettingsDb>();
    final fts5Db = getIt<Fts5Db>();
    _updateNotifications = getIt<UpdateNotifications>();
    _entitiesCacheService = getIt<EntitiesCacheService>();

    // Initialize delegates
    _persistence = JournalFilterPersistence(settingsDb);
    _queryRunner = JournalQueryRunner(
      db: _db,
      fts5Db: fts5Db,
      entitiesCacheService: _entitiesCacheService,
    );

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
    final controller = _createPagingController()..fetchNextPage();

    // Set up subscriptions
    _setupSubscriptions(showTasks);

    // Load persisted filters
    _loadPersistedFilters();
    _loadPersistedEntryTypes();

    // Register hotkeys (desktop only)
    _registerHotkeys();

    // Clean up on dispose
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
      selectedTaskStatuses: _selectedTaskStatuses,
      sortOption: _sortOption,
      showCreationDate: _showCreationDate,
      showDueDate: _showDueDate,
      showCoverArt: _showCoverArt,
      showProjectsHeader: _showProjectsHeader,
      showDistances: _showDistances,
    );
  }

  // ---------------------------------------------------------------
  // Paging controller
  // ---------------------------------------------------------------

  PagingController<int, JournalEntity> _createPagingController() {
    return JournalPagingController(
      getNextPageKey: _getNextPageKey,
      fetchPage: _fetchPage,
    );
  }

  int? _getNextPageKey(
    PagingState<int, JournalEntity> pagingState, {
    bool consumePostFilterOffset = true,
  }) {
    final currentKeys = pagingState.keys;
    if (currentKeys == null || currentKeys.isEmpty) {
      return 0;
    }
    if (!pagingState.hasNextPage) {
      return null;
    }
    final currentPages = pagingState.pages;
    if (currentPages != null &&
        currentPages.isNotEmpty &&
        currentPages.last.length < pageSize) {
      return null;
    }
    if (_postFilterNextRawOffset != null) {
      final offset = _postFilterNextRawOffset!;
      if (consumePostFilterOffset) {
        _postFilterNextRawOffset = null;
      }
      return offset;
    }
    if (currentPages != null &&
        currentPages.isNotEmpty &&
        currentKeys.length == currentPages.length) {
      final lastFetchedItemsCount = currentPages.last.length;
      return currentKeys.last + lastFetchedItemsCount;
    }
    return currentKeys.last +
        ((currentPages != null &&
                currentPages.isNotEmpty &&
                currentKeys.length == currentPages.length)
            ? currentPages.last.length
            : 0);
  }

  // ---------------------------------------------------------------
  // Retained refresh
  // ---------------------------------------------------------------

  Future<void> _refreshLoadedPagesPreservingVisibleItems(
    JournalPagingController pagingController,
  ) async {
    final loadedPageKeys = _loadedVisiblePageKeys(pagingController);
    final loadedPageCount = loadedPageKeys.length;
    if (loadedPageCount == 0) {
      pagingController
        ..refresh()
        ..fetchNextPage();
      return;
    }

    final refreshToken = Object();
    pagingController.startRetainedRefresh(refreshToken);

    try {
      late final List<List<JournalEntity>> refreshedPages;
      late final List<int> refreshedKeys;
      int? retainedNextRawOffset;
      if (_requiresSequentialRetainedRefresh) {
        refreshedPages = <List<JournalEntity>>[];
        refreshedKeys = <int>[];
        int? nextPageKey = 0;

        for (
          var pageIndex = 0;
          pageIndex < loadedPageCount && nextPageKey != null;
          pageIndex++
        ) {
          final pageKey = nextPageKey;
          refreshedKeys.add(pageKey);

          final items = await _runQuery(
            pageKey,
            setPostFilterNextRawOffset: (value) {
              retainedNextRawOffset = value;
            },
          );
          if (!ref.mounted) return;
          if (!pagingController.isRetainedRefresh(refreshToken)) return;

          refreshedPages.add(items);

          if (pageIndex < loadedPageCount - 1) {
            nextPageKey = items.length < pageSize
                ? null
                : retainedNextRawOffset ?? pageKey + items.length;
          }
        }
      } else {
        refreshedKeys = loadedPageKeys;
        refreshedPages = await Future.wait(
          refreshedKeys.map(_runQuery),
        );
        if (!ref.mounted) return;
        if (!pagingController.isRetainedRefresh(refreshToken)) return;
      }

      final hasNextPage =
          refreshedPages.length == loadedPageCount &&
          refreshedPages.isNotEmpty &&
          refreshedPages.last.length == pageSize;

      _postFilterNextRawOffset =
          _requiresSequentialRetainedRefresh && hasNextPage
          ? retainedNextRawOffset
          : null;

      if (refreshedPages.isNotEmpty) {
        _rememberLeadingTaskIds(refreshedPages.first);
      }

      pagingController.replacePages(
        refreshedPages,
        keys: refreshedKeys,
        hasNextPage: hasNextPage,
      );
    } catch (error, stackTrace) {
      DevLogger.warning(
        name: 'JournalPageController',
        message: 'Error in retained visible-page refresh: $error\n$stackTrace',
      );
      if (!ref.mounted) return;
      if (!pagingController.isRetainedRefresh(refreshToken)) return;
      pagingController.finishRetainedRefreshWithError(
        error,
        refreshToken: refreshToken,
      );
      if (error is! Exception) rethrow;
    }
  }

  // ---------------------------------------------------------------
  // Subscriptions
  // ---------------------------------------------------------------

  void _setupSubscriptions(bool showTasks) {
    _privateFlagSub = _db.watchConfigFlag('private').listen((showPrivate) {
      _showPrivateEntries = showPrivate;
      _emitState();
    });

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
            .listen(_onConfigFlagsChanged);

    String idMapper(JournalEntity entity) => entity.meta.id;

    _updatesSub = _updateNotifications.updateStream.listen((affectedIds) async {
      if (_isVisible) {
        final displayedIds =
            state.pagingController?.value.items?.map(idMapper).toSet() ??
            <String>{};
        final affectsDisplayedItems = displayedIds
            .intersection(affectedIds)
            .isNotEmpty;

        if (showTasks) {
          if (affectsDisplayedItems) {
            await refreshQuery(preserveVisibleItems: true);
            return;
          }

          final savedOffset = _postFilterNextRawOffset;
          final newIds = (await _runQuery(0)).map(idMapper).toSet();
          _postFilterNextRawOffset = savedOffset;
          if (!setEquals(_lastIds, newIds)) {
            _lastIds = newIds;
            await refreshQuery(preserveVisibleItems: true);
          }
        } else {
          if (affectsDisplayedItems) {
            await refreshQuery(preserveVisibleItems: true);
          }
        }
      } else {
        _needsRefreshOnVisible = true;
      }
    });
  }

  void _onConfigFlagsChanged(
    ({
      bool events,
      bool habits,
      bool dashboards,
      bool vectorSearch,
      bool projects,
    })
    flags,
  ) {
    final oldAllowed = computeAllowedEntryTypes(
      events: _enableEvents,
      habits: _enableHabits,
      dashboards: _enableDashboards,
    ).toSet();

    _enableEvents = flags.events;
    _enableHabits = flags.habits;
    _enableDashboards = flags.dashboards;
    _enableVectorSearch = flags.vectorSearch;
    _enableProjects = flags.projects;
    var shouldRefreshAfterModeFallback = false;
    if (_showTasks &&
        isDesktop &&
        _enableVectorSearch &&
        !_hasExplicitSearchModeSelection &&
        _searchMode != SearchMode.vector) {
      _searchMode = SearchMode.vector;
      shouldRefreshAfterModeFallback = true;
    } else if (!_enableVectorSearch && _searchMode == SearchMode.vector) {
      _searchMode = SearchMode.fullText;
      shouldRefreshAfterModeFallback = true;
    }
    if (!_enableProjects && _selectedProjectIds.isNotEmpty) {
      _selectedProjectIds = {};
      shouldRefreshAfterModeFallback = true;
    }

    final newAllowed = computeAllowedEntryTypes(
      events: _enableEvents,
      habits: _enableHabits,
      dashboards: _enableDashboards,
    ).toSet();

    final hadAllPreviouslySelected =
        oldAllowed.isNotEmpty && setEquals(_selectedEntryTypes, oldAllowed);

    final prevSelection = _selectedEntryTypes;

    if (_selectedEntryTypes.isEmpty || hadAllPreviouslySelected) {
      _selectedEntryTypes = newAllowed;
    } else {
      _selectedEntryTypes = _selectedEntryTypes.intersection(newAllowed);
    }

    _emitState();

    if (shouldRefreshAfterModeFallback) {
      unawaited(refreshQuery(preserveVisibleItems: true));
    }

    if (!setEquals(prevSelection, _selectedEntryTypes)) {
      persistEntryTypes();
    }
  }

  void _registerHotkeys() {
    if (isDesktop) {
      hotKeyManager.register(
        HotKey(
          key: LogicalKeyboardKey.keyR,
          modifiers: [HotKeyModifier.meta],
          scope: HotKeyScope.inapp,
        ),
        keyDownHandler: (hotKey) => refreshQuery(preserveVisibleItems: true),
      );
    }
  }

  void _dispose(PagingController<int, JournalEntity> controller) {
    _configFlagsSub?.cancel();
    _privateFlagSub?.cancel();
    _updatesSub?.cancel();
    controller.dispose();
  }

  // ---------------------------------------------------------------
  // State emission
  // ---------------------------------------------------------------

  void _emitState() {
    state = state.copyWith(
      match: _query,
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

  String _getCategoryFiltersKey() {
    return _showTasks ? tasksCategoryFiltersKey : journalCategoryFiltersKey;
  }

  // ---------------------------------------------------------------
  // Public API — filter toggles
  // ---------------------------------------------------------------

  void setFilters(Set<DisplayFilter> filters) {
    _filters = filters;
    refreshQuery();
  }

  Future<void> toggleSelectedTaskStatus(String status) async {
    if (_selectedTaskStatuses.contains(status)) {
      _selectedTaskStatuses = _selectedTaskStatuses.difference({status});
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
      _selectedEntryTypes = _selectedEntryTypes.difference({entryType});
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

  Future<void> setAgentAssignmentFilter(AgentAssignmentFilter filter) async {
    _agentAssignmentFilter = filter;
    await persistTasksFilter();
  }

  Future<void> setSortOption(TaskSortOption option) async {
    _sortOption = option;
    await persistTasksFilter();
  }

  void setSearchMode(SearchMode mode) {
    _hasExplicitSearchModeSelection = true;
    _searchMode = _enableVectorSearch ? mode : SearchMode.fullText;
    refreshQuery();
  }

  Future<void> setShowCreationDate({required bool show}) async {
    _showCreationDate = show;
    _emitState();
    await _persistTasksFilterWithoutRefresh();
  }

  Future<void> setShowDueDate({required bool show}) async {
    _showDueDate = show;
    _emitState();
    await _persistTasksFilterWithoutRefresh();
  }

  Future<void> setShowCoverArt({required bool show}) async {
    _showCoverArt = show;
    _emitState();
    await _persistTasksFilterWithoutRefresh();
  }

  Future<void> setShowProjectsHeader({required bool show}) async {
    _showProjectsHeader = show;
    _emitState();
    await _persistTasksFilterWithoutRefresh();
  }

  Future<void> setShowDistances({required bool show}) async {
    _showDistances = show;
    _emitState();
    await _persistTasksFilterWithoutRefresh();
  }

  // ---------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------

  Future<void> _loadPersistedFilters() async {
    final perTabKey = _getCategoryFiltersKey();
    final tasksFilter = await _persistence.loadFilters(perTabKey);
    if (tasksFilter == null) return;

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

    _selectedCategoryIds = tasksFilter.selectedCategoryIds;
    _emitState();
    await refreshQuery();
  }

  Future<void> _loadPersistedEntryTypes() async {
    final entryTypes = await _persistence.loadEntryTypes();
    if (entryTypes == null) return;
    _selectedEntryTypes = entryTypes;
    _emitState();
    await refreshQuery();
  }

  Future<void> persistTasksFilter() async {
    await refreshQuery();
    await _persistTasksFilterWithoutRefresh();
  }

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
    await _persistence.saveFilters(filter, _getCategoryFiltersKey());
  }

  Future<void> persistEntryTypes() async {
    await refreshQuery();
    await _persistence.saveEntryTypes(_selectedEntryTypes);
  }

  // ---------------------------------------------------------------
  // Search and query
  // ---------------------------------------------------------------

  Future<void> setSearchString(String query) async {
    _query = query;
    await refreshQuery();
  }

  Future<void> refreshQuery({bool preserveVisibleItems = false}) async {
    _queryRunner.clearCache();
    _emitState();

    final pagingController = state.pagingController;
    if (pagingController == null) {
      DevLogger.warning(
        name: 'JournalPageController',
        message: 'refreshQuery called but pagingController is null',
      );
      return;
    }

    if (preserveVisibleItems &&
        pagingController is JournalPagingController &&
        pagingController.hasVisibleItems) {
      await _refreshLoadedPagesPreservingVisibleItems(pagingController);
      return;
    }

    pagingController
      ..refresh()
      ..fetchNextPage();
  }

  void updateVisibility(VisibilityInfo visibilityInfo) {
    final isVisible = visibilityInfo.visibleBounds.size.width > 0;
    if (!_isVisible && isVisible && _needsRefreshOnVisible) {
      _needsRefreshOnVisible = false;
      refreshQuery(preserveVisibleItems: true);
    }
    _isVisible = isVisible;
  }

  Future<List<JournalEntity>> _fetchPage(int pageKey) async {
    try {
      final items = await _runQuery(pageKey);
      if (pageKey == 0) {
        _rememberLeadingTaskIds(items);
      }
      return items;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        print('Error in _fetchPage: $error\n$stackTrace');
      }
      rethrow;
    }
  }

  Future<List<JournalEntity>> _runQuery(
    int pageKey, {
    void Function(int? nextRawOffset)? setPostFilterNextRawOffset,
  }) async {
    final applyOffset =
        setPostFilterNextRawOffset ??
        (int? value) => _postFilterNextRawOffset = value;

    final params = _buildQueryParams();

    // Vector search: bypass FTS5, update telemetry on state directly.
    if (params.enableVectorSearch &&
        params.searchMode == SearchMode.vector &&
        params.query.isNotEmpty &&
        pageKey == 0) {
      return _runVectorSearchWithTelemetry(params);
    }

    _fullTextMatches = await _queryRunner.fts5Search(params.query);

    return _queryRunner.runQuery(
      params,
      pageKey,
      fullTextMatches: _fullTextMatches,
      setPostFilterNextRawOffset: applyOffset,
    );
  }

  Future<List<JournalEntity>> _runVectorSearchWithTelemetry(
    JournalQueryParams params,
  ) async {
    state = state.copyWith(
      vectorSearchInFlight: true,
      vectorSearchElapsed: Duration.zero,
      vectorSearchResultCount: 0,
      vectorSearchDistances: const {},
    );

    final result = await _queryRunner.runVectorSearch(params);

    state = state.copyWith(
      vectorSearchInFlight: false,
      vectorSearchElapsed: result.elapsed,
      vectorSearchResultCount: result.entities.length,
      vectorSearchDistances: result.distances,
    );

    return result.entities;
  }

  JournalQueryParams _buildQueryParams() {
    return JournalQueryParams(
      showTasks: _showTasks,
      selectedEntryTypes: _selectedEntryTypes,
      selectedCategoryIds: _selectedCategoryIds,
      selectedProjectIds: _selectedProjectIds,
      selectedLabelIds: _selectedLabelIds,
      selectedPriorities: _selectedPriorities,
      selectedTaskStatuses: _selectedTaskStatuses,
      sortOption: _sortOption,
      agentAssignmentFilter: _agentAssignmentFilter,
      filters: _filters,
      query: _query,
      enableVectorSearch: _enableVectorSearch,
      searchMode: _searchMode,
      enableEvents: _enableEvents,
      enableHabits: _enableHabits,
      enableDashboards: _enableDashboards,
    );
  }

  // ---------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------

  bool get _requiresSequentialRetainedRefresh =>
      _showTasks &&
      (_agentAssignmentFilter != AgentAssignmentFilter.all ||
          _selectedProjectIds.isNotEmpty);

  List<int> _loadedVisiblePageKeys(JournalPagingController pagingController) {
    final pages = pagingController.value.pages;
    final keys = pagingController.value.keys;
    if (pages == null || keys == null) return const [];

    final sharedLength = pages.length < keys.length
        ? pages.length
        : keys.length;
    final loadedPageKeys = <int>[];
    for (var index = 0; index < sharedLength; index++) {
      if (pages[index].isNotEmpty) {
        loadedPageKeys.add(keys[index]);
      }
    }
    return loadedPageKeys;
  }

  void _rememberLeadingTaskIds(Iterable<JournalEntity> items) {
    if (!_showTasks) return;
    _lastIds = items.map((entity) => entity.meta.id).toSet();
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
