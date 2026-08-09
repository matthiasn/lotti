import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/goals/evaluation/goal_evaluation.dart';
import 'package:lotti/features/goals/runtime/goal_wake_facts.dart';
import 'package:lotti/features/goals/workflow/goal_facts_renderer.dart';

void main() {
  const renderer = GoalFactsRenderer();
  final now = DateTime(2026, 8, 9, 12);
  final fixedClock = Clock.fixed(now);

  GoalSpecVersionEntity version() =>
      AgentDomainEntity.goalSpecVersion(
            id: 'goal-1:spec-v1',
            agentId: 'goal-1',
            version: 1,
            status: GoalSpecVersionStatus.active,
            authoredBy: 'user',
            title: 'Steps',
            statement: 'Average 10,000 steps per day over a rolling week.',
            criteria: const GoalCriterion.metric(
              criterionId: 'steps',
              dataType: 'cumulative_step_count',
              window: GoalWindow.rollingDays(count: 7),
              aggregation: GoalAggregation.dailySumThenAverage,
              target: 10000,
            ),
            createdAt: DateTime(2026),
            vectorClock: null,
          )
          as GoalSpecVersionEntity;

  GoalWakeFacts facts({
    GoalTrackStatus status = GoalTrackStatus.offTrack,
    GoalTrackStatus? previous = GoalTrackStatus.atRisk,
  }) => GoalWakeFacts(
    trackStatus: status,
    previousStatus: previous,
    evaluation: const GoalEvaluation(
      attainment: 0.64,
      satisfied: false,
      dataCoverage: 1,
      results: {
        'steps': GoalCriterionResult(
          criterionId: 'steps',
          actual: 6400,
          target: 10000,
          ratio: 0.64,
          satisfied: false,
          sampleCount: 7,
        ),
      },
    ),
    shortTermAttainment: 0.5,
  );

  GoalNudgeEntity nudge({
    required String id,
    required GoalNudgeStatus status,
    List<GoalNudgeRating> ratings = const [],
    DateTime? activatedAt,
    DateTime? dismissedAt,
    DateTime? staleAt,
    int activationCount = 1,
  }) =>
      AgentDomainEntity.goalNudge(
            id: id,
            agentId: 'goal-1',
            status: status,
            brief: const GoalNudgeBrief(
              headline: 'Your inner couch potato is winning.',
              tagline: 'Six days of quiet shoes.',
              tone: GoalNudgeTone.nudge,
              animation: GoalBannerAnimation.pulse,
            ),
            briefDigest: 'digest-$id',
            createdAt: DateTime(2026, 8, 8),
            updatedAt: DateTime(2026, 8, 8),
            vectorClock: null,
            ratings: ratings,
            activatedAt: activatedAt,
            dismissedAt: dismissedAt,
            staleAt: staleAt,
            activationCount: activationCount,
          )
          as GoalNudgeEntity;

  Map<String, dynamic> renderedJson({
    List<GoalNudgeEntity> nudges = const [],
    GoalWakeFacts? wakeFacts,
    List<GoalProgressEntity> priors = const [],
  }) {
    final text = withClock(
      fixedClock,
      () => renderer.render(
        version: version(),
        facts: wakeFacts ?? facts(),
        priorRegisters: priors,
        nudges: nudges,
      ),
    );
    expect(
      text,
      startsWith('FACTS (deterministic, authoritative'),
      reason: 'the labelled fence is part of the validated contract',
    );
    final fence = text.substring(
      text.indexOf('```json\n') + 8,
      text.lastIndexOf('\n```'),
    );
    return jsonDecode(fence) as Map<String, dynamic>;
  }

  test('renders the exact section vocabulary the evals validated', () {
    final json = renderedJson();
    expect(json.keys, {
      'goal',
      'evaluation',
      'reporting',
      'ads',
      'personaTone',
      'unansweredUserMessages',
      'observations',
    });
    final evaluation = json['evaluation'] as Map<String, dynamic>;
    expect(evaluation['trackStatus'], 'offTrack');
    expect(evaluation['attainment'], 0.64);
    expect(evaluation['trailing3DayAttainment'], 0.5);
    final reporting = json['reporting'] as Map<String, dynamic>;
    expect(reporting['materialChangeSinceLastReport'], isTrue);
    expect(reporting['lastReportStatus'], 'atRisk');
    final goal = json['goal'] as Map<String, dynamic>;
    expect(
      (goal['criteria'] as Map<String, dynamic>)['window'],
      'rolling 7 days',
    );
  });

  test('active ads carry freshness; a stale-marked ad is exposed as such', () {
    final json = renderedJson(
      nudges: [
        nudge(
          id: 'ad-fresh',
          status: GoalNudgeStatus.active,
          activatedAt: now.subtract(const Duration(hours: 6)),
          staleAt: now.add(const Duration(hours: 66)),
        ),
        nudge(
          id: 'ad-stale',
          status: GoalNudgeStatus.active,
          activatedAt: now.subtract(const Duration(hours: 80)),
          staleAt: now.subtract(const Duration(hours: 8)),
        ),
      ],
    );
    final ads = json['ads'] as Map<String, dynamic>;
    final active = (ads['active'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(active, hasLength(2));
    final fresh = active.singleWhere((a) => a['adId'] == 'ad-fresh');
    expect(fresh['fresh'], isTrue);
    expect(fresh['markedStale'], isFalse);
    final stale = active.singleWhere((a) => a['adId'] == 'ad-stale');
    expect(stale['fresh'], isFalse);
    expect(stale['markedStale'], isTrue);
  });

  test('only retired ads with mean rating >= 4 are offered for re-run, '
      'best first; skips never count', () {
    GoalNudgeRating rating(
      int activation,
      int? value, {
      bool skipped = false,
    }) => GoalNudgeRating(
      activation: activation,
      ratedAt: DateTime(2026, 8, activation),
      rating: value,
      skipped: skipped,
    );
    final json = renderedJson(
      nudges: [
        nudge(
          id: 'ad-great',
          status: GoalNudgeStatus.retired,
          ratings: [rating(1, 5), rating(2, null, skipped: true), rating(3, 4)],
          activationCount: 3,
        ),
        nudge(
          id: 'ad-good',
          status: GoalNudgeStatus.retired,
          ratings: [rating(1, 4)],
        ),
        nudge(
          id: 'ad-meh',
          status: GoalNudgeStatus.retired,
          ratings: [rating(1, 2)],
        ),
        nudge(id: 'ad-unrated', status: GoalNudgeStatus.retired),
        nudge(
          id: 'ad-active-top',
          status: GoalNudgeStatus.active,
          ratings: [rating(1, 5)],
        ),
      ],
    );
    final reusable =
        ((json['ads'] as Map<String, dynamic>)['reusableTopRated']
                as List<dynamic>)
            .cast<Map<String, dynamic>>();
    expect(
      [for (final ad in reusable) ad['adId']],
      ['ad-great', 'ad-good'],
    );
    expect(reusable.first['meanRating'], 4.5);
    expect(reusable.first['timesRun'], 3);
  });

  test('a dismissal within 24h raises the cooldown flag; an old one does '
      'not', () {
    bool cooldown(DateTime dismissedAt) =>
        ((renderedJson(
                      nudges: [
                        nudge(
                          id: 'ad-x',
                          status: GoalNudgeStatus.dismissed,
                          dismissedAt: dismissedAt,
                        ),
                      ],
                    )['ads'] ??
                    <String, dynamic>{})
                as Map<String, dynamic>)['dismissalCooldownActive']
            as bool;
    expect(cooldown(now.subtract(const Duration(hours: 3))), isTrue);
    expect(cooldown(now.subtract(const Duration(hours: 30))), isFalse);
  });

  test('trend worsening needs three strictly declining points', () {
    expect(renderer.trendWorsening(0.5, [0.6, 0.7]), isTrue);
    expect(renderer.trendWorsening(0.5, [0.6]), isFalse);
    expect(renderer.trendWorsening(0.7, [0.6, 0.7]), isFalse);
    expect(renderer.trendWorsening(0.5, [0.5, 0.7]), isFalse);
  });

  test('criterionJson renders every composite variant', () {
    const composite = GoalCriterion.atLeastCount(
      criterionId: 'two-of-three',
      successes: 2,
      criteria: [
        GoalCriterion.habit(
          criterionId: 'gym',
          habitId: 'gym-habit',
          window: GoalWindow.calendarWeek(),
          targetCount: 3,
        ),
        GoalCriterion.measurable(
          criterionId: 'water',
          dataTypeId: 'water-id',
          window: GoalWindow.day(),
          aggregation: GoalAggregation.sum,
          target: 2000,
        ),
        GoalCriterion.anyOf(
          criterionId: 'either',
          criteria: [
            GoalCriterion.allOf(criterionId: 'both', criteria: []),
          ],
        ),
      ],
    );
    final json = criterionJson(composite);
    expect(json['atLeast'], 2);
    expect(
      criterionJson(
        const GoalCriterion.metric(
          criterionId: 'monthly',
          dataType: 'x',
          window: GoalWindow.calendarMonth(),
          aggregation: GoalAggregation.sum,
          target: 1,
        ),
      )['window'],
      'calendar month',
    );
    final children = (json['of']! as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(children[0]['habit'], 'gym-habit');
    expect(children[0]['window'], 'calendar week (Mon-Sun)');
    expect(children[1]['measurable'], 'water-id');
    expect(children[1]['window'], 'day');
    expect(
      ((children[2]['anyOf'] as List<dynamic>).single
          as Map<String, dynamic>)['allOf'],
      isEmpty,
    );
  });
}
