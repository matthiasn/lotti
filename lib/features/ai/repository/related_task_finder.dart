import 'package:flutter/foundation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/repository/vector_search_repository.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/consts.dart';

/// One related task a search by meaning found, before it is read back: its
/// id and cosine distance.
typedef RelatedTaskHit = ({String taskId, double distance});

/// One task a search by meaning found close enough to a query.
@immutable
class RelatedTaskMatch {
  const RelatedTaskMatch({
    required this.task,
    required this.distance,
    required this.queryIndex,
  });

  /// The task, read fresh for this search.
  final Task task;

  /// Cosine distance of its nearest embedding to the query, lower is closer.
  final double distance;

  /// Which of the queries found it nearest; on a tie, the earliest.
  final int queryIndex;
}

/// What a search found, and the searches it ran or reused.
@immutable
class RelatedTaskSearch {
  const RelatedTaskSearch({required this.matches, required this.searches});

  /// Nearest first; equally near tasks by id, so the order never reshuffles.
  final List<RelatedTaskMatch> matches;

  /// Hits by query, for a later search of the same queries to reuse. Only
  /// searches that ran are kept: empty means none did.
  final Map<String, List<RelatedTaskHit>> searches;
}

/// Finds the tasks related by meaning to some text about a task, on the
/// device — what the task agent's `find_related_tasks` tool searches with.
///
/// A task counts when it is within [maxDistance] of a query, is not the task
/// itself, holds no live link to it — any type, either direction, hidden
/// ones included — and still exists. Tasks are read fresh on every search;
/// only ids and distances are ever reused.
class RelatedTaskFinder {
  const RelatedTaskFinder({
    required this._db,
    required this._search,
    this._domainLogger,
  });

  final JournalDb _db;

  /// Null where the embedding pipeline did not start (its store failed to
  /// open, or the platform runs no model): there is nothing to search.
  final VectorSearchRepository? _search;
  final DomainLogger? _domainLogger;

  /// The farthest cosine distance a task may be from a query.
  ///
  /// Measured with the shipped EmbeddingGemma q4 model over the demo world's
  /// note and paraphrase queries in eleven languages: the right task's median
  /// distance is 0.53, the nearest wrong task's 0.63. At 0.55, 57 % of right
  /// matches pass and 13 % of nearest wrong ones; nine in ten nearest hits
  /// under it are the right task. A related task offered wrongly costs more
  /// than one never offered, so the cutoff favours precision.
  static const maxDistance = 0.55;

  /// Related tasks asked of each search. One more is asked for, since the
  /// task itself is usually the nearest match of its own text.
  static const hitsPerQuery = 5;

  static const _sub = 'RelatedTaskFinder';

  /// Whether a search can run at all: the pipeline is up and search by
  /// meaning is switched on. Without the model a search still returns
  /// nothing, which the search itself reports ([VectorSearchResult.searched]).
  Future<bool> get isAvailable async =>
      _search != null && await _db.getConfigFlag(enableEmbeddingsFlag);

  /// The tasks related to [taskId] by any of [queries].
  ///
  /// [previous] supplies searches already run, by query; [categoryIds]
  /// limits the search to those categories, null meaning all of them. A
  /// query whose search did not run is left out of [RelatedTaskSearch
  /// .searches], so the next search tries it again.
  Future<RelatedTaskSearch> find(
    String taskId,
    List<String> queries, {
    Map<String, List<RelatedTaskHit>>? previous,
    Set<String>? categoryIds,
  }) async {
    final search = _search;
    if (search == null || queries.isEmpty) {
      return const RelatedTaskSearch(matches: [], searches: {});
    }

    final searches = <String, List<RelatedTaskHit>>{};
    final best = <String, ({int queryIndex, double distance})>{};
    for (var i = 0; i < queries.length; i++) {
      final query = queries[i];
      final hits =
          searches[query] ??
          previous?[query] ??
          await _searchFor(search, query, categoryIds);
      if (hits == null) continue;
      searches[query] = hits;
      for (final hit in hits) {
        if (hit.taskId == taskId || hit.distance > maxDistance) continue;
        final current = best[hit.taskId];
        if (current == null || hit.distance < current.distance) {
          best[hit.taskId] = (queryIndex: i, distance: hit.distance);
        }
      }
    }

    final linked = await _linkedTaskIds(taskId);
    final candidateIds = best.keys.where((id) => !linked.contains(id)).toSet();
    final tasks = await _db.getJournalEntitiesForIdsUnordered(candidateIds);
    final matches = [
      for (final task in tasks)
        if (task is Task && task.meta.deletedAt == null)
          RelatedTaskMatch(
            task: task,
            distance: best[task.meta.id]!.distance,
            queryIndex: best[task.meta.id]!.queryIndex,
          ),
    ]..sort(_nearestFirst);

    return RelatedTaskSearch(matches: matches, searches: searches);
  }

  static int _nearestFirst(RelatedTaskMatch a, RelatedTaskMatch b) {
    final byDistance = a.distance.compareTo(b.distance);
    return byDistance != 0
        ? byDistance
        : a.task.meta.id.compareTo(b.task.meta.id);
  }

  /// The search's hits for [query], or null when no search ran — it threw,
  /// or the model is missing or could not embed the query.
  Future<List<RelatedTaskHit>?> _searchFor(
    VectorSearchRepository search,
    String query,
    Set<String>? categoryIds,
  ) async {
    try {
      final result = await search.searchRelatedTasks(
        query: query,
        k: hitsPerQuery + 1,
        categoryIds: categoryIds,
      );
      if (!result.searched) return null;
      return [
        for (final entity in result.entities)
          if (result.distances[entity.meta.id] case final distance?)
            (taskId: entity.meta.id, distance: distance),
      ];
    } on Exception catch (e, stackTrace) {
      _domainLogger?.error(
        LogDomain.ai,
        DomainLogger.withoutSource(e),
        errorType: e.runtimeType,
        stackTrace: stackTrace,
        subDomain: _sub,
        message: 'Related-task search failed',
      );
      return null;
    }
  }

  /// Every task linked to [taskId] by any live link, of any type, in either
  /// direction — hidden links included, since the user chose to hide them,
  /// not to have them offered again.
  Future<Set<String>> _linkedTaskIds(String taskId) async {
    final links = await _db.linksForEntryIdsBidirectional({taskId});
    return {
      for (final link in links)
        if (link.fromId == taskId) link.toId else link.fromId,
    };
  }
}
