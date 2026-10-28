import 'package:clock/clock.dart';
import 'package:lotti/classes/journal_page_state.dart';
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/tasks/util/due_date_utils.dart';
import 'package:lotti/services/entities_cache_service.dart';

/// Computes the number of tasks matching a [TasksFilter].
///
/// In the common case (no project / agent / due filters) the answer is a
/// single `COUNT(*)` SQL query via `JournalDb.getFilteredTasksCount`. When
/// project, agent or due post-filters are active — predicates that live
/// outside the journal table's filter columns — we instead fetch a task-id
/// list at the same predicate set and intersect with the post-filter id sets.
/// The due set comes from `JournalDb.getOpenTaskIdsForDueFilter`, the same
/// read the list narrows by. The intersection mirrors the
/// post-filter loop in `JournalQueryRunner._runPostFilteredTaskQuery`, so
/// the count agrees with what the live task list shows.
class SavedTaskFilterCountRepository {
  SavedTaskFilterCountRepository({
    required this._db,
    required this._cache,
    required this._agentRepository,
  });

  final JournalDb _db;
  final EntitiesCacheService _cache;
  final AgentRepository _agentRepository;

  Future<int> count(TasksFilter filter) async {
    if (filter.selectedTaskStatuses.isEmpty) return 0;

    // Empty category selection means "all categories" plus the empty-string
    // sentinel — same expansion `_runTaskQuery` performs.
    final List<String> categoryIds;
    if (filter.selectedCategoryIds.isEmpty) {
      categoryIds = [
        ..._cache.sortedCategories.map((e) => e.id),
        '',
      ];
    } else {
      categoryIds = filter.selectedCategoryIds.toList();
    }
    // Note: categoryIds can never be empty here — the expansion branch
    // always appends the empty-string sentinel, and the explicit branch is
    // guarded by selectedCategoryIds.isNotEmpty.

    final taskStatuses = filter.selectedTaskStatuses.toList();
    final labelIds = filter.selectedLabelIds.toList();
    final priorities = filter.selectedPriorities.toList();
    final hasProjectFilter = filter.selectedProjectIds.isNotEmpty;
    final hasAgentFilter =
        filter.agentAssignmentFilter != AgentAssignmentFilter.all;
    final dueTaskIds = filter.dueFilter == TaskDueFilter.all
        ? null
        : await _db.getOpenTaskIdsForDueFilter(
            filter.dueFilter,
            now: clock.now(),
          );
    // Nothing open is due in the window, so nothing can match — skip the
    // id-list fetch entirely. This is the common case for an urgency probe.
    if (dueTaskIds != null && dueTaskIds.isEmpty) return 0;

    if (!hasProjectFilter && !hasAgentFilter && dueTaskIds == null) {
      return _db.getFilteredTasksCount(
        taskStatuses: taskStatuses,
        categoryIds: categoryIds,
        labelIds: labelIds,
        priorities: priorities,
      );
    }

    // Run the id-list query in parallel with the post-filter id-set fetches —
    // they're independent.
    final results = await Future.wait<Object>([
      _db.getFilteredTaskIds(
        taskStatuses: taskStatuses,
        categoryIds: categoryIds,
        labelIds: labelIds,
        priorities: priorities,
      ),
      if (hasProjectFilter)
        _db.getTaskIdsForProjects(filter.selectedProjectIds),
      if (hasAgentFilter) _agentRepository.getTaskIdsWithAgentLink(),
    ]);

    final taskIds = results[0] as List<String>;
    var idx = 1;
    final projectTaskIds = hasProjectFilter
        ? results[idx++] as Set<String>
        : null;
    final agentLinkedIds = hasAgentFilter
        ? results[idx++] as Set<String>
        : null;

    var matched = 0;
    for (final id in taskIds) {
      if (dueTaskIds != null && !dueTaskIds.contains(id)) continue;
      if (projectTaskIds != null && !projectTaskIds.contains(id)) continue;
      if (agentLinkedIds != null) {
        final hasLink = agentLinkedIds.contains(id);
        final pass =
            filter.agentAssignmentFilter == AgentAssignmentFilter.hasAgent
            ? hasLink
            : !hasLink;
        if (!pass) continue;
      }
      matched++;
    }
    return matched;
  }

  /// The most urgent due state among the open tasks [filter] matches:
  /// [DueDateUrgency.overdue] when any is overdue, else
  /// [DueDateUrgency.dueToday] when any is due today, else
  /// [DueDateUrgency.normal].
  ///
  /// Honours the filter's own due clause — a saved "Due today" view never
  /// reads as overdue, since it cannot contain an overdue task — and only
  /// probes the second window when the first finds nothing.
  Future<DueDateUrgency> dueUrgency(TasksFilter filter) async {
    if (filter.dueFilter != TaskDueFilter.dueToday &&
        await count(filter.copyWith(dueFilter: TaskDueFilter.overdue)) > 0) {
      return DueDateUrgency.overdue;
    }
    if (filter.dueFilter != TaskDueFilter.overdue &&
        await count(filter.copyWith(dueFilter: TaskDueFilter.dueToday)) > 0) {
      return DueDateUrgency.dueToday;
    }
    return DueDateUrgency.normal;
  }
}
