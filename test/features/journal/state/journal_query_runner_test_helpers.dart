import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/journal/state/journal_query_runner.dart';

final hTestDate = DateTime(2024, 3, 15);

Task hMakeTask({
  required String id,
  required DateTime createdAt,
  DateTime? due,
  String? categoryId,
}) {
  return Task(
    data: TaskData(
      status: TaskStatus.open(
        id: 'status-$id',
        createdAt: createdAt,
        utcOffset: 0,
      ),
      title: 'Task $id',
      statusHistory: const [],
      dateFrom: createdAt,
      dateTo: createdAt,
      due: due,
    ),
    meta: Metadata(
      id: id,
      createdAt: createdAt,
      dateFrom: createdAt,
      dateTo: createdAt,
      updatedAt: createdAt,
      categoryId: categoryId,
    ),
  );
}

JournalEntry hMakeEntry({
  required String id,
  required DateTime createdAt,
}) {
  return JournalEntry(
    entryText: EntryText(plainText: 'Entry $id', markdown: 'Entry $id'),
    meta: Metadata(
      id: id,
      createdAt: createdAt,
      dateFrom: createdAt,
      dateTo: createdAt,
      updatedAt: createdAt,
    ),
  );
}

JournalQueryParams hDefaultParams({
  bool showTasks = false,
  Set<String> selectedEntryTypes = const {},
  Set<String> selectedCategoryIds = const {},
  Set<String> selectedProjectIds = const {},
  Set<String> selectedLabelIds = const {},
  Set<String> selectedPriorities = const {},
  Set<String> selectedTaskStatuses = const {'OPEN', 'GROOMED', 'IN PROGRESS'},
  TaskSortOption sortOption = TaskSortOption.byPriority,
  AgentAssignmentFilter agentAssignmentFilter = AgentAssignmentFilter.all,
  Set<DisplayFilter> filters = const {},
  String query = '',
  bool enableVectorSearch = false,
  SearchMode searchMode = SearchMode.fullText,
  bool enableEvents = true,
  bool enableHabits = true,
  bool enableDashboards = true,
}) {
  return JournalQueryParams(
    showTasks: showTasks,
    selectedEntryTypes: selectedEntryTypes,
    selectedCategoryIds: selectedCategoryIds,
    selectedProjectIds: selectedProjectIds,
    selectedLabelIds: selectedLabelIds,
    selectedPriorities: selectedPriorities,
    selectedTaskStatuses: selectedTaskStatuses,
    sortOption: sortOption,
    agentAssignmentFilter: agentAssignmentFilter,
    filters: filters,
    query: query,
    enableVectorSearch: enableVectorSearch,
    searchMode: searchMode,
    enableEvents: enableEvents,
    enableHabits: enableHabits,
    enableDashboards: enableDashboards,
  );
}
