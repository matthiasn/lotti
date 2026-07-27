import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/tasks/repository/task_dependency_resolver.dart';

// Wake trigger-token vocabulary and extractors live in
// `day_agent_trigger_tokens.dart`.

/// Minimum score that becomes an auto-linked match.
const dayAgentHighConfidenceThreshold = 0.75;

/// Minimum score that becomes a low-confidence linked match.
const dayAgentMediumConfidenceThreshold = 0.5;

/// Parsed confidence classification used before persistence.
class ParsedItemMatchClassification {
  const ParsedItemMatchClassification({
    required this.confidence,
    required this.lowConfidence,
    required this.shouldAutoLink,
  });

  /// Persisted confidence bucket.
  final ParsedItemConfidence confidence;

  /// Whether UI should flag this item as a low-confidence match.
  final bool lowConfidence;

  /// Whether the parsed item should keep its matched task link.
  final bool shouldAutoLink;
}

/// Classifies a model-emitted match score using the phase-2 thresholds.
ParsedItemMatchClassification classifyParsedItemMatch(double score) {
  if (score >= dayAgentHighConfidenceThreshold) {
    return const ParsedItemMatchClassification(
      confidence: ParsedItemConfidence.high,
      lowConfidence: false,
      shouldAutoLink: true,
    );
  }
  if (score >= dayAgentMediumConfidenceThreshold) {
    return const ParsedItemMatchClassification(
      confidence: ParsedItemConfidence.medium,
      lowConfidence: true,
      shouldAutoLink: true,
    );
  }
  return const ParsedItemMatchClassification(
    confidence: ParsedItemConfidence.low,
    lowConfidence: false,
    shouldAutoLink: false,
  );
}

/// Pending decision bucket for Daily OS reconcile.
enum DayAgentPendingKind {
  /// Due before the active day.
  overdue,

  /// Already in progress.
  inProgress,

  /// Recurring task missed in the lookback window.
  missedRecurring,

  /// Due on the active day.
  dueToday,
}

/// Backend projection of a task that needs reconcile attention.
class DayAgentPendingItem {
  const DayAgentPendingItem({
    required this.taskId,
    required this.title,
    required this.kind,
    required this.status,
    required this.categoryId,
    this.due,
  });

  /// Journal task ID.
  final String taskId;

  /// Task title.
  final String title;

  /// Why the task is pending.
  final DayAgentPendingKind kind;

  /// Current task status string.
  final String status;

  /// Task category ID, if any.
  final String? categoryId;

  /// Due date, if set.
  final DateTime? due;

  /// JSON shape returned by direct tools.
  Map<String, Object?> toJson() => {
    'taskId': taskId,
    'title': title,
    'kind': kind.name,
    'status': status,
    'categoryId': categoryId,
    'due': due?.toIso8601String(),
  };
}

/// A task the user has decided to place in a day plan.
///
/// Emitted by `DayAgentPlanService.hydrateDecidedTasks` and surfaced in the
/// drafting prompt under `drafting.decidedTasks`. The model is expected to
/// set `PlannedBlock.taskId` to a value from this set when its `ai`/`manual`
/// blocks correspond to one of these tasks.
class DecidedTaskRef {
  const DecidedTaskRef({
    required this.id,
    required this.title,
    required this.categoryId,
    this.status,
    this.blockedBy = const [],
    this.estimateMinutes,
  });

  /// Journal task ID.
  final String id;

  /// Task title.
  final String title;

  /// Task category ID, if any.
  final String? categoryId;

  /// Task status as the corpus spells it, e.g. `OPEN`, `BLOCKED`.
  ///
  /// Carried because ADR 0043's blocked-work rule is stated in terms of it.
  /// The rule reaches the model on every drafting wake, but the task corpus
  /// that used to be its only source renders inside `<capture>` alone — so a
  /// wake without a capture was told to respect blockers while being shown
  /// nothing that could be blocked. Measured: the eval's blockedWithoutCorpus
  /// scenario failed `blockerBeforeBlocked` on every sample of every model,
  /// while its twin with the corpus rendered passed every one.
  final String? status;

  /// One-hop blockers (ADR 0043), in the same shape the corpus uses.
  final List<ResolvedBlocker> blockedBy;

  /// How long the task is expected to take, as the corpus spells it.
  ///
  /// Carried because the drafting rules ask the model to total the estimates of
  /// the work it intends to place and compare that against
  /// `<planning_window>.availableMinutes`. Without it that instruction is
  /// unfollowable on a capture-less wake: the corpus is the only other carrier
  /// of estimates and it renders inside `<capture>` alone. Measured before this
  /// existed — qwen3.5 placed 540 and 600 minutes of decided work against a
  /// 480-minute cap on two of three `overCommitted` samples.
  final int? estimateMinutes;

  /// JSON shape sent to the model in the drafting prompt.
  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'categoryId': categoryId,
    if (status != null) 'status': status,
    if (blockedBy.isNotEmpty)
      'blockedBy': [for (final blocker in blockedBy) blocker.toJson()],
    'estimateMinutes': ?estimateMinutes,
  };
}

/// Blocked-work state of a task an earlier draft already scheduled.
///
/// Exists because ADR 0043's rule is a **union** — a task is blocked when its
/// `status` is `BLOCKED` *or* it carries a non-empty `blockedBy` — and the two
/// halves come from different places. `TaskDependencyResolver` only ever
/// reports link-derived blockers, so a task a user marked blocked by hand
/// carries no blockers at all and would be invisible if blockers were the only
/// thing projected.
///
/// Only constructed for tasks that are actually blocked, so an ordinary
/// re-draft adds nothing to the prompt.
class PlannedTaskState {
  const PlannedTaskState({required this.status, this.blockedBy = const []});

  /// Task status as the corpus spells it, e.g. `OPEN`, `BLOCKED`.
  final String status;

  /// One-hop blockers (ADR 0043), empty for a hand-marked blocked task.
  final List<ResolvedBlocker> blockedBy;

  /// ADR 0043's predicate, stated once.
  static bool isBlocked({
    required String status,
    required List<ResolvedBlocker> blockedBy,
  }) => status == blockedTaskDbStatus || blockedBy.isNotEmpty;

  Map<String, Object?> toJson() => {
    'status': status,
    if (blockedBy.isNotEmpty)
      'blockedBy': [for (final blocker in blockedBy) blocker.toJson()],
  };
}

/// `TaskStatus.blocked.toDbString`, the spelling ADR 0043's rule quotes.
const String blockedTaskDbStatus = 'BLOCKED';

/// FTS-backed task candidate returned by `match_to_corpus`.
class DayAgentCorpusMatch {
  const DayAgentCorpusMatch({
    required this.taskId,
    required this.title,
    required this.score,
    required this.status,
    required this.categoryId,
    this.due,
  });

  /// Journal task ID.
  final String taskId;

  /// Task title.
  final String title;

  /// Relative score. Higher is better.
  final double score;

  /// Current task status string.
  final String status;

  /// Task category ID, if any.
  final String? categoryId;

  /// Due date, if set.
  final DateTime? due;

  /// JSON shape returned by direct tools.
  Map<String, Object?> toJson() => {
    'taskId': taskId,
    'title': title,
    'score': score,
    'status': status,
    'categoryId': categoryId,
    'due': due?.toIso8601String(),
  };
}

/// Converts a task row to a pending-decision projection.
DayAgentPendingItem pendingItemFromTask(Task task, DayAgentPendingKind kind) {
  return DayAgentPendingItem(
    taskId: task.id,
    title: task.data.title,
    kind: kind,
    status: task.data.status.toDbString,
    categoryId: task.meta.categoryId,
    due: task.data.due,
  );
}

/// Converts a task row to a corpus-match projection.
DayAgentCorpusMatch corpusMatchFromTask(Task task, double score) {
  return DayAgentCorpusMatch(
    taskId: task.id,
    title: task.data.title,
    score: score,
    status: task.data.status.toDbString,
    categoryId: task.meta.categoryId,
    due: task.data.due,
  );
}

/// Deduplicates pending decisions by task ID and sorts overdue work first.
///
/// When a task appears in multiple buckets, the highest-priority bucket wins.
List<DayAgentPendingItem> dedupeAndSortPendingItems(
  Iterable<DayAgentPendingItem> items,
) {
  final bestByTask = <String, DayAgentPendingItem>{};
  for (final item in items) {
    final existing = bestByTask[item.taskId];
    if (existing == null ||
        _pendingKindRank(item.kind) < _pendingKindRank(existing.kind)) {
      bestByTask[item.taskId] = item;
    }
  }

  final sorted = bestByTask.values.toList()
    ..sort((a, b) {
      final byKind = _pendingKindRank(a.kind).compareTo(
        _pendingKindRank(b.kind),
      );
      if (byKind != 0) return byKind;

      final aDue = a.due;
      final bDue = b.due;
      if (aDue != null && bDue != null) {
        final byDue = aDue.compareTo(bDue);
        if (byDue != 0) return byDue;
      } else if (aDue != null) {
        return -1;
      } else if (bDue != null) {
        return 1;
      }

      final byTitle = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      if (byTitle != 0) return byTitle;
      return a.taskId.compareTo(b.taskId);
    });
  return sorted;
}

int _pendingKindRank(DayAgentPendingKind kind) {
  return switch (kind) {
    DayAgentPendingKind.overdue => 0,
    DayAgentPendingKind.inProgress => 1,
    DayAgentPendingKind.missedRecurring => 2,
    DayAgentPendingKind.dueToday => 3,
  };
}
