import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';

/// Wake trigger token prefix used when a capture should be parsed.
const dayAgentCaptureSubmittedPrefix = 'capture_submitted:';

/// Wake scheduling reason used when a capture was submitted.
const dayAgentCaptureSubmittedReason = 'capture_submitted';

/// Wake trigger token prefix used to request a day-plan drafting wake.
// TODO(day-agent): hoist drafting + capture + refine token helpers into a
// shared `day_agent_trigger_tokens.dart` once Commit adds another family.
const dayAgentDraftingPrefix = 'drafting:';

/// Wake scheduling reason used when a draft is requested.
const dayAgentDraftingReason = 'drafting';

/// Wake trigger token prefix used to request a day-plan refine wake.
const dayAgentRefinePrefix = 'refine:';

/// Wake scheduling reason used when a refine is requested.
const dayAgentRefineReason = 'refine';

/// Wake trigger token prefix used to advertise a task the UI considers
/// "decided" (one the user said yes to and wants placed in the day plan).
const dayAgentDecidedTaskPrefix = 'decided_task:';

/// Wake trigger token prefix used to advertise a parsed capture item the UI
/// considers "decided" but which does not have a persisted task ID yet.
const dayAgentDecidedCaptureItemPrefix = 'decided_capture_item:';

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
  });

  /// Journal task ID.
  final String id;

  /// Task title.
  final String title;

  /// Task category ID, if any.
  final String? categoryId;

  /// JSON shape sent to the model in the drafting prompt.
  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'categoryId': categoryId,
  };
}

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

/// Creates the capture-submitted wake trigger token.
String dayAgentCaptureSubmittedToken(String captureId) {
  return '$dayAgentCaptureSubmittedPrefix$captureId';
}

/// Extracts the first submitted capture ID from a trigger-token set.
///
/// The returned ID is trimmed of surrounding whitespace so equality checks
/// downstream (e.g. against `CaptureEntity.id`) match canonical form.
String? captureIdFromTriggerTokens(Set<String> triggerTokens) {
  for (final token in triggerTokens) {
    if (token.startsWith(dayAgentCaptureSubmittedPrefix)) {
      final captureId = token
          .substring(dayAgentCaptureSubmittedPrefix.length)
          .trim();
      if (captureId.isNotEmpty) return captureId;
    }
  }
  return null;
}

/// Creates the drafting wake trigger token for [dayId].
String dayAgentDraftingToken(String dayId) {
  return '$dayAgentDraftingPrefix$dayId';
}

/// Extracts the first drafting-target day ID from a trigger-token set.
///
/// The returned ID is trimmed of surrounding whitespace so equality checks
/// downstream (e.g. against `AgentSlots.activeDayId`) match canonical form.
String? draftingDayIdFromTriggerTokens(Set<String> triggerTokens) {
  for (final token in triggerTokens) {
    if (token.startsWith(dayAgentDraftingPrefix)) {
      final dayId = token.substring(dayAgentDraftingPrefix.length).trim();
      if (dayId.isNotEmpty) return dayId;
    }
  }
  return null;
}

/// Creates the refine wake trigger token for [dayId].
String dayAgentRefineToken(String dayId) {
  return '$dayAgentRefinePrefix$dayId';
}

/// Extracts the first refine-target day ID from a trigger-token set.
///
/// The returned ID is trimmed of surrounding whitespace so equality checks
/// downstream match canonical form.
String? refineDayIdFromTriggerTokens(Set<String> triggerTokens) {
  for (final token in triggerTokens) {
    if (token.startsWith(dayAgentRefinePrefix)) {
      final dayId = token.substring(dayAgentRefinePrefix.length).trim();
      if (dayId.isNotEmpty) return dayId;
    }
  }
  return null;
}

/// Creates the decided-task trigger token for [taskId].
String dayAgentDecidedTaskToken(String taskId) {
  return '$dayAgentDecidedTaskPrefix$taskId';
}

/// Creates the decided capture-item trigger token for [parsedItemId].
String dayAgentDecidedCaptureItemToken(String parsedItemId) {
  return '$dayAgentDecidedCaptureItemPrefix$parsedItemId';
}

/// Extracts every decided-task ID advertised on a trigger-token set.
///
/// Returns IDs trimmed of surrounding whitespace, in iteration order of the
/// input set. Skips prefix-only and whitespace-only tokens. Returns an empty
/// list when no decided-task tokens are present.
List<String> decidedTaskIdsFromTriggerTokens(Set<String> triggerTokens) =>
    _idsForPrefix(triggerTokens, dayAgentDecidedTaskPrefix);

/// Extracts every decided capture-item ID advertised on a trigger-token set.
///
/// These IDs refer to parsed capture items rather than journal tasks. They let
/// drafting carry approved NEW/unlinked items forward so the model can create
/// tasks before placing them.
List<String> decidedCaptureItemIdsFromTriggerTokens(
  Set<String> triggerTokens,
) => _idsForPrefix(triggerTokens, dayAgentDecidedCaptureItemPrefix);

List<String> _idsForPrefix(Set<String> tokens, String prefix) {
  final out = <String>[];
  for (final token in tokens) {
    if (token.startsWith(prefix)) {
      final id = token.substring(prefix.length).trim();
      if (id.isNotEmpty) out.add(id);
    }
  }
  return out;
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
