import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/services/entities_cache_service.dart';

/// Computes the number of tasks matching a [TasksFilter].
///
/// In the common case (no project / agent filters) the answer is a single
/// `COUNT(*)` SQL query via `JournalDb.getFilteredTasksCount`. When project
/// or agent post-filters are active — predicates that live outside the
/// journal table — we instead fetch a task-id list at the same predicate set
/// and intersect with the post-filter id sets. The intersection mirrors the
/// post-filter loop in `JournalQueryRunner._runPostFilteredTaskQuery`, so
/// the count agrees with what the live task list shows.
class SavedTaskFilterCountRepository {
  SavedTaskFilterCountRepository({
    required JournalDb db,
    required EntitiesCacheService cache,
    required AgentRepository agentRepository,
  }) : _db = db,
       _cache = cache,
       _agentRepository = agentRepository;

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
    if (categoryIds.isEmpty) return 0;

    final taskStatuses = filter.selectedTaskStatuses.toList();
    final labelIds = filter.selectedLabelIds.toList();
    final priorities = filter.selectedPriorities.toList();
    final hasProjectFilter = filter.selectedProjectIds.isNotEmpty;
    final hasAgentFilter =
        filter.agentAssignmentFilter != AgentAssignmentFilter.all;

    if (!hasProjectFilter && !hasAgentFilter) {
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
}
