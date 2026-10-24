import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/agents/service/open_task_corpus.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_reconcile_models.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_reads.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/features/tasks/repository/task_dependency_resolver.dart';
import 'package:lotti/utils/day_agent_capture_helpers.dart';

/// FTS corpus matching + corpus-snapshot logic for the day-agent capture
/// flow. The capture service keeps thin delegators so mocks of the service
/// still intercept the public methods. The corpus itself — which open tasks,
/// in which order — is `readOpenTaskCorpus` / `matchOpenTasksByPhrase` in
/// `features/agents`, shared with the front agent's routing index; this
/// service only shapes the day agent's rows and blockers from it.
class DayAgentCorpusService {
  /// Creates the corpus collaborator.
  DayAgentCorpusService({
    required this.journalDb,
    required this.fts5Db,
    required this.reads,
  });

  /// Maximum number of tasks embedded in a corpus snapshot.
  static const maxCorpusTasks = 200;

  /// Maximum number of match candidates returned by [matchToCorpus].
  static const maxMatchCandidates = 8;

  /// Journal DB used for task reads.
  final JournalDb journalDb;

  /// FTS index used by `match_to_corpus`.
  final Fts5Db fts5Db;

  /// Shared agent-identity resolution.
  final DayAgentCaptureReads reads;

  /// Build the bounded task corpus embedded in capture-triggered wakes.
  ///
  /// When [dependencyResolver] is supplied, blocked rows gain a `blockedBy`
  /// key (ADR 0043 §1-2) — resolved once against the already-capped id set,
  /// never per task. Omitting it (the default) keeps every row byte-identical
  /// to the pre-ADR-0043 shape, which is what makes a dependency-free corpus
  /// byte-stable. Estimates are emitted only when positive; zero is the
  /// standard persisted representation of unsized work and must not look free.
  Future<List<Map<String, Object?>>> buildTaskCorpusSnapshot({
    required Set<String> allowedCategoryIds,
    required DateTime day,
    int limit = maxCorpusTasks,
    TaskDependencyResolver? dependencyResolver,
  }) async {
    final tasks = await readOpenTaskCorpus(
      journalDb: journalDb,
      allowedCategoryIds: allowedCategoryIds,
      day: day,
      limit: limit,
    );

    final blockedBy = dependencyResolver == null
        ? const <String, List<ResolvedBlocker>>{}
        : await dependencyResolver.resolveBlockedStatus(
            {for (final task in tasks) task.id},
            allowedCategoryIds: allowedCategoryIds,
          );

    return [
      for (final task in tasks)
        {
          'taskId': task.id,
          'title': task.data.title,
          'status': task.data.status.toDbString,
          'categoryId': task.meta.categoryId,
          'due': task.data.due?.toIso8601String(),
          if (task.data.estimate?.inMinutes case final minutes?
              when minutes > 0)
            'estimateMinutes': minutes,
          'priority': task.data.priority.short,
          if (blockedBy[task.id] case final blockers?)
            'blockedBy': [for (final b in blockers) b.toJson()],
        },
    ];
  }

  /// Finds existing tasks that may match a capture phrase.
  Future<List<DayAgentCorpusMatch>> matchToCorpus({
    required String agentId,
    required String phrase,
    String? categoryHint,
  }) async {
    final identity = await reads.requireIdentity(agentId);
    final trimmed = phrase.trim();
    if (trimmed.isEmpty) {
      throw const DayAgentCaptureException('phrase must not be empty');
    }

    final categoryFilter = _categoryFilterForHint(
      allowedCategoryIds: identity.allowedCategoryIds,
      categoryHint: blankToNull(categoryHint),
    );
    if (categoryFilter != null && categoryFilter.isEmpty) {
      return const <DayAgentCorpusMatch>[];
    }

    final matches = await matchOpenTasksByPhrase(
      fts5Db: fts5Db,
      journalDb: journalDb,
      phrase: trimmed,
      categoryFilter: categoryFilter,
      limit: maxMatchCandidates,
    );
    return [
      for (final match in matches)
        corpusMatchFromTask(match.task, 1 / (match.rank + 1)),
    ];
  }

  Set<String>? _categoryFilterForHint({
    required Set<String> allowedCategoryIds,
    required String? categoryHint,
  }) {
    if (categoryHint == null) {
      return allowedCategoryIds.isEmpty ? null : allowedCategoryIds;
    }
    if (allowedCategoryIds.isNotEmpty &&
        !allowedCategoryIds.contains(categoryHint)) {
      return const <String>{};
    }
    return {categoryHint};
  }
}
