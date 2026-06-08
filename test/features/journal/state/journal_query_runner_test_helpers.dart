import 'package:glados/glados.dart' as glados;
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

/// A generated mix of tasks with and without due dates, with deliberately
/// colliding due dates and varied dateFrom values so every branch of the
/// sortByDueDate comparator (due vs due, due vs none, tie-breaks) is hit.
class DueDateSortScenario {
  DueDateSortScenario({
    required int withDueCount,
    required int withoutDueCount,
    required int seed,
  }) : tasks = [
         for (var i = 0; i < withDueCount; i++)
           hMakeTask(
             id: 'due-$i',
             createdAt: DateTime(2024, 3, 1 + (seed * 7 + i) % 28),
             // % 5 keeps the due-date pool small so ties are frequent.
             due: DateTime(2024, 6, 1 + (seed + i * 3) % 5),
           ),
         for (var i = 0; i < withoutDueCount; i++)
           hMakeTask(
             id: 'free-$i',
             createdAt: DateTime(2024, 4, 1 + (seed * 5 + i) % 28),
           ),
       ] {
    // Deterministic interleave so the input order is not pre-sorted.
    if (seed.isOdd) {
      tasks = tasks.reversed.toList();
    }
  }

  List<Task> tasks;

  @override
  String toString() =>
      'DueDateSortScenario(${tasks.map((t) => '${t.meta.id}@'
          '${t.data.due}').join(', ')})';
}

extension AnyDueDateSortScenario on glados.Any {
  glados.Generator<DueDateSortScenario> get dueDateSortScenario => combine3(
    intInRange(0, 7),
    intInRange(0, 7),
    intInRange(0, 1000),
    (int withDue, int withoutDue, int seed) => DueDateSortScenario(
      withDueCount: withDue,
      withoutDueCount: withoutDue,
      seed: seed,
    ),
  );
}
