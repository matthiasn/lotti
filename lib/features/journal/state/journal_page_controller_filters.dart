part of 'journal_page_controller.dart';

/// Filter-state mutation methods for [JournalPageController].
///
/// A `mixin on Notifier<JournalPageState>` (not a helper class) because these
/// methods mutate the Notifier's filter state and drive its refresh/persist/
/// emit lifecycle. Filter fields stay on the concrete class (satisfying the
/// abstract accessors below); the lifecycle hooks are likewise concrete.
mixin _JournalPageFilters on Notifier<JournalPageState> {
  // Filter state owned by the concrete JournalPageController.
  set _filters(Set<DisplayFilter> value);
  Set<String> get _selectedEntryTypes;
  set _selectedEntryTypes(Set<String> value);
  bool get _enableVectorSearch;
  set _searchMode(SearchMode value);
  set _hasExplicitSearchModeSelection(bool value);
  Set<String> get _selectedCategoryIds;
  set _selectedCategoryIds(Set<String> value);
  Set<String> get _selectedProjectIds;
  set _selectedProjectIds(Set<String> value);
  Set<String> get _selectedLabelIds;
  set _selectedLabelIds(Set<String> value);
  Set<String> get _selectedPriorities;
  set _selectedPriorities(Set<String> value);
  set _sortOption(TaskSortOption value);
  set _showCreationDate(bool value);
  set _showDueDate(bool value);
  set _agentAssignmentFilter(AgentAssignmentFilter value);
  Set<String> get _selectedTaskStatuses;
  set _selectedTaskStatuses(Set<String> value);

  // Lifecycle hooks implemented by the concrete JournalPageController.
  void _emitState();
  Future<void> refreshQuery({bool preserveVisibleItems});
  Future<void> persistTasksFilter();
  Future<void> _persistTasksFilterWithoutRefresh();
  Future<void> persistEntryTypes();

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
}
