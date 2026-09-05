import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';

/// What the band shows for one step: the durable status, read the way the
/// user decided it. A resolved step that recorded its task was *added*; a
/// resolved step without one was marked done by an older surface.
enum ProjectNextStepOutcome { pending, added, done, dismissed }

/// The outcome the band shows for [step].
ProjectNextStepOutcome projectNextStepOutcome(
  ProjectRecommendationEntity step,
) => switch (step.status) {
  ProjectRecommendationStatus.active => ProjectNextStepOutcome.pending,
  ProjectRecommendationStatus.dismissed => ProjectNextStepOutcome.dismissed,
  ProjectRecommendationStatus.resolved when step.createdTaskId != null =>
    ProjectNextStepOutcome.added,
  ProjectRecommendationStatus.resolved => ProjectNextStepOutcome.done,
  // Superseded rows never reach the band; a stale one reads as decided so
  // it can neither be acted on nor block the run summary.
  ProjectRecommendationStatus.superseded => ProjectNextStepOutcome.done,
};

/// How many steps of a run ended up in each outcome.
class ProjectNextStepsTally {
  const ProjectNextStepsTally({
    required this.pending,
    required this.added,
    required this.done,
    required this.dismissed,
  });

  factory ProjectNextStepsTally.of(
    Iterable<ProjectRecommendationEntity> steps,
  ) {
    var pending = 0;
    var added = 0;
    var done = 0;
    var dismissed = 0;
    for (final step in steps) {
      switch (projectNextStepOutcome(step)) {
        case ProjectNextStepOutcome.pending:
          pending++;
        case ProjectNextStepOutcome.added:
          added++;
        case ProjectNextStepOutcome.done:
          done++;
        case ProjectNextStepOutcome.dismissed:
          dismissed++;
      }
    }
    return ProjectNextStepsTally(
      pending: pending,
      added: added,
      done: done,
      dismissed: dismissed,
    );
  }

  final int pending;
  final int added;
  final int done;
  final int dismissed;

  int get total => pending + added + done + dismissed;

  /// Every step of the run has been decided (and there was at least one).
  bool get allDecided => total > 0 && pending == 0;
}

/// The steps a phone shows before "Show N more" — the first [cap] rows in the
/// agent's order, regardless of outcome, so a decided row keeps its place
/// instead of pushing an open one out of view. [cap] is ignored once the
/// user asked for all of them, and a run that fits the cap never truncates.
List<T> visibleProjectNextSteps<T>(
  List<T> steps, {
  required int cap,
  required bool showAll,
}) {
  assert(cap > 0, 'cap must be positive');
  if (showAll || steps.length <= cap) return steps;
  return steps.sublist(0, cap);
}

/// The coarse units of "when the agent last looked".
enum ProjectNextStepsAgeUnit { justNow, minutes, hours, days }

typedef ProjectNextStepsAge = ({ProjectNextStepsAgeUnit unit, int count});

/// Buckets [elapsed] into the coarse "when the agent last looked" wording
/// the band uses: anything under a minute is *just now*, then whole minutes,
/// whole hours, whole days. Negative elapsed (clock skew after sync) reads as
/// just now rather than as a time in the future.
ProjectNextStepsAge projectNextStepsAge(Duration elapsed) {
  if (elapsed < const Duration(minutes: 1)) {
    return (unit: ProjectNextStepsAgeUnit.justNow, count: 0);
  }
  if (elapsed < const Duration(hours: 1)) {
    return (unit: ProjectNextStepsAgeUnit.minutes, count: elapsed.inMinutes);
  }
  if (elapsed < const Duration(days: 1)) {
    return (unit: ProjectNextStepsAgeUnit.hours, count: elapsed.inHours);
  }
  return (unit: ProjectNextStepsAgeUnit.days, count: elapsed.inDays);
}
