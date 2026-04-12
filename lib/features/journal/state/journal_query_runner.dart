import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/ai/repository/vector_search_repository.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/journal/utils/entry_type_gating.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/services/entities_cache_service.dart';

/// Bundles all filter/search state needed to execute a single query.
class JournalQueryParams {
  const JournalQueryParams({
    required this.showTasks,
    required this.selectedEntryTypes,
    required this.selectedCategoryIds,
    required this.selectedProjectIds,
    required this.selectedLabelIds,
    required this.selectedPriorities,
    required this.selectedTaskStatuses,
    required this.sortOption,
    required this.agentAssignmentFilter,
    required this.filters,
    required this.query,
    required this.enableVectorSearch,
    required this.searchMode,
    required this.enableEvents,
    required this.enableHabits,
    required this.enableDashboards,
  });

  final bool showTasks;
  final Set<String> selectedEntryTypes;
  final Set<String> selectedCategoryIds;
  final Set<String> selectedProjectIds;
  final Set<String> selectedLabelIds;
  final Set<String> selectedPriorities;
  final Set<String> selectedTaskStatuses;
  final TaskSortOption sortOption;
  final AgentAssignmentFilter agentAssignmentFilter;
  final Set<DisplayFilter> filters;
  final String query;
  final bool enableVectorSearch;
  final SearchMode searchMode;
  final bool enableEvents;
  final bool enableHabits;
  final bool enableDashboards;
}

/// Result of a vector search, wrapping entity results with timing telemetry.
class JournalVectorSearchResult {
  const JournalVectorSearchResult({
    required this.entities,
    required this.elapsed,
    required this.distances,
  });

  final List<JournalEntity> entities;
  final Duration elapsed;
  final Map<String, double> distances;
}

/// Executes queries against the journal/task databases, including full-text
/// search, vector search, post-filtering, and sorting.
class JournalQueryRunner {
  JournalQueryRunner({
    required JournalDb db,
    required Fts5Db fts5Db,
    required EntitiesCacheService entitiesCacheService,
  }) : _db = db,
       _fts5Db = fts5Db,
       _entitiesCacheService = entitiesCacheService;

  final JournalDb _db;
  final Fts5Db _fts5Db;
  final EntitiesCacheService _entitiesCacheService;

  /// Page size used for database pagination.
  static const pageSize = 50;

  // Cached per-refresh to avoid repeated DB hits during pagination.
  Set<String>? _cachedAgentLinkedIds;

  /// Clears internal caches. Call at the start of each refresh cycle.
  void clearCache() {
    _cachedAgentLinkedIds = null;
  }

  // ---------------------------------------------------------------
  // Full-text search
  // ---------------------------------------------------------------

  /// Returns the set of IDs matching [query] via FTS5, or empty for blank query.
  Future<Set<String>> fts5Search(String query) async {
    if (query.isEmpty) return {};
    final res = await _fts5Db.watchFullTextMatches(query).first;
    return res.toSet();
  }

  // ---------------------------------------------------------------
  // Main query
  // ---------------------------------------------------------------

  /// Runs a paginated query using the filter state in [params].
  ///
  /// [fullTextMatches] are the IDs from a prior FTS5 search (pass empty set
  /// when the query is blank).
  ///
  /// [setPostFilterNextRawOffset] is called when post-filters (project /
  /// agent) consume more raw rows than they return, so the caller can track
  /// the correct raw offset for the next page.
  Future<List<JournalEntity>> runQuery(
    JournalQueryParams params,
    int pageKey, {
    required Set<String> fullTextMatches,
    void Function(int? nextRawOffset)? setPostFilterNextRawOffset,
  }) async {
    // Intersect selected types with allowed based on feature flags.
    final allowed = computeAllowedEntryTypes(
      events: params.enableEvents,
      habits: params.enableHabits,
      dashboards: params.enableDashboards,
    );
    final types = params.selectedEntryTypes.where(allowed.contains).toList();
    final ids = params.query.isNotEmpty ? fullTextMatches.toList() : null;

    final starredEntriesOnly = params.filters.contains(
      DisplayFilter.starredEntriesOnly,
    );
    final privateEntriesOnly = params.filters.contains(
      DisplayFilter.privateEntriesOnly,
    );
    final flaggedEntriesOnly = params.filters.contains(
      DisplayFilter.flaggedEntriesOnly,
    );

    if (params.showTasks) {
      return _runTaskQuery(
        params,
        pageKey,
        ids: ids,
        starredEntriesOnly: starredEntriesOnly,
        setPostFilterNextRawOffset: setPostFilterNextRawOffset,
      );
    }

    return _db.getJournalEntities(
      types: types,
      ids: ids,
      starredStatuses: starredEntriesOnly ? [true] : [true, false],
      privateStatuses: privateEntriesOnly ? [true] : [true, false],
      flaggedStatuses: flaggedEntriesOnly ? [1] : [1, 0],
      categoryIds: params.selectedCategoryIds.isNotEmpty
          ? params.selectedCategoryIds
          : null,
      limit: pageSize,
      offset: pageKey,
    );
  }

  // ---------------------------------------------------------------
  // Task-specific query
  // ---------------------------------------------------------------

  Future<List<JournalEntity>> _runTaskQuery(
    JournalQueryParams params,
    int pageKey, {
    required List<String>? ids,
    required bool starredEntriesOnly,
    void Function(int? nextRawOffset)? setPostFilterNextRawOffset,
  }) async {
    final allCategoryIds = _entitiesCacheService.sortedCategories
        .map((e) => e.id)
        .toSet();

    Set<String> categoryIds;
    if (params.selectedCategoryIds.isEmpty) {
      categoryIds = allCategoryIds.isEmpty ? {''} : allCategoryIds;
    } else {
      categoryIds = params.selectedCategoryIds;
    }

    final sortByDateInDb =
        params.sortOption == TaskSortOption.byDate ||
        params.sortOption == TaskSortOption.byDueDate;

    final agentFilterActive =
        params.agentAssignmentFilter != AgentAssignmentFilter.all;
    final projectFilterActive = params.selectedProjectIds.isNotEmpty;
    final needsPostFilter = agentFilterActive || projectFilterActive;

    if (!needsPostFilter) {
      setPostFilterNextRawOffset?.call(null);
      final res = await _db.getTasks(
        ids: ids,
        starredStatuses: starredEntriesOnly ? [true] : [true, false],
        taskStatuses: params.selectedTaskStatuses.toList(),
        categoryIds: categoryIds.toList(),
        labelIds: params.selectedLabelIds.toList(),
        priorities: params.selectedPriorities.toList(),
        sortByDate: sortByDateInDb,
        limit: pageSize,
        offset: pageKey,
      );
      if (params.sortOption == TaskSortOption.byDueDate) {
        return sortByDueDate(res);
      }
      return res;
    }

    return _runPostFilteredTaskQuery(
      params,
      pageKey,
      ids: ids,
      categoryIds: categoryIds,
      starredEntriesOnly: starredEntriesOnly,
      sortByDateInDb: sortByDateInDb,
      agentFilterActive: agentFilterActive,
      projectFilterActive: projectFilterActive,
      setPostFilterNextRawOffset: setPostFilterNextRawOffset,
    );
  }

  Future<List<JournalEntity>> _runPostFilteredTaskQuery(
    JournalQueryParams params,
    int pageKey, {
    required List<String>? ids,
    required Set<String> categoryIds,
    required bool starredEntriesOnly,
    required bool sortByDateInDb,
    required bool agentFilterActive,
    required bool projectFilterActive,
    void Function(int? nextRawOffset)? setPostFilterNextRawOffset,
  }) async {
    // Pre-fetch filter sets so the loop doesn't re-query each iteration.
    final projectTaskIds = projectFilterActive
        ? await _db.getTaskIdsForProjects(params.selectedProjectIds)
        : null;
    final agentLinkedIds = agentFilterActive
        ? await getAgentLinkedTaskIds()
        : null;

    final filtered = <JournalEntity>[];
    var currentOffset = pageKey;
    const fetchChunk = pageSize;

    var pageFilled = false;
    while (!pageFilled && filtered.length < pageSize) {
      final raw = await _db.getTasks(
        ids: ids,
        starredStatuses: starredEntriesOnly ? [true] : [true, false],
        taskStatuses: params.selectedTaskStatuses.toList(),
        categoryIds: categoryIds.toList(),
        labelIds: params.selectedLabelIds.toList(),
        priorities: params.selectedPriorities.toList(),
        sortByDate: sortByDateInDb,
        limit: fetchChunk,
        offset: currentOffset,
      );

      var consumedInChunk = 0;
      for (final entity in raw) {
        consumedInChunk++;
        var keep = true;
        if (projectTaskIds != null &&
            !projectTaskIds.contains(entity.meta.id)) {
          keep = false;
        }
        if (keep && agentLinkedIds != null) {
          final hasLink = agentLinkedIds.contains(entity.meta.id);
          keep = params.agentAssignmentFilter == AgentAssignmentFilter.hasAgent
              ? hasLink
              : !hasLink;
        }
        if (keep) filtered.add(entity);
        if (filtered.length == pageSize) {
          currentOffset += consumedInChunk;
          pageFilled = true;
          break;
        }
      }

      if (!pageFilled) {
        currentOffset += raw.length;
      }
      if (raw.length < fetchChunk) break;
    }

    setPostFilterNextRawOffset?.call(currentOffset);

    if (params.sortOption == TaskSortOption.byDueDate) {
      return sortByDueDate(filtered).take(pageSize).toList();
    }
    return filtered.take(pageSize).toList();
  }

  // ---------------------------------------------------------------
  // Vector search
  // ---------------------------------------------------------------

  /// Executes a vector search and returns results with telemetry.
  Future<JournalVectorSearchResult> runVectorSearch(
    JournalQueryParams params,
  ) async {
    if (!getIt.isRegistered<VectorSearchRepository>()) {
      DevLogger.warning(
        name: 'JournalQueryRunner',
        message:
            'VectorSearchRepository not registered — '
            'is the embedding pipeline available?',
      );
      return const JournalVectorSearchResult(
        entities: [],
        elapsed: Duration.zero,
        distances: {},
      );
    }

    try {
      final repo = getIt<VectorSearchRepository>();
      final categoryIds = params.selectedCategoryIds.isNotEmpty
          ? params.selectedCategoryIds
          : null;

      final result = params.showTasks
          ? await repo.searchRelatedTasks(
              query: params.query,
              categoryIds: categoryIds,
            )
          : await repo.searchRelatedEntries(
              query: params.query,
              categoryIds: categoryIds,
            );

      return JournalVectorSearchResult(
        entities: result.entities,
        elapsed: result.elapsed,
        distances: result.distances,
      );
    } on Exception catch (e) {
      DevLogger.warning(
        name: 'JournalQueryRunner',
        message: 'Vector search failed: $e',
      );
      return const JournalVectorSearchResult(
        entities: [],
        elapsed: Duration.zero,
        distances: {},
      );
    }
  }

  // ---------------------------------------------------------------
  // Agent linked IDs
  // ---------------------------------------------------------------

  /// Fetches the set of task IDs that have an agent_task link.
  /// Cached per refresh cycle — call [clearCache] to reset.
  Future<Set<String>> getAgentLinkedTaskIds() async {
    if (_cachedAgentLinkedIds != null) return _cachedAgentLinkedIds!;
    final repo = AgentRepository(getIt<AgentDatabase>());
    final ids = await repo.getTaskIdsWithAgentLink();
    _cachedAgentLinkedIds = ids;
    return ids;
  }

  // ---------------------------------------------------------------
  // Sorting
  // ---------------------------------------------------------------

  /// Sorts tasks by due date (soonest first, tasks without due dates at end).
  /// Preserves creation date order for tasks with the same due date or no
  /// due date.
  static List<JournalEntity> sortByDueDate(List<JournalEntity> entities) {
    return List<JournalEntity>.from(entities)..sort((a, b) {
      final dueA = a is Task ? a.data.due : null;
      final dueB = b is Task ? b.data.due : null;

      final aHasDue = dueA != null;
      final bHasDue = dueB != null;

      if (aHasDue && bHasDue) {
        final comparison = dueA.compareTo(dueB);
        if (comparison != 0) return comparison;
      } else if (aHasDue) {
        return -1;
      } else if (bHasDue) {
        return 1;
      }

      return b.meta.dateFrom.compareTo(a.meta.dateFrom);
    });
  }
}
