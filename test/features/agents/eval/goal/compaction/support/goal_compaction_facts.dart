/// The production derivation for a compaction fixture: signal window →
/// evaluator → policy → `GoalWakeFacts` → `GoalFactsRenderer`.
///
/// Every arm of the evaluation renders through this, so the only thing that
/// differs between arms is the `userVoice` block. The status the agent is
/// asked to restate comes from the real evaluator and the real policy; the
/// fixture's answer key merely predicts it, and the offline self-test holds
/// the two together.
library;

import 'package:clock/clock.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/goals/evaluation/goal_progress_evaluator.dart';
import 'package:lotti/features/goals/evaluation/goal_track_policy.dart';
import 'package:lotti/features/goals/runtime/goal_wake_facts.dart';
import 'package:lotti/features/goals/workflow/goal_facts_renderer.dart';

import 'goal_compaction_fixtures.dart';

/// What the deterministic tier says about a fixture at the reference date.
class GoalCompactionDerivation {
  const GoalCompactionDerivation({
    required this.version,
    required this.facts,
    required this.priorRegisters,
  });

  final GoalSpecVersionEntity version;
  final GoalWakeFacts facts;
  final List<GoalProgressEntity> priorRegisters;

  GoalTrackStatus get status => facts.trackStatus;
}

/// Runs the fixture's window through the production evaluator and policy.
GoalCompactionDerivation deriveGoalCompactionFacts(
  GoalCompactionFixture fixture, {
  DateTime? reference,
}) {
  final now = reference ?? goalCompactionEvalReference;
  const evaluator = GoalProgressEvaluator();
  const policy = GoalTrackPolicy();
  final evaluation = evaluator.evaluate(fixture.criteria, fixture.window, now);
  final shortTerm = evaluator.shortTermAttainment(
    fixture.criteria,
    fixture.window,
    now,
  );
  final targetDate = fixture.targetDate;
  final status = policy.derive(
    evaluation: evaluation,
    shortTermAttainment: shortTerm,
    priorAttainments: fixture.priorAttainments,
    targetDatePassed:
        targetDate != null &&
        GoalWindow.dayUtc(now).isAfter(GoalWindow.dayUtc(targetDate)),
  );

  final specVersionId = '${fixture.agentId}:spec-v1';
  final version =
      AgentDomainEntity.goalSpecVersion(
            id: specVersionId,
            agentId: fixture.agentId,
            version: 1,
            status: GoalSpecVersionStatus.active,
            authoredBy: 'user',
            title: fixture.title,
            statement: fixture.statement,
            criteria: fixture.criteria,
            createdAt: fixture.startDate,
            vectorClock: null,
            startDate: fixture.startDate,
            targetDate: fixture.targetDate,
          )
          as GoalSpecVersionEntity;

  final priorRegisters = <GoalProgressEntity>[
    for (final (index, attainment) in fixture.priorAttainments.indexed)
      AgentDomainEntity.goalProgress(
            id: goalProgressId(
              fixture.agentId,
              goalCompactionDayKey(now.subtract(Duration(days: index + 1))),
            ),
            agentId: fixture.agentId,
            periodKey: goalCompactionDayKey(
              now.subtract(Duration(days: index + 1)),
            ),
            trackStatus: fixture.priorStatus,
            attainment: attainment,
            dataCoverage: 1,
            satisfied: attainment >= 1,
            specVersionId: specVersionId,
            createdAt: now.subtract(Duration(days: index + 1)),
            updatedAt: now.subtract(Duration(days: index + 1)),
            vectorClock: null,
          )
          as GoalProgressEntity,
  ];

  return GoalCompactionDerivation(
    version: version,
    facts: GoalWakeFacts(
      trackStatus: status,
      previousStatus: fixture.transitionFrom,
      evaluation: evaluation,
      shortTermAttainment: shortTerm,
    ),
    priorRegisters: priorRegisters,
  );
}

/// The question every evaluation wake carries. It makes `reply_to_user`
/// contract-mandated, so each arm produces a status assessment and a
/// recommendation the judge can compare against the full-context arm.
const goalCompactionEvalUserMessage =
    'Quick check: where does this goal stand right now, and what would you '
    'suggest I focus on next? Please take the whole history into account, '
    'not just this week.';

/// Renders the FACTS block the agent reads, with [userVoice] in the slot
/// the compaction strategy fills and the evaluation question pending.
String renderGoalCompactionFacts(
  GoalCompactionFixture fixture,
  GoalCompactionDerivation derivation, {
  required List<Map<String, Object?>> userVoice,
  DateTime? reference,
}) {
  final now = reference ?? goalCompactionEvalReference;
  return withClock(
    Clock.fixed(now),
    () => const GoalFactsRenderer().render(
      version: derivation.version,
      facts: derivation.facts,
      priorRegisters: derivation.priorRegisters,
      nudges: const [],
      evaluationReference: now,
      unansweredUserMessages: const [goalCompactionEvalUserMessage],
      userVoice: userVoice,
    ),
  );
}

/// A register's period key: the UTC calendar day.
String goalCompactionDayKey(DateTime day) =>
    day.toIso8601String().substring(0, 10);
