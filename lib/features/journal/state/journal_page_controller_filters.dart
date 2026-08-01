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
  set _selectedProjectIds(Set<String> value);
  set _selectedLabelIds(Set<String> value);
  set _selectedPriorities(Set<String> value);
  set _sortOption(TaskSortOption value);
  set _showCreationDate(bool value);
  set _showDueDate(bool value);
  set _agentAssignmentFilter(AgentAssignmentFilter value);
  set _selectedTaskStatuses(Set<String> value);

  // Lifecycle hooks implemented by the concrete JournalPageController.
  void _emitState();
  Future<void> refreshQuery({bool preserveVisibleItems});
  Future<void> persistTasksFilter();
  Future<void> persistEntryTypes();

  void setFilters(Set<DisplayFilter> filters) {
    _filters = filters;
    refreshQuery();
  }

  /// Applies all filter changes at once with a single persist/refresh cycle.
  ///
  /// Use this when multiple filter fields change simultaneously (e.g. from
  /// the filter sheet "Apply" button) to avoid intermediate query refreshes.
  ///
  /// The caller manages the project/category relationship and provides both
  /// fields when category-scoped projects need to be cleared.
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

  void setSearchMode(SearchMode mode) {
    _hasExplicitSearchModeSelection = true;
    _searchMode = _enableVectorSearch ? mode : SearchMode.fullText;
    refreshQuery();
  }
}
