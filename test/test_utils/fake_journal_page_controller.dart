import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';

/// Shared fake controller for testing widgets that depend on JournalPageController.
///
/// Tracks method calls for verification and allows state updates for testing
/// state-dependent UI changes.
///
/// Usage:
/// ```dart
/// final fakeController = FakeJournalPageController(initialState);
/// // ... pump widget with provider override ...
/// expect(fakeController.toggledCategoryIds, contains('cat1'));
/// ```
class FakeJournalPageController extends JournalPageController {
  FakeJournalPageController(this._initialState);

  final JournalPageState _initialState;

  // Tracking for verification
  final List<String> toggledCategoryIds = [];
  final List<String> toggledLabelIds = [];
  final List<String> toggledTaskStatuses = [];
  final List<String> toggledPriorities = [];
  final List<String> toggledEntryTypes = [];
  final List<String> singleEntryTypeCalls = [];
  final List<String> singleTaskStatusCalls = [];
  final List<TaskSortOption> sortOptionCalls = [];
  final List<bool> showCreationDateCalls = [];
  final List<bool> showDueDateCalls = [];
  final List<Set<DisplayFilter>> filtersCalls = [];
  final List<String> searchStringCalls = [];
  final List<SearchMode> searchModeCalls = [];
  final List<AgentAssignmentFilter> agentAssignmentFilterCalls = [];
  final List<String> toggledProjectIds = [];

  int selectAllCategoriesCalled = 0;
  int clearSelectedLabelIdsCalled = 0;
  int clearSelectedTaskStatusesCalled = 0;
  int selectAllTaskStatusesCalled = 0;
  int clearSelectedPrioritiesCalled = 0;
  int selectAllEntryTypesCalled = 0;
  List<String>? selectAllEntryTypesParam;
  int clearSelectedEntryTypesCalled = 0;
  int clearProjectFilterCalled = 0;
  int refreshQueryCalled = 0;

  @override
  JournalPageState build(bool showTasks) => _initialState;

  @override
  JournalPageState get state => _initialState;

  /// Update state for testing - this updates Riverpod's internal state
  // ignore: use_setters_to_change_properties
  void updateState(JournalPageState newState) => state = newState;

  // Batch setter tracking
  final List<Set<String>> setSelectedTaskStatusesCalls = [];
  final List<Set<String>> setSelectedCategoryIdsCalls = [];
  final List<Set<String>> setSelectedLabelIdsCalls = [];
  final List<Set<String>> setSelectedProjectIdsCalls = [];
  final List<Set<String>> setSelectedPrioritiesCalls = [];
  int applyBatchFilterUpdateCalled = 0;

  // Category methods
  @override
  Future<void> setSelectedTaskStatuses(Set<String> statuses) async {
    setSelectedTaskStatusesCalls.add(statuses);
  }

  @override
  Future<void> setSelectedCategoryIds(Set<String> categoryIds) async {
    setSelectedCategoryIdsCalls.add(categoryIds);
  }

  @override
  Future<void> setSelectedLabelIds(Set<String> labelIds) async {
    setSelectedLabelIdsCalls.add(labelIds);
  }

  @override
  Future<void> setSelectedProjectIds(Set<String> projectIds) async {
    setSelectedProjectIdsCalls.add(projectIds);
  }

  @override
  Future<void> setSelectedPriorities(Set<String> priorities) async {
    setSelectedPrioritiesCalls.add(priorities);
  }

  @override
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
    applyBatchFilterUpdateCalled++;
    if (statuses != null) setSelectedTaskStatusesCalls.add(statuses);
    if (categoryIds != null) setSelectedCategoryIdsCalls.add(categoryIds);
    if (labelIds != null) setSelectedLabelIdsCalls.add(labelIds);
    if (projectIds != null) setSelectedProjectIdsCalls.add(projectIds);
    if (priorities != null) setSelectedPrioritiesCalls.add(priorities);
    if (sortOption != null) sortOptionCalls.add(sortOption);
    if (agentAssignmentFilter != null) {
      agentAssignmentFilterCalls.add(agentAssignmentFilter);
    }
    if (searchMode != null) searchModeCalls.add(searchMode);
    if (showCreationDate != null) showCreationDateCalls.add(showCreationDate);
    if (showDueDate != null) showDueDateCalls.add(showDueDate);
  }

  @override
  Future<void> toggleSelectedCategoryIds(String categoryId) async {
    toggledCategoryIds.add(categoryId);
  }

  @override
  Future<void> selectedAllCategories() async {
    selectAllCategoriesCalled++;
  }

  // Label methods
  @override
  Future<void> toggleSelectedLabelId(String labelId) async {
    toggledLabelIds.add(labelId);
  }

  @override
  Future<void> clearSelectedLabelIds() async {
    clearSelectedLabelIdsCalled++;
  }

  // Task status methods
  @override
  Future<void> toggleSelectedTaskStatus(String status) async {
    toggledTaskStatuses.add(status);
  }

  @override
  Future<void> selectSingleTaskStatus(String taskStatus) async {
    singleTaskStatusCalls.add(taskStatus);
  }

  @override
  Future<void> selectAllTaskStatuses() async {
    selectAllTaskStatusesCalled++;
  }

  @override
  Future<void> clearSelectedTaskStatuses() async {
    clearSelectedTaskStatusesCalled++;
  }

  // Priority methods
  @override
  Future<void> toggleSelectedPriority(String priority) async {
    toggledPriorities.add(priority);
  }

  @override
  Future<void> clearSelectedPriorities() async {
    clearSelectedPrioritiesCalled++;
  }

  // Sort and display methods
  @override
  Future<void> setSortOption(TaskSortOption sortOption) async {
    sortOptionCalls.add(sortOption);
  }

  @override
  Future<void> setShowCreationDate({required bool show}) async {
    showCreationDateCalls.add(show);
  }

  @override
  Future<void> setShowDueDate({required bool show}) async {
    showDueDateCalls.add(show);
  }

  // Agent assignment filter
  @override
  Future<void> setAgentAssignmentFilter(AgentAssignmentFilter filter) async {
    agentAssignmentFilterCalls.add(filter);
  }

  // Project filter methods
  @override
  Future<void> toggleProjectFilter(String projectId) async {
    toggledProjectIds.add(projectId);
  }

  @override
  Future<void> clearProjectFilter() async {
    clearProjectFilterCalled++;
  }

  // Filter methods
  @override
  void setFilters(Set<DisplayFilter> filters) {
    filtersCalls.add(filters);
  }

  // Entry type methods
  @override
  void toggleSelectedEntryTypes(String entryType) {
    toggledEntryTypes.add(entryType);
  }

  @override
  void selectSingleEntryType(String entryType) {
    singleEntryTypeCalls.add(entryType);
  }

  @override
  void selectAllEntryTypes([List<String>? types]) {
    selectAllEntryTypesCalled++;
    selectAllEntryTypesParam = types;
  }

  @override
  void clearSelectedEntryTypes() {
    clearSelectedEntryTypesCalled++;
  }

  // Search methods
  @override
  void setSearchMode(SearchMode mode) {
    searchModeCalls.add(mode);
  }

  @override
  Future<void> setSearchString(String query) async {
    searchStringCalls.add(query);
  }

  /// Captures the `preserveVisibleItems` flag passed to each
  /// [refreshQuery] call, so tests can assert the flicker-safe variant
  /// is used by callers like pull-to-refresh / filter-toggle flows.
  final List<bool> refreshQueryPreserveFlags = <bool>[];

  @override
  Future<void> refreshQuery({bool preserveVisibleItems = false}) async {
    refreshQueryCalled++;
    refreshQueryPreserveFlags.add(preserveVisibleItems);
  }

  /// Resets all tracking counters and lists for fresh test assertions
  void resetTracking() {
    setSelectedTaskStatusesCalls.clear();
    setSelectedCategoryIdsCalls.clear();
    setSelectedLabelIdsCalls.clear();
    setSelectedProjectIdsCalls.clear();
    setSelectedPrioritiesCalls.clear();
    toggledCategoryIds.clear();
    toggledLabelIds.clear();
    toggledTaskStatuses.clear();
    toggledPriorities.clear();
    toggledEntryTypes.clear();
    singleEntryTypeCalls.clear();
    singleTaskStatusCalls.clear();
    sortOptionCalls.clear();
    showCreationDateCalls.clear();
    showDueDateCalls.clear();
    filtersCalls.clear();
    searchStringCalls.clear();
    searchModeCalls.clear();
    agentAssignmentFilterCalls.clear();
    toggledProjectIds.clear();
    selectAllCategoriesCalled = 0;
    clearSelectedLabelIdsCalled = 0;
    clearSelectedTaskStatusesCalled = 0;
    selectAllTaskStatusesCalled = 0;
    clearSelectedPrioritiesCalled = 0;
    selectAllEntryTypesCalled = 0;
    selectAllEntryTypesParam = null;
    clearSelectedEntryTypesCalled = 0;
    clearProjectFilterCalled = 0;
    refreshQueryCalled = 0;
    refreshQueryPreserveFlags.clear();
    applyBatchFilterUpdateCalled = 0;
  }
}
