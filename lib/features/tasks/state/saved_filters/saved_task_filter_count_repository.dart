import 'package:clock/clock.dart';
import 'package:lotti/classes/journal_page_state.dart';
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/tasks/state/task_due_view_counts.dart';
import 'package:lotti/features/tasks/util/due_date_utils.dart';
import 'package:lotti/services/entities_cache_service.dart';

/// Counts the tasks a [TasksFilter] matches, and answers the due-date
/// questions the smart views and the saved-filter markers ask of it.
///
/// In the common case (no project / agent / due / search clause) a count is a
/// single `COUNT(*)` SQL query via `JournalDb.getFilteredTasksCount`. Any
/// clause that lives outside the journal table's filter columns moves it to
/// [_matchingIds] — the filter's task-id list intersected with the post-filter
/// id sets, mirroring the loop in `JournalQueryRunner._runPostFilteredTaskQuery`
/// so the count agrees with what the live task list shows.
///
/// Query budget for the due-date reads, which run on every task change:
///
/// | Call | Queries |
/// |------|---------|
/// | [dueViewCounts] | 1 due-window read + 1 id list |
/// | [dueUrgencies] over N filters | 1 due-window read + N id lists (+ 1 agent-link read, shared) |
///
/// Both skip the id lists entirely when nothing open is due by tonight.
class SavedTaskFilterCountRepository {
  SavedTaskFilterCountRepository({
    required this._db,
    required this._cache,
    required this._agentRepository,
  });

  final JournalDb _db;
  final EntitiesCacheService _cache;
  final AgentRepository _agentRepository;

  /// [restrictToIds], when given, admits only those task ids — the live
  /// search's matches, so a count can agree with a searched list.
  Future<int> count(TasksFilter filter, {Set<String>? restrictToIds}) async {
    if (filter.selectedTaskStatuses.isEmpty) return 0;
    if (restrictToIds != null && restrictToIds.isEmpty) return 0;

    final dueTaskIds = filter.dueFilter == TaskDueFilter.all
        ? null
        : await _db.getOpenTaskIdsForDueFilter(
            filter.dueFilter,
            now: clock.now(),
          );
    // Nothing open is due in the window, so nothing can match — skip the
    // id-list fetch entirely.
    if (dueTaskIds != null && dueTaskIds.isEmpty) return 0;

    final hasPostFilter =
        filter.selectedProjectIds.isNotEmpty ||
        filter.agentAssignmentFilter != AgentAssignmentFilter.all;
    if (!hasPostFilter && dueTaskIds == null && restrictToIds == null) {
      return _db.getFilteredTasksCount(
        taskStatuses: filter.selectedTaskStatuses.toList(),
        categoryIds: _categoryIds(filter),
        labelIds: filter.selectedLabelIds.toList(),
        priorities: filter.selectedPriorities.toList(),
      );
    }

    final ids = await _matchingIds(filter);
    return ids
        .where(
          (id) =>
              (dueTaskIds == null || dueTaskIds.contains(id)) &&
              (restrictToIds == null || restrictToIds.contains(id)),
        )
        .length;
  }

  /// How many open tasks [filter] matches in each smart view, from one
  /// due-window read and one id list. The filter's own due clause is ignored:
  /// each view swaps in its own. [restrictToIds] narrows both to a search.
  Future<TaskDueViewCounts> dueViewCounts(
    TasksFilter filter, {
    Set<String>? restrictToIds,
  }) async {
    if (filter.selectedTaskStatuses.isEmpty) return TaskDueViewCounts.zero;
    if (restrictToIds != null && restrictToIds.isEmpty) {
      return TaskDueViewCounts.zero;
    }
    final windows = await _db.getOpenTaskIdsByDueWindow(now: clock.now());
    if (windows.overdue.isEmpty && windows.dueToday.isEmpty) {
      return TaskDueViewCounts.zero;
    }

    var overdue = 0;
    var dueToday = 0;
    for (final id in await _matchingIds(filter)) {
      if (restrictToIds != null && !restrictToIds.contains(id)) continue;
      if (windows.overdue.contains(id)) {
        overdue++;
      } else if (windows.dueToday.contains(id)) {
        dueToday++;
      }
    }
    return TaskDueViewCounts(overdue: overdue, dueToday: dueToday);
  }

  /// The most urgent due state among the open tasks each of [filters]
  /// matches, in order: [DueDateUrgency.overdue] when any is overdue, else
  /// [DueDateUrgency.dueToday] when any is due today, else
  /// [DueDateUrgency.normal].
  ///
  /// Honours each filter's own due clause — a saved "Due today" view never
  /// reads as overdue, since it cannot contain an overdue task. One
  /// due-window read serves every filter, and each filter's id list is
  /// fetched once and checked against both windows.
  Future<List<DueDateUrgency>> dueUrgencies(List<TasksFilter> filters) async {
    if (filters.isEmpty) return const [];
    final windows = await _db.getOpenTaskIdsByDueWindow(now: clock.now());
    if (windows.overdue.isEmpty && windows.dueToday.isEmpty) {
      return List.filled(filters.length, DueDateUrgency.normal);
    }

    // The agent-link set is the same for every filter: read it once.
    final agentLinkedIds =
        filters.any((f) => f.agentAssignmentFilter != AgentAssignmentFilter.all)
        ? await _agentRepository.getTaskIdsWithAgentLink()
        : null;

    Future<DueDateUrgency> urgencyOf(TasksFilter filter) async {
      final checkOverdue =
          filter.dueFilter != TaskDueFilter.dueToday &&
          windows.overdue.isNotEmpty;
      final checkToday =
          filter.dueFilter != TaskDueFilter.overdue &&
          windows.dueToday.isNotEmpty;
      if (filter.selectedTaskStatuses.isEmpty ||
          (!checkOverdue && !checkToday)) {
        return DueDateUrgency.normal;
      }
      final ids = await _matchingIds(filter, agentLinkedIds: agentLinkedIds);
      var hasToday = false;
      for (final id in ids) {
        if (checkOverdue && windows.overdue.contains(id)) {
          return DueDateUrgency.overdue;
        }
        if (checkToday && windows.dueToday.contains(id)) hasToday = true;
      }
      return hasToday ? DueDateUrgency.dueToday : DueDateUrgency.normal;
    }

    return Future.wait(filters.map(urgencyOf));
  }

  /// The ids of the tasks [filter] matches on every clause except its due
  /// clause and any search: the journal-table predicates, then the project
  /// and agent post-filters. [agentLinkedIds] lets a batch share one read.
  Future<Iterable<String>> _matchingIds(
    TasksFilter filter, {
    Set<String>? agentLinkedIds,
  }) async {
    final hasProjectFilter = filter.selectedProjectIds.isNotEmpty;
    final hasAgentFilter =
        filter.agentAssignmentFilter != AgentAssignmentFilter.all;

    // The id list runs in parallel with the post-filter id-set fetches —
    // they're independent.
    final results = await Future.wait<Object>([
      _db.getFilteredTaskIds(
        taskStatuses: filter.selectedTaskStatuses.toList(),
        categoryIds: _categoryIds(filter),
        labelIds: filter.selectedLabelIds.toList(),
        priorities: filter.selectedPriorities.toList(),
      ),
      if (hasProjectFilter)
        _db.getTaskIdsForProjects(filter.selectedProjectIds),
      if (hasAgentFilter && agentLinkedIds == null)
        _agentRepository.getTaskIdsWithAgentLink(),
    ]);

    final taskIds = results[0] as List<String>;
    var idx = 1;
    final projectTaskIds = hasProjectFilter
        ? results[idx++] as Set<String>
        : null;
    final agentIds = hasAgentFilter
        ? agentLinkedIds ?? results[idx++] as Set<String>
        : null;

    return taskIds.where((id) {
      if (projectTaskIds != null && !projectTaskIds.contains(id)) {
        return false;
      }
      if (agentIds != null) {
        final hasLink = agentIds.contains(id);
        return filter.agentAssignmentFilter == AgentAssignmentFilter.hasAgent
            ? hasLink
            : !hasLink;
      }
      return true;
    });
  }

  /// Empty category selection means "all categories" plus the empty-string
  /// sentinel — the same expansion `_runTaskQuery` performs, so the result is
  /// never empty.
  List<String> _categoryIds(TasksFilter filter) =>
      filter.selectedCategoryIds.isEmpty
      ? [..._cache.sortedCategories.map((e) => e.id), '']
      : filter.selectedCategoryIds.toList();
}
