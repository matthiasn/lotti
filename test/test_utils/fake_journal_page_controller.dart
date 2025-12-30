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
  final List<TaskSortOption> sortOptionCalls = [];
  final List<bool> showCreationDateCalls = [];
  final List<Set<DisplayFilter>> filtersCalls = [];
  final List<String> searchStringCalls = [];

  int selectAllCategoriesCalled = 0;
  int clearSelectedLabelIdsCalled = 0;
  int clearSelectedTaskStatusesCalled = 0;
  int selectAllTaskStatusesCalled = 0;
  int clearSelectedPrioritiesCalled = 0;
  int selectAllEntryTypesCalled = 0;
  int clearSelectedEntryTypesCalled = 0;
  int refreshQueryCalled = 0;

  @override
  JournalPageState build(bool showTasks) => _initialState;

  /// Update state for testing - this updates Riverpod's internal state
  // ignore: use_setters_to_change_properties
  void updateState(JournalPageState newState) => state = newState;

  // Category methods
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
  }

  @override
  void clearSelectedEntryTypes() {
    clearSelectedEntryTypesCalled++;
  }

  // Search methods
  @override
  Future<void> setSearchString(String query) async {
    searchStringCalls.add(query);
  }

  @override
  Future<void> refreshQuery() async {
    refreshQueryCalled++;
  }

  /// Resets all tracking counters and lists for fresh test assertions
  void resetTracking() {
    toggledCategoryIds.clear();
    toggledLabelIds.clear();
    toggledTaskStatuses.clear();
    toggledPriorities.clear();
    toggledEntryTypes.clear();
    singleEntryTypeCalls.clear();
    sortOptionCalls.clear();
    showCreationDateCalls.clear();
    filtersCalls.clear();
    searchStringCalls.clear();
    selectAllCategoriesCalled = 0;
    clearSelectedLabelIdsCalled = 0;
    clearSelectedTaskStatusesCalled = 0;
    selectAllTaskStatusesCalled = 0;
    clearSelectedPrioritiesCalled = 0;
    selectAllEntryTypesCalled = 0;
    clearSelectedEntryTypesCalled = 0;
    refreshQueryCalled = 0;
  }
}
