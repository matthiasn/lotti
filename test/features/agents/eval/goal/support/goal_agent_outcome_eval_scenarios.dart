/// The tier-2 scenario catalog: goal worlds expressed in domain entities.
///
/// Each scenario states only its EVIDENCE — the signal window, the banners
/// already on the board, the prior period registers. Status, attainment,
/// trend, freshness, cooldown and reusability are all derived by production
/// from that evidence, which is the point: a tier-1 fixture can claim a
/// status its FACTS never justify, and this tier structurally cannot.
///
/// The set is deliberately small. It covers the policy rows where an
/// *attempt* and an *outcome* can disagree — forced retries, strategy
/// rejections, withheld tools and the persistence gates — rather than
/// re-running tier 1's breadth through a slower harness.
library;

import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_window.dart';

import 'goal_agent_outcome_eval.dart';

/// The steps goal every scenario varies. One criterion on purpose: tier 2
/// measures the wake's machinery, and a composite tree would put the
/// evaluator's arithmetic in the way of that.
const goalOutcomeEvalSteps = GoalCriterion.metric(
  criterionId: 'steps',
  dataType: 'cumulative_step_count',
  window: GoalWindow.rollingDays(count: 7),
  aggregation: GoalAggregation.dailySumThenAverage,
  target: 10000,
);

const _statement = 'Average 10,000 steps per day.';

/// A uniform seven-day window at [perDay] steps. Attainment is then simply
/// `perDay / 10000`, so a scenario's intended status is legible from the
/// number alone — and the offline test asserts the derivation agrees.
GoalSignalWindow _uniform(int perDay) => GoalSignalWindow(
  quantitativeDailySums: {
    'cumulative_step_count': {
      for (var day = 3; day <= 9; day++) DateTime.utc(2026, 8, day): perDay,
    },
  },
);

/// Behind over the week but back at pace for the trailing three days — the
/// shape `GoalTrackPolicy` reads as `recovering`.
final _recoveringWindow = GoalSignalWindow(
  quantitativeDailySums: {
    'cumulative_step_count': {
      for (var day = 3; day <= 6; day++) DateTime.utc(2026, 8, day): 3000,
      for (var day = 7; day <= 9; day++) DateTime.utc(2026, 8, day): 11000,
    },
  },
);

/// Two days of readings in a seven-day window: coverage below the policy's
/// floor, which is `insufficientData` and never a guilt trip.
final _sparseWindow = GoalSignalWindow(
  quantitativeDailySums: {
    'cumulative_step_count': {
      DateTime.utc(2026, 8, 8): 9000,
      DateTime.utc(2026, 8, 9): 9500,
    },
  },
);

/// Yesterday's register, which is what makes a trend. `offTrack` needs a bad
/// prior period; a matching prior is what makes a wake a genuine no-op.
Map<String, GoalProgressEntity> Function(String, DateTime) _yesterday(
  GoalTrackStatus status,
  double attainment,
) =>
    (agentId, now) => {
      '2026-08-08': goalOutcomeEvalRegister(
        agentId: agentId,
        periodKey: '2026-08-08',
        trackStatus: status,
        attainment: attainment,
        now: now,
      ),
    };

/// The tier-2 catalog.
final goalOutcomeEvalScenarios = <GoalOutcomeEvalScenario>[
  // ── P2: the no-op discriminator ────────────────────────────────────────
  // On track yesterday, on track today, nothing to say. Tier 1 grades this
  // by counting tool calls; here it is the stronger claim that the wake left
  // NOTHING behind — no report, no head advance, no banner.
  GoalOutcomeEvalScenario(
    id: 'ot_quiet_wake',
    policyRuleId: 'P2',
    title: 'Steps',
    statement: _statement,
    criteria: goalOutcomeEvalSteps,
    window: _uniform(11000),
    priorRegisters: _yesterday(GoalTrackStatus.onTrack, 1.1),
    expectation: const GoalOutcomeExpectation(expectsNoOutcome: true),
  ),

  // ── P1: a transition owes a report ─────────────────────────────────────
  // Yesterday at risk, today on track. `statusTransitioned` makes the report
  // mandatory, so this case also exercises `_forceReport`: a model that
  // simply answers in prose is repaired into a persisted report, and tier 1
  // would have scored the same turn a miss.
  GoalOutcomeEvalScenario(
    id: 'ot_transition_report',
    policyRuleId: 'P1',
    title: 'Steps',
    statement: _statement,
    criteria: goalOutcomeEvalSteps,
    window: _uniform(11000),
    priorRegisters: _yesterday(GoalTrackStatus.atRisk, 0.85),
    expectation: const GoalOutcomeExpectation(
      requiresReport: true,
      expectedReportStatus: GoalTrackStatus.onTrack,
      forbidsNewAd: true,
    ),
  ),

  // ── P5: off track with a clear board owes a banner ──────────────────────
  // The only row where an ad is REQUIRED, and the one `_forceAd` exists for.
  GoalOutcomeEvalScenario(
    id: 'off_track_first_ad',
    policyRuleId: 'P5',
    title: 'Steps',
    statement: _statement,
    criteria: goalOutcomeEvalSteps,
    window: _uniform(6000),
    priorRegisters: _yesterday(GoalTrackStatus.atRisk, 0.6),
    expectation: const GoalOutcomeExpectation(
      requiresReport: true,
      expectedReportStatus: GoalTrackStatus.offTrack,
      requiresNewAd: true,
    ),
  ),

  // ── P6: a fresh banner is already doing this job ───────────────────────
  // Ad tools are on the wire here (off track IS eligible), so this measures
  // restraint under temptation rather than a withheld surface — and it
  // measures it at the board, where a second banner would actually shout.
  GoalOutcomeEvalScenario(
    id: 'off_track_fresh_ad',
    policyRuleId: 'P6',
    title: 'Steps',
    statement: _statement,
    criteria: goalOutcomeEvalSteps,
    window: _uniform(6000),
    priorRegisters: _yesterday(GoalTrackStatus.atRisk, 0.6),
    nudges: (agentId, now) => [
      goalOutcomeEvalNudge(
        id: 'ad-fresh',
        agentId: agentId,
        status: NudgeStatus.active,
        headline: 'Your pedometer misses you.',
        now: now,
      ),
    ],
    expectation: const GoalOutcomeExpectation(
      requiresReport: true,
      forbidsNewAd: true,
    ),
  ),

  // ── The dismissal cooldown, end to end ─────────────────────────────────
  // Off track — so policy would otherwise REQUIRE an ad — but the user
  // dismissed one today. The deterministic tier withholds the ad tools
  // entirely, and this case proves the quiet actually reaches the board
  // rather than being argued for in the prompt.
  GoalOutcomeEvalScenario(
    id: 'off_track_cooldown',
    policyRuleId: 'P5',
    title: 'Steps',
    statement: _statement,
    criteria: goalOutcomeEvalSteps,
    window: _uniform(6000),
    priorRegisters: _yesterday(GoalTrackStatus.atRisk, 0.6),
    nudges: (agentId, now) => [
      goalOutcomeEvalNudge(
        id: 'ad-dismissed-today',
        agentId: agentId,
        status: NudgeStatus.dismissed,
        headline: 'Ten thousand steps is a walk, not a marathon.',
        now: now,
        age: const Duration(hours: 4),
        dismissedAt: now.subtract(const Duration(hours: 4)),
      ),
    ],
    expectation: const GoalOutcomeExpectation(
      requiresReport: true,
      forbidsNewAd: true,
    ),
  ),

  // ── P7: recovering retires the stale scolding ──────────────────────────
  GoalOutcomeEvalScenario(
    id: 'recovering_retires_ad',
    policyRuleId: 'P7',
    title: 'Steps',
    statement: _statement,
    criteria: goalOutcomeEvalSteps,
    window: _recoveringWindow,
    priorRegisters: _yesterday(GoalTrackStatus.offTrack, 0.4),
    nudges: (agentId, now) => [
      goalOutcomeEvalNudge(
        id: 'ad-stale-behind',
        agentId: agentId,
        status: NudgeStatus.active,
        headline: "You're well behind this week.",
        now: now,
        age: const Duration(days: 4),
      ),
    ],
    expectation: const GoalOutcomeExpectation(
      requiresRetirement: true,
      forbidsNewAd: true,
    ),
  ),

  // ── P8: a data gap is not a failure ────────────────────────────────────
  GoalOutcomeEvalScenario(
    id: 'sparse_insufficient_data',
    policyRuleId: 'P8',
    title: 'Steps',
    statement: _statement,
    criteria: goalOutcomeEvalSteps,
    window: _sparseWindow,
    priorRegisters: _yesterday(GoalTrackStatus.insufficientData, 0),
    expectation: const GoalOutcomeExpectation(
      expectedReportStatus: GoalTrackStatus.insufficientData,
      forbidsNewAd: true,
    ),
  ),

  // ── P13: reuse beats authoring ─────────────────────────────────────────
  // Off track with no active banner but a proven retired one on the shelf.
  // `rerun_goal_ad` costs nothing to author; a fresh `create_goal_ad` is the
  // wrong outcome even though it also puts a banner on the board.
  GoalOutcomeEvalScenario(
    id: 'off_track_reuses_top_rated',
    policyRuleId: 'P13',
    title: 'Steps',
    statement: _statement,
    criteria: goalOutcomeEvalSteps,
    window: _uniform(6000),
    priorRegisters: _yesterday(GoalTrackStatus.atRisk, 0.6),
    nudges: (agentId, now) => [
      goalOutcomeEvalNudge(
        id: 'ad-top-rated',
        agentId: agentId,
        status: NudgeStatus.retired,
        headline: 'The couch will still be there afterwards.',
        now: now,
        age: const Duration(days: 12),
        retiredAt: now.subtract(const Duration(days: 5)),
        ratings: [
          NudgeRating(
            activation: 1,
            ratedAt: now.subtract(const Duration(days: 6)),
            rating: 5,
          ),
        ],
      ),
    ],
    expectation: const GoalOutcomeExpectation(requiresRerun: true),
  ),

  // ── P10: dialogue first, and the user must actually get an answer ──────
  // On track, so the ad tools are withheld — the interactive-and-ineligible
  // combination that used to leave them on the wire for every chat turn.
  // The pass condition is a persisted, user-visible reply.
  GoalOutcomeEvalScenario(
    id: 'chat_question_on_track',
    policyRuleId: 'P10',
    title: 'Steps',
    statement: _statement,
    criteria: goalOutcomeEvalSteps,
    window: _uniform(11000),
    priorRegisters: _yesterday(GoalTrackStatus.onTrack, 1.1),
    pendingUserMessage: 'How am I doing on steps this week?',
    triggerTokens: const {'goal-chat'},
    expectation: const GoalOutcomeExpectation(
      requiresReply: true,
      forbidsNewAd: true,
    ),
  ),
];

/// Lookup by id, for the offline tests and `GOAL_OUTCOME_EVAL_SCENARIOS`.
GoalOutcomeEvalScenario goalOutcomeScenarioById(String id) =>
    goalOutcomeEvalScenarios.firstWhere((scenario) => scenario.id == id);
