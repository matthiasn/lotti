import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';

/// Computes the number of tasks matching a [TasksFilter].
///
/// Mirrors the in-DB filter pipeline used by `JournalQueryRunner._runTaskQuery`
/// — same status / category / label / priority predicates — and applies the
/// project and agent-assignment post-filters in Dart on top of the materialised
/// task list, so the count is consistent with what the user sees in the live
/// task list.
///
/// **Performance**: this fetches up to [maxFetch] task entities to count them.
/// For typical task corpora (hundreds, low thousands) the cost is acceptable
/// for sidebar polling. If a saved filter could plausibly match more than
/// [maxFetch] tasks the count is capped at that value — a follow-up can lift
/// the limit by promoting the count to a dedicated `COUNT(*)` SQL query.
class SavedTaskFilterCountRepository {
  SavedTaskFilterCountRepository({
    JournalDb? db,
    EntitiesCacheService? cache,
    AgentRepository? agentRepository,
    this.maxFetch = 5000,
  }) : _db = db ?? getIt<JournalDb>(),
       _cache = cache ?? getIt<EntitiesCacheService>(),
       _agentRepository =
           agentRepository ?? AgentRepository(getIt<AgentDatabase>());

  final JournalDb _db;
  final EntitiesCacheService _cache;
  final AgentRepository _agentRepository;

  /// Cap on the number of tasks materialised per count call.
  final int maxFetch;

  Future<int> count(TasksFilter filter) async {
    // Statuses: empty → no rows. Apply the same guard the query runner uses.
    final taskStatuses = filter.selectedTaskStatuses.toList();
    if (taskStatuses.isEmpty) return 0;

    // Categories: same expansion as `_runTaskQuery` — empty selection means
    // "all categories" plus the empty-string sentinel.
    final allCategoryIds = _cache.sortedCategories.map((e) => e.id).toSet();
    final categoryIds = filter.selectedCategoryIds.isEmpty
        ? <String>{...allCategoryIds, ''}.toList()
        : filter.selectedCategoryIds.toList();
    if (categoryIds.isEmpty) return 0;

    final entities = await _db.getTasks(
      starredStatuses: const [true, false],
      taskStatuses: taskStatuses,
      categoryIds: categoryIds,
      labelIds: filter.selectedLabelIds.toList(),
      priorities: filter.selectedPriorities.toList(),
      limit: maxFetch,
    );

    // Project post-filter.
    Set<String>? projectTaskIds;
    if (filter.selectedProjectIds.isNotEmpty) {
      projectTaskIds = await _db.getTaskIdsForProjects(
        filter.selectedProjectIds,
      );
    }

    // Agent post-filter.
    Set<String>? agentLinkedIds;
    if (filter.agentAssignmentFilter != AgentAssignmentFilter.all) {
      agentLinkedIds = await _agentRepository.getTaskIdsWithAgentLink();
    }

    if (projectTaskIds == null && agentLinkedIds == null) {
      return entities.length;
    }

    var matched = 0;
    for (final entity in entities) {
      if (entity is! Task) continue;
      final id = entity.meta.id;
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
