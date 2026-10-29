import 'package:clock/clock.dart';
import 'package:lotti/classes/github/pull_request_ref.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/journal_page_state.dart';
import 'package:lotti/database/agents/agent_database.dart';
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/features/ai/repository/vector_search_repository.dart';
import 'package:lotti/features/journal/utils/entry_type_gating.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
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
    required this.enableRelationships,
    this.dueFilter = TaskDueFilter.all,
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

  /// The smart-view narrowing (Overdue / Due today); tasks only.
  final TaskDueFilter dueFilter;
  final String query;
  final bool enableVectorSearch;
  final SearchMode searchMode;
  final bool enableEvents;
  final bool enableHabits;
  final bool enableDashboards;
  final bool enableRelationships;
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
    required this._db,
    required this._fts5Db,
    required this._entitiesCacheService,
    required this._domainLogger,
  });

  final JournalDb _db;
  final DomainLogger _domainLogger;
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

  /// The tasks linked to the pull request a pasted link in the query of
  /// [params] names, or null when the query is not one ([pullRequestSearchRef]) or
  /// the page lists entries rather than tasks — then the query is searched
  /// as text.
  ///
  /// An exact lookup like semantic search, it returns every linked task in
  /// one page, newest first, and keeps the clauses that scope what may be
  /// shown — the category selection (and with it lockdown), the due view
  /// and private mode — but not the status selection: a merged pull
  /// request's task is usually done, and the default view hides done tasks.
  Future<List<JournalEntity>?> runPullRequestSearch(
    JournalQueryParams params,
  ) async {
    if (!params.showTasks) return null;
    final pullRequest = pullRequestSearchRef(params.query);
    if (pullRequest == null) return null;

    final holders = await _db.taskIdsHoldingPullRequest(pullRequest.key);
    final ids = await _narrowByDueFilter(holders.toList(), params.dueFilter);
    final categoryIds = params.selectedCategoryIds;
    final tasks = await _db.getJournalEntitiesForIds({...?ids});
    return [
      for (final task in tasks)
        if (task is Task &&
            (categoryIds.isEmpty ||
                categoryIds.contains(task.meta.categoryId ?? '')))
          task,
    ];
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
      relationships: params.enableRelationships,
    );
    // A check-in is a search result like any entry (ADR 0139, superseding
    // ADR 0064 decision 3): search runs on the device, only for its user,
    // and the `private` flag a check-in inherits from its person hides it
    // here as it hides it in the feed.
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
      final taskIds = await _narrowByDueFilter(ids, params.dueFilter);
      // An empty restriction matches nothing; the task queries read an empty
      // id list as "no rows" too, but saying so here skips the round trip.
      if (taskIds != null && taskIds.isEmpty) {
        setPostFilterNextRawOffset?.call(null);
        return const <JournalEntity>[];
      }
      return _runTaskQuery(
        params,
        pageKey,
        ids: taskIds,
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

  /// Intersects the full-text [ids] restriction (null when no search is
  /// active) with the open tasks [dueFilter] admits today. The due set is
  /// small — open tasks due on or before today — so it rides the same `ids`
  /// restriction search uses and composes with every other clause and both
  /// sort paths without a query of its own.
  Future<List<String>?> _narrowByDueFilter(
    List<String>? ids,
    TaskDueFilter dueFilter,
  ) async {
    if (dueFilter == TaskDueFilter.all) return ids;
    final dueIds = await _db.getOpenTaskIdsForDueFilter(
      dueFilter,
      now: clock.now(),
    );
    if (ids == null) return dueIds.toList();
    return ids.where(dueIds.contains).toList();
  }

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
      categoryIds = {...allCategoryIds, ''};
    } else {
      categoryIds = params.selectedCategoryIds;
    }

    final sortByDueDate = params.sortOption == TaskSortOption.byDueDate;
    final sortByDateInDb =
        params.sortOption == TaskSortOption.byDate || sortByDueDate;

    final agentFilterActive =
        params.agentAssignmentFilter != AgentAssignmentFilter.all;
    final projectFilterActive = params.selectedProjectIds.isNotEmpty;
    final needsPostFilter = agentFilterActive || projectFilterActive;

    if (!needsPostFilter) {
      setPostFilterNextRawOffset?.call(null);

      // Due-date sorting uses a dedicated raw SQL query with the expression
      // index so results are globally ordered across pages.
      if (sortByDueDate) {
        return _db.getTasksSortedByDueDate(
          ids: ids,
          starredStatuses: starredEntriesOnly ? [true] : [true, false],
          taskStatuses: params.selectedTaskStatuses.toList(),
          categoryIds: categoryIds.toList(),
          labelIds: params.selectedLabelIds.toList(),
          priorities: params.selectedPriorities.toList(),
          limit: pageSize,
          offset: pageKey,
        );
      }

      return _db.getTasks(
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
    final useDueDateSort = params.sortOption == TaskSortOption.byDueDate;

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
      final raw = useDueDateSort
          ? await _db.getTasksSortedByDueDate(
              ids: ids,
              starredStatuses: starredEntriesOnly ? [true] : [true, false],
              taskStatuses: params.selectedTaskStatuses.toList(),
              categoryIds: categoryIds.toList(),
              labelIds: params.selectedLabelIds.toList(),
              priorities: params.selectedPriorities.toList(),
              limit: fetchChunk,
              offset: currentOffset,
            )
          : await _db.getTasks(
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
      _domainLogger.log(
        LogDomain.persistence,
        'VectorSearchRepository not registered — '
        'is the embedding pipeline available?',
        subDomain: 'JournalQueryRunner',
        level: InsightLevel.warn,
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

      // Semantic results come back whole; narrow them to the due view here,
      // as the paged path does through its ids restriction. The distances
      // stay whole: they are the search's result set, which the smart-view
      // counts restrict themselves to.
      final dueIds = params.showTasks
          ? await _narrowByDueFilter(null, params.dueFilter)
          : null;
      return JournalVectorSearchResult(
        entities: dueIds == null
            ? result.entities
            : [
                for (final entity in result.entities)
                  if (dueIds.contains(entity.meta.id)) entity,
              ],
        elapsed: result.elapsed,
        distances: result.distances,
      );
    } on Exception catch (e, stackTrace) {
      _domainLogger.error(
        LogDomain.persistence,
        e,
        stackTrace: stackTrace,
        subDomain: 'JournalQueryRunner',
        message: 'Vector search failed',
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
}
