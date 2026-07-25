import 'package:lotti/classes/day_plan.dart';
import 'package:meta/meta.dart';

/// Value types the day-planning eval scores over.
///
/// Deliberately small and provider-free: the scorers in
/// `eval_constraints.dart` are pure functions over these, so they can be
/// unit-tested against hand-built plans in ordinary CI without a model, a
/// database, or the pipeline.

/// One task as the model saw it in the corpus.
///
/// Mirrors the corpus row shape from `DayAgentCorpusService` closely enough to
/// score against, including the ADR 0043 `blockedBy` annotation.
@immutable
class EvalCorpusTask {
  const EvalCorpusTask({
    required this.taskId,
    required this.title,
    this.status = 'OPEN',
    this.blockedBy = const [],
    this.estimateMinutes,
    this.categoryId,
  });

  final String taskId;
  final String title;

  /// Corpus status string, e.g. `OPEN`, `IN PROGRESS`, `BLOCKED`.
  final String status;

  /// Task ids blocking this one (ADR 0043).
  final List<String> blockedBy;

  final int? estimateMinutes;
  final String? categoryId;

  /// ADR 0043's predicate, stated once.
  ///
  /// A union, not a choice: a manually blocked task shows `status: BLOCKED`
  /// with no links, so absence of [blockedBy] means link-ready, not free to
  /// schedule.
  bool get isBlocked =>
      status.toUpperCase() == 'BLOCKED' || blockedBy.isNotEmpty;
}

/// The inputs a scenario handed the model, kept alongside the result so a
/// scorer never has to re-derive what the model was asked to do.
@immutable
class EvalFixtureInputs {
  const EvalFixtureInputs({
    required this.dayId,
    required this.planDate,
    this.corpus = const [],
    this.decidedTaskIds = const [],
    this.capacityMinutes = 480,
    this.now,
  });

  final String dayId;
  final DateTime planDate;
  final List<EvalCorpusTask> corpus;

  /// Tasks the user explicitly approved for placement.
  final List<String> decidedTaskIds;

  final int capacityMinutes;

  /// Wall instant the draft ran at, for same-day scenarios. Null for a
  /// future-day draft, where "the past" has no meaning.
  final DateTime? now;

  EvalCorpusTask? taskById(String id) {
    for (final task in corpus) {
      if (task.taskId == id) return task;
    }
    return null;
  }
}

/// One tool call the model made, in order, including rejected ones.
///
/// Rejections are first-class: the write path throws on a violated hard
/// constraint and hands the message back to the model, which then retries. A
/// plan that only became legal on the fourth attempt is indistinguishable from
/// a first-time-right plan if you look at the persisted result alone, so the
/// rejection text is where guarded constraints are actually scored.
@immutable
class EvalToolCall {
  const EvalToolCall({
    required this.name,
    required this.accepted,
    this.rejectionMessage,
    this.arguments = const {},
  });

  final String name;
  final bool accepted;

  /// The failure text the model received. Null when [accepted].
  final String? rejectionMessage;

  final Map<String, Object?> arguments;
}

/// Everything one run produced, as the scorers see it.
@immutable
class EvalRunOutcome {
  const EvalRunOutcome({
    required this.inputs,
    this.blocks = const [],
    this.toolCalls = const [],
    this.planPersisted = true,
  });

  final EvalFixtureInputs inputs;

  /// Blocks on the persisted plan, in whatever order they were stored.
  final List<PlannedBlock> blocks;

  final List<EvalToolCall> toolCalls;

  /// False when the run ended without a plan at all — every constraint that
  /// reads the plan is then inapplicable rather than failed.
  final bool planPersisted;

  Iterable<EvalToolCall> get rejections =>
      toolCalls.where((call) => !call.accepted);
}

/// Outcome of one constraint against one run.
///
/// [passed] is nullable because "not applicable" is a distinct answer from
/// "failed": a scenario with no blocked tasks says nothing about whether the
/// model respects blockers, and averaging that in as a pass would flatter it.
@immutable
class EvalConstraintResult {
  const EvalConstraintResult({
    required this.id,
    required this.passed,
    required this.detail,
  });

  const EvalConstraintResult.notApplicable(this.id, this.detail)
    : passed = null;

  final String id;
  final bool? passed;

  /// Human-readable, and specific enough to act on — names the offending
  /// block or task rather than restating the rule.
  final String detail;

  bool get isApplicable => passed != null;
}
