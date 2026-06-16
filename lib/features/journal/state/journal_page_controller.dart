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
import 'package:lotti/features/journal/state/journal_page_subscriptions.dart';
import 'package:lotti/features/journal/state/journal_paging_controller.dart';
import 'package:lotti/features/journal/state/journal_query_runner.dart';
import 'package:lotti/features/journal/utils/entry_types.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/platform.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'journal_page_controller.g.dart';
part 'journal_page_controller_filters.dart';

/// Controller for managing journal/tasks page state.
///
/// Uses a family provider pattern with showTasks as the family key.
/// keepAlive: true to preserve state when switching tabs.
@Riverpod(keepAlive: true)
class JournalPageController extends _$JournalPageController
    with _JournalPageFilters {
  // Storage keys
  static const tasksCategoryFiltersKey = 'TASKS_CATEGORY_FILTERS';
  static const journalCategoryFiltersKey = 'JOURNAL_CATEGORY_FILTERS';
  static const int pageSize = JournalQueryRunner.pageSize;

  /// Canonical list of task-status strings persisted in the DB.
  ///
  /// Kept here alongside the controller that drives the query so the
  /// paging layer does not depend on the tasks UI module to know what
  /// "all statuses" means.
  static const List<String> allTaskStatusValues = <String>[
    'OPEN',
    'GROOMED',
    'IN PROGRESS',
    'BLOCKED',
    'ON HOLD',
    'DONE',
    'REJECTED',
  ];

  // Delegates
  late final JournalFilterPersistence _persistence;
  late final JournalQueryRunner _queryRunner;
  late final JournalPageSubscriptions _subscriptions;
  StreamSubscription<int>? _navIndexSubscription;

  // Internal state (mutable for efficiency, exposed via immutable state)
  bool _isVisible = false;
  bool _needsRefreshOnVisible = false;
  Set<String> _lastIds = {};
  @override
  Set<String> _selectedEntryTypes = entryTypes.toSet();
  @override
  Set<DisplayFilter> _filters = {};
  bool _enableEvents = false;
  bool _enableHabits = false;
  bool _enableDashboards = false;
  @override
  bool _enableVectorSearch = false;
  bool _enableProjects = false;
  @override
  SearchMode _searchMode = SearchMode.fullText;
  @override
  bool _hasExplicitSearchModeSelection = false;
  String _query = '';
  bool _showPrivateEntries = false;
  late bool _showTasks;
  @override
  Set<String> _selectedCategoryIds = {};
  @override
  Set<String> _selectedProjectIds = {};
  @override
  Set<String> _selectedLabelIds = {};
  @override
  Set<String> _selectedPriorities = {};
  Set<String> _fullTextMatches = {};
  @override
  TaskSortOption _sortOption = TaskSortOption.byPriority;
  @override
  bool _showCreationDate = false;
  @override
  bool _showDueDate = true;
  bool _showCoverArt = true;
  bool _showProjectsHeader = true;
  bool _showDistances = false;
  @override
  AgentAssignmentFilter _agentAssignmentFilter = AgentAssignmentFilter.all;
  int? _postFilterNextRawOffset;
  @override
  Set<String> _selectedTaskStatuses = {'OPEN', 'GROOMED', 'IN PROGRESS'};

  @override
  JournalPageState build(bool showTasks) {
    _showTasks = showTasks;

    // Initialize services
    final db = getIt<JournalDb>();
    final settingsDb = getIt<SettingsDb>();
    final fts5Db = getIt<Fts5Db>();
    final updateNotifications = getIt<UpdateNotifications>();
    final entitiesCacheService = getIt<EntitiesCacheService>();

    // Initialize delegates
    _persistence = JournalFilterPersistence(settingsDb);
    _queryRunner = JournalQueryRunner(
      db: db,
      fts5Db: fts5Db,
      entitiesCacheService: entitiesCacheService,
    );
    _subscriptions = JournalPageSubscriptions(
      db: db,
      updateNotifications: updateNotifications,
    );

    // Visibility tracking is driven by the top-level nav index. The
    // controller starts visible if its tab is the active one when
    // build() runs (the page provider is keepAlive, so the first build
    // typically coincides with the tab being shown).
    final navService = getIt<NavService>();
    _isVisible = navService.index == _myTabIndex(navService);
    _navIndexSubscription = navService.getIndexStream().listen(
      _handleNavIndex,
    );

    // Initialize category selection for tasks tab
    if (showTasks) {
      final allCategoryIds = entitiesCacheService.sortedCategories
          .map((e) => e.id)
          .toSet();
      if (allCategoryIds.isEmpty) {
        _selectedCategoryIds = {''};
      }
    }

    // Create pagination controller
    final controller = _createPagingController()..fetchNextPage();

    // Set up subscriptions
    _subscriptions.setup(
      showTasks: showTasks,
      onPrivateFlagChanged: (showPrivate) {
        _showPrivateEntries = showPrivate;
        _emitState();
      },
      onJournalConfigFlagsChanged: _onJournalConfigFlagsChanged,
      onUpdateNotification: (affectedIds) =>
          _onUpdateNotification(affectedIds, showTasks: showTasks),
    );

    // Load persisted filters
    _loadPersistedFilters();
    _loadPersistedEntryTypes();

    // Register hotkeys (desktop only)
    _registerHotkeys();

    // Clean up on dispose
    ref.onDispose(() {
      _subscriptions.dispose();
      _navIndexSubscription?.cancel();
      controller.dispose();
    });

    return JournalPageState(
      showTasks: showTasks,
      pagingController: controller,
      selectedEntryTypes: _selectedEntryTypes.toList(),
      selectedCategoryIds: _selectedCategoryIds,
      selectedProjectIds: _selectedProjectIds,
      selectedLabelIds: _selectedLabelIds,
      selectedPriorities: _selectedPriorities,
      taskStatuses: allTaskStatusValues,
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
    if (currentKeys == null || currentKeys.isEmpty) return 0;
    if (!pagingState.hasNextPage) return null;
    final currentPages = pagingState.pages;
    if (currentPages != null &&
        currentPages.isNotEmpty &&
        currentPages.last.length < pageSize) {
      return null;
    }
    if (_postFilterNextRawOffset != null) {
      final offset = _postFilterNextRawOffset!;
      if (consumePostFilterOffset) _postFilterNextRawOffset = null;
      return offset;
    }
    if (currentPages != null &&
        currentPages.isNotEmpty &&
        currentKeys.length == currentPages.length) {
      return currentKeys.last + currentPages.last.length;
    }
    return currentKeys.last +
        ((currentPages != null &&
                currentPages.isNotEmpty &&
                currentKeys.length == currentPages.length)
            ? currentPages.last.length
            : 0);
  }

  // ---------------------------------------------------------------
  // Subscription callbacks
  // ---------------------------------------------------------------

  void _onJournalConfigFlagsChanged(JournalConfigFlags flags) {
    final result = JournalPageSubscriptions.applyJournalConfigFlags(
      flags: flags,
      showTasks: _showTasks,
      enableEvents: _enableEvents,
      enableHabits: _enableHabits,
      enableDashboards: _enableDashboards,
      enableVectorSearch: _enableVectorSearch,
      enableProjects: _enableProjects,
      searchMode: _searchMode,
      hasExplicitSearchModeSelection: _hasExplicitSearchModeSelection,
      selectedEntryTypes: _selectedEntryTypes,
      selectedProjectIds: _selectedProjectIds,
    );

    final prevSelection = _selectedEntryTypes;
    _enableEvents = result.enableEvents;
    _enableHabits = result.enableHabits;
    _enableDashboards = result.enableDashboards;
    _enableVectorSearch = result.enableVectorSearch;
    _enableProjects = result.enableProjects;
    _searchMode = result.searchMode;
    _selectedEntryTypes = result.selectedEntryTypes;
    _selectedProjectIds = result.selectedProjectIds;

    _emitState();

    if (result.shouldRefresh) {
      unawaited(refreshQuery(preserveVisibleItems: true));
    }
    if (!setEquals(prevSelection, _selectedEntryTypes)) {
      persistEntryTypes();
    }
  }

  Future<void> _onUpdateNotification(
    Set<String> affectedIds, {
    required bool showTasks,
  }) async {
    if (_isVisible) {
      String idMapper(JournalEntity entity) => entity.meta.id;
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

  // ---------------------------------------------------------------
  // State emission
  // ---------------------------------------------------------------

  @override
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

  // ---------------------------------------------------------------
  // Search and query
  // ---------------------------------------------------------------

  Future<void> setSearchString(String query) async {
    _query = query;
    await refreshQuery();
  }

  @override
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
      await pagingController.refreshLoadedPages(
        runQuery: _runQuery,
        requiresSequential: _requiresSequentialRetainedRefresh,
        pageSize: pageSize,
        isMounted: () => ref.mounted,
        onPostFilterOffset: (offset) => _postFilterNextRawOffset = offset,
        onLeadingItems: _rememberLeadingTaskIds,
      );
      return;
    }

    pagingController
      ..refresh()
      ..fetchNextPage();
  }

  /// Tab index that this controller's page lives at, derived from
  /// `showTasks`. The tasks tab is always at index 0; the journal tab
  /// position depends on which other tabs are enabled, so we ask the
  /// NavService for it.
  int _myTabIndex(NavService navService) =>
      _showTasks ? navService.tasksIndex : navService.journalIndex;

  /// Drains a deferred refresh when this controller's tab becomes the
  /// active top-level tab. Updates from the DB stream while the tab is
  /// hidden are coalesced via `_needsRefreshOnVisible`; this method
  /// fires the held-back refresh on the inactive→active edge.
  void _handleNavIndex(int newIndex) {
    if (!ref.mounted) return;

    final isVisible = newIndex == _myTabIndex(getIt<NavService>());
    if (!_isVisible && isVisible && _needsRefreshOnVisible) {
      _needsRefreshOnVisible = false;
      unawaited(refreshQuery(preserveVisibleItems: true));
    }
    _isVisible = isVisible;
  }

  /// Test-only entry point that lets tests drive the visibility edge
  /// without standing up a full NavService stream. Equivalent to a
  /// nav-index emission whose value resolves to `isVisible`.
  /// Test-only seam for [_getNextPageKey] — the pure page-key computation
  /// over a [PagingState] (plus the one-shot post-filter offset).
  @visibleForTesting
  int? debugGetNextPageKey(
    PagingState<int, JournalEntity> pagingState, {
    bool consumePostFilterOffset = true,
  }) => _getNextPageKey(
    pagingState,
    consumePostFilterOffset: consumePostFilterOffset,
  );

  /// Test-only seam to read/seed the one-shot post-filter raw offset.
  @visibleForTesting
  int? get debugPostFilterNextRawOffset => _postFilterNextRawOffset;

  @visibleForTesting
  set debugPostFilterNextRawOffset(int? value) =>
      _postFilterNextRawOffset = value;

  @visibleForTesting
  void debugSetVisibility({required bool isVisible}) {
    _handleNavIndex(
      isVisible ? _myTabIndex(getIt<NavService>()) : -1,
    );
  }

  Future<List<JournalEntity>> _fetchPage(int pageKey) async {
    try {
      final items = await _runQuery(pageKey);
      if (pageKey == 0) _rememberLeadingTaskIds(items);
      return items;
    } catch (error, stackTrace) {
      if (kDebugMode) print('Error in _fetchPage: $error\n$stackTrace');
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
    // An empty selection means "no status filter" → query across all statuses
    // rather than returning zero rows because `task_status IN ()` matches
    // nothing.
    final effectiveTaskStatuses = _selectedTaskStatuses.isEmpty
        ? allTaskStatusValues.toSet()
        : _selectedTaskStatuses;
    return JournalQueryParams(
      showTasks: _showTasks,
      selectedEntryTypes: _selectedEntryTypes,
      selectedCategoryIds: _selectedCategoryIds,
      selectedProjectIds: _selectedProjectIds,
      selectedLabelIds: _selectedLabelIds,
      selectedPriorities: _selectedPriorities,
      selectedTaskStatuses: effectiveTaskStatuses,
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

  /// Test-only seam for [_requiresSequentialRetainedRefresh].
  @visibleForTesting
  bool get debugRequiresSequentialRetainedRefresh =>
      _requiresSequentialRetainedRefresh;

  bool get _requiresSequentialRetainedRefresh =>
      _showTasks &&
      (_agentAssignmentFilter != AgentAssignmentFilter.all ||
          _selectedProjectIds.isNotEmpty);

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

  // ---------------------------------------------------------------
  // Filter mutation + persistence
  // ---------------------------------------------------------------

  String _getCategoryFiltersKey() {
    return _showTasks
        ? JournalPageController.tasksCategoryFiltersKey
        : JournalPageController.journalCategoryFiltersKey;
  }

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

  @override
  Future<void> persistTasksFilter() async {
    // Swap visible items in place instead of clearing-then-refetching so the
    // list doesn't flicker when the user toggles a filter chip.
    await refreshQuery(preserveVisibleItems: true);
    await _persistTasksFilterWithoutRefresh();
  }

  @override
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

  @override
  Future<void> persistEntryTypes() async {
    await refreshQuery();
    await _persistence.saveEntryTypes(_selectedEntryTypes);
  }
}
