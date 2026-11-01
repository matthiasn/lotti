import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/link_suggestions/prior_work_mention.dart';
import 'package:lotti/features/ai/link_suggestions/related_task_finder.dart';
import 'package:lotti/features/ai/link_suggestions/task_link_suggestion.dart';
import 'package:lotti/features/ai/repository/vector_search_repository.dart';
import 'package:lotti/features/ai/service/embedding_content_extractor.dart';
import 'package:lotti/services/domain_logging.dart';
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
  TaskLinkSuggestionDetector({
    required JournalDb db,
    required VectorSearchRepository? search,
    DomainLogger? domainLogger,
  }) : _db = db,
       _finder = RelatedTaskFinder(
         db: db,
         search: search,
         domainLogger: domainLogger,
       );

  final JournalDb _db;
  final RelatedTaskFinder _finder;

  /// The most recent text entries of a task whose sentences are read.
  static const maxEntries = 20;

  /// The most mentions searched per scan, newest first. Each costs one query
  /// embedding.
  static const maxMentions = 4;

  /// The farthest cosine distance a task may be from a mention: the
  /// finder's measured cutoff ([RelatedTaskFinder.maxDistance]).
  static const double maxDistance = RelatedTaskFinder.maxDistance;

  /// The most suggestions offered for one task at a time.
  static const maxSuggestions = 3;

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
    if (!await _finder.isAvailable) {
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

    final found = await _finder.find(
      taskId,
      [for (final mention in mentions) mention.query ?? task.data.title],
      previous: previous?.searches,
    );
    // Matches come nearest first, and each names the earliest — newest —
    // mention that found it nearest.
    final suggestions = [
      for (final match in found.matches)
        TaskLinkSuggestion(
          sourceTaskId: taskId,
          targetTaskId: match.task.meta.id,
          targetTitle: match.task.data.title,
          relation: relationForCandidate(
            mentions[match.queryIndex],
            candidateIsClosed: isClosedTask(match.task),
          ),
          distance: match.distance,
          mention: mentions[match.queryIndex],
          mentionedAt: writtenAt[mentions[match.queryIndex].sourceId]!,
        ),
    ];
    final offered = suggestions.take(maxSuggestions).toList();

    return TaskLinkSuggestionScan(
      suggestions: offered,
      watchedIds: {...watchedIds, for (final s in offered) s.targetTaskId},
      searches: found.searches,
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
}
