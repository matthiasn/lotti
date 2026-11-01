import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/link_suggestions/prior_work_mention.dart';
import 'package:lotti/features/ai/link_suggestions/task_link_suggestion.dart';
import 'package:lotti/features/ai/repository/vector_search_repository.dart';
import 'package:lotti/features/ai/service/embedding_content_extractor.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/day_agent_capture_helpers.dart';

/// Finds the tasks a task's notes and log entries speak of, and suggests
/// linking them.
///
/// Mechanical and local: a sentence that mentions other work
/// ([detectPriorWorkMentions]) is searched by meaning over the on-device
/// embedding index ([VectorSearchRepository.searchRelatedTasks]); a task
/// close enough to it, and not linked to this one already, becomes a
/// suggestion. Nothing is written here and no model other than the embedding
/// model runs.
class TaskLinkSuggestionDetector {
  const TaskLinkSuggestionDetector({
    required this._db,
    required this._search,
    this._domainLogger,
  });

  final JournalDb _db;

  /// Null where the embedding pipeline did not start (its store failed to
  /// open, or the platform runs no model): there is nothing to search.
  final VectorSearchRepository? _search;
  final DomainLogger? _domainLogger;

  /// The most recent text entries of a task whose sentences are read.
  static const maxEntries = 20;

  /// The most mentions searched per scan, newest first. Each costs one query
  /// embedding.
  static const maxMentions = 4;

  /// Related tasks asked of each search. One more is asked for, since the
  /// task itself is usually the nearest match of its own sentences.
  static const hitsPerMention = 5;

  /// The most suggestions offered for one task at a time.
  static const maxSuggestions = 3;

  /// The farthest cosine distance a task may be from the mention.
  ///
  /// Measured with the shipped EmbeddingGemma q4 model over the demo world's
  /// note and paraphrase queries in eleven languages: the right task's median
  /// distance is 0.53, the nearest wrong task's 0.63. At 0.55, 57 % of right
  /// matches pass and 13 % of nearest wrong ones; nine in ten nearest hits
  /// under it are the right task. A suggestion the user has to reject costs
  /// more than one that is never made, so the cutoff favours precision.
  static const maxDistance = 0.55;

  static const _sub = 'TaskLinkSuggestionDetector';

  /// Scans [taskId]'s notes and its linked text entries.
  ///
  /// [previous] is the last scan of the same task; its searches are reused
  /// for every query that has not changed.
  Future<TaskLinkSuggestionScan> scan(
    String taskId, {
    TaskLinkSuggestionScan? previous,
  }) async {
    final task = await _db.journalEntityById(taskId);
    if (task is! Task || task.meta.deletedAt != null) {
      return TaskLinkSuggestionScan.empty;
    }
    final search = _search;
    if (search == null || !await _db.getConfigFlag(enableEmbeddingsFlag)) {
      return TaskLinkSuggestionScan(
        suggestions: const [],
        watchedIds: {taskId},
      );
    }

    final entries =
        (await _db.getLinkedEntities(taskId))
            .where(
              (e) =>
                  (e is JournalEntry || e is JournalAudio) &&
                  e.meta.deletedAt == null,
            )
            .toList()
          ..sort((a, b) => b.meta.dateFrom.compareTo(a.meta.dateFrom));
    final watchedIds = {taskId, for (final e in entries) e.meta.id};
    final writtenAt = {
      taskId: task.meta.dateFrom,
      for (final e in entries) e.meta.id: e.meta.dateFrom,
    };

    final mentions = _mentions(task, entries.take(maxEntries));
    if (mentions.isEmpty) {
      return TaskLinkSuggestionScan(
        suggestions: const [],
        watchedIds: watchedIds,
      );
    }

    final searches = <String, List<RelatedTaskHit>>{};
    final best = <String, ({PriorWorkMention mention, double distance})>{};
    for (final mention in mentions) {
      final query = mention.query ?? task.data.title;
      final hits =
          searches[query] ??
          previous?.searches[query] ??
          await _searchFor(search, query);
      if (hits == null) continue;
      searches[query] = hits;
      for (final hit in hits) {
        if (hit.taskId == taskId || hit.distance > maxDistance) continue;
        final current = best[hit.taskId];
        // Mentions come newest first: an equally near later one keeps the
        // newer mention's relation.
        if (current == null || hit.distance < current.distance) {
          best[hit.taskId] = (mention: mention, distance: hit.distance);
        }
      }
    }

    final linked = await _linkedTaskIds(taskId);
    final candidateIds = best.keys.where((id) => !linked.contains(id)).toSet();
    final candidates = {
      for (final entity in await _db.getJournalEntitiesForIdsUnordered(
        candidateIds,
      ))
        if (entity is Task && entity.meta.deletedAt == null)
          entity.meta.id: entity,
    };

    final suggestions =
        [
          for (final MapEntry(key: id, value: candidate) in candidates.entries)
            TaskLinkSuggestion(
              sourceTaskId: taskId,
              targetTaskId: id,
              targetTitle: candidate.data.title,
              relation: relationForCandidate(
                best[id]!.mention,
                candidateIsClosed: isClosedTask(candidate),
              ),
              distance: best[id]!.distance,
              mention: best[id]!.mention,
              mentionedAt: writtenAt[best[id]!.mention.sourceId]!,
            ),
        ]..sort((a, b) {
          final byDistance = a.distance.compareTo(b.distance);
          return byDistance != 0
              ? byDistance
              : a.targetTaskId.compareTo(b.targetTaskId);
        });
    final offered = suggestions.take(maxSuggestions).toList();

    return TaskLinkSuggestionScan(
      suggestions: offered,
      watchedIds: {...watchedIds, for (final s in offered) s.targetTaskId},
      searches: searches,
    );
  }

  /// The mentions to search, at most [maxMentions]: the entries' first,
  /// newest entry first, then the task's own notes.
  List<PriorWorkMention> _mentions(
    Task task,
    Iterable<JournalEntity> newestFirst,
  ) {
    final mentions = <PriorWorkMention>[];
    void addFrom(String? text, String sourceId) {
      if (text == null || mentions.length >= maxMentions) return;
      mentions.addAll(
        detectPriorWorkMentions(
          text,
          sourceId: sourceId,
        ).take(maxMentions - mentions.length),
      );
    }

    for (final entry in newestFirst) {
      addFrom(EmbeddingContentExtractor.plainTextOf(entry), entry.meta.id);
    }
    addFrom(task.entryText?.plainText, task.meta.id);
    return mentions;
  }

  /// The search's hits for [query], or null when no search ran — it threw,
  /// or the model is missing or could not embed the query. Null is not
  /// remembered, so the next scan tries again; only a search that ran can
  /// answer "nothing found" for good.
  Future<List<RelatedTaskHit>?> _searchFor(
    VectorSearchRepository search,
    String query,
  ) async {
    try {
      final result = await search.searchRelatedTasks(
        query: query,
        k: hitsPerMention + 1,
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
  /// not to have them suggested again.
  Future<Set<String>> _linkedTaskIds(String taskId) async {
    final links = await _db.linksForEntryIdsBidirectional({taskId});
    return {
      for (final link in links)
        if (link.fromId == taskId) link.toId else link.fromId,
    };
  }
}
