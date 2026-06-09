part of 'journal_page_controller.dart';

/// Filter-mutation and persistence methods of [JournalPageController].
/// Extracted into a part-file mixin to keep the controller file under the
/// size limit; shared filter state is reached through abstract accessors that
/// the concrete controller satisfies with its own fields.
mixin _JournalPageFilters on _$JournalPageController {
  JournalFilterPersistence get _persistence;
  Set<String> get _selectedEntryTypes;
  set _selectedEntryTypes(Set<String> value);
  set _filters(Set<DisplayFilter> value);
  bool get _enableVectorSearch;
  set _searchMode(SearchMode value);
  set _hasExplicitSearchModeSelection(bool value);
  bool get _showTasks;
  Set<String> get _selectedCategoryIds;
  set _selectedCategoryIds(Set<String> value);
  Set<String> get _selectedProjectIds;
  set _selectedProjectIds(Set<String> value);
  Set<String> get _selectedLabelIds;
  set _selectedLabelIds(Set<String> value);
  Set<String> get _selectedPriorities;
  set _selectedPriorities(Set<String> value);
  TaskSortOption get _sortOption;
  set _sortOption(TaskSortOption value);
  bool get _showCreationDate;
  set _showCreationDate(bool value);
  bool get _showDueDate;
  set _showDueDate(bool value);
  bool get _showCoverArt;
  set _showCoverArt(bool value);
  bool get _showProjectsHeader;
  set _showProjectsHeader(bool value);
  bool get _showDistances;
  set _showDistances(bool value);
  AgentAssignmentFilter get _agentAssignmentFilter;
  set _agentAssignmentFilter(AgentAssignmentFilter value);
  Set<String> get _selectedTaskStatuses;
  set _selectedTaskStatuses(Set<String> value);
  void _emitState();
  Future<void> refreshQuery({bool preserveVisibleItems});

  String _getCategoryFiltersKey() {
    return _showTasks
        ? JournalPageController.tasksCategoryFiltersKey
        : JournalPageController.journalCategoryFiltersKey;
  }

  // ---------------------------------------------------------------
  // Public API — filter toggles
  // ---------------------------------------------------------------

  void setFilters(Set<DisplayFilter> filters) {
    _filters = filters;
    refreshQuery();
  }

  /// Replaces all selected task statuses at once.
  Future<void> setSelectedTaskStatuses(Set<String> statuses) async {
    _selectedTaskStatuses = {...statuses};
    await persistTasksFilter();
  }

  /// Replaces all selected category IDs at once.
  Future<void> setSelectedCategoryIds(Set<String> categoryIds) async {
    _selectedCategoryIds = {...categoryIds};
    // Project filters are category-scoped — clear when categories change
    // to avoid invisible stale filters for a previous category.
    _selectedProjectIds = {};
    await persistTasksFilter();
  }

  /// Replaces all selected label IDs at once.
  Future<void> setSelectedLabelIds(Set<String> labelIds) async {
    _selectedLabelIds = {...labelIds};
    await persistTasksFilter();
  }

  /// Replaces all selected project IDs at once.
  Future<void> setSelectedProjectIds(Set<String> projectIds) async {
    _selectedProjectIds = {...projectIds};
    await persistTasksFilter();
  }

  /// Replaces all selected priorities at once.
  Future<void> setSelectedPriorities(Set<String> priorities) async {
    _selectedPriorities = {...priorities};
    await persistTasksFilter();
  }

  /// Applies all filter changes at once with a single persist/refresh cycle.
  ///
  /// Use this when multiple filter fields change simultaneously (e.g. from
  /// the filter sheet "Apply" button) to avoid intermediate query refreshes.
  ///
  /// Unlike [setSelectedCategoryIds], this does NOT automatically clear
  /// projects when categories change — the caller (filter modal) manages
  /// the project/category relationship and always provides both fields.
  Future<void> applyBatchFilterUpdate({
    Set<String>? statuses,
    Set<String>? categoryIds,
    Set<String>? labelIds,
    Set<String>? projectIds,
    Set<String>? priorities,
    TaskSortOption? sortOption,
    AgentAssignmentFilter? agentAssignmentFilter,
    SearchMode? searchMode,
    bool? showCreationDate,
    bool? showDueDate,
  }) async {
    if (statuses != null) _selectedTaskStatuses = {...statuses};
    if (categoryIds != null) _selectedCategoryIds = {...categoryIds};
    if (labelIds != null) _selectedLabelIds = {...labelIds};
    if (projectIds != null) _selectedProjectIds = {...projectIds};
    if (priorities != null) _selectedPriorities = {...priorities};
    if (sortOption != null) _sortOption = sortOption;
    if (agentAssignmentFilter != null) {
      _agentAssignmentFilter = agentAssignmentFilter;
    }
    if (searchMode != null && _enableVectorSearch) {
      _hasExplicitSearchModeSelection = true;
      _searchMode = searchMode;
    }
    if (showCreationDate != null) _showCreationDate = showCreationDate;
    if (showDueDate != null) _showDueDate = showDueDate;

    await persistTasksFilter();
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
    // Swap visible items in place instead of clearing-then-refetching so the
    // list doesn't flicker when the user toggles a filter chip.
    await refreshQuery(preserveVisibleItems: true);
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
}
