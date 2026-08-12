import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/goals/evaluation/goal_evaluation.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_window.dart';
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
    int? deficit,
    int? buffer,
    Map<String, List<GoalCategoryTimeSession>> categoryTimeSessions = const {},
    DateTime? categoryTimeEvidenceStart,
    DateTime? categoryTimeEvidenceEnd,
  }) => GoalWakeFacts(
    trackStatus: status,
    previousStatus: previous,
    evaluation: GoalEvaluation(
      attainment: 0.64,
      satisfied: false,
      dataCoverage: 1,
      deficit: deficit,
      buffer: buffer,
      results: {
        'steps': GoalCriterionResult(
          criterionId: 'steps',
          actual: 6400,
          target: 10000,
          ratio: 0.64,
          satisfied: false,
          sampleCount: 7,
          deficit: deficit,
          buffer: buffer,
        ),
      },
    ),
    shortTermAttainment: 0.5,
    categoryTimeSessionsByCategory: categoryTimeSessions,
    categoryTimeEvidenceStart: categoryTimeEvidenceStart,
    categoryTimeEvidenceEnd: categoryTimeEvidenceEnd,
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
      'generatedAt',
      'localTime',
      'goal',
      'evaluation',
      'reporting',
      'ads',
      'personaTone',
      'unansweredUserMessages',
      'observations',
    });
    final localTime = json['localTime'] as Map<String, dynamic>;
    expect(localTime['iso8601'], isA<String>());
    expect(localTime['utcOffsetMinutes'], isA<int>());
    expect(localTime['timeZoneName'], isA<String>());
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

  test('rolling-window recovery facts reach the authoritative block so the '
      'agent can restate them without recomputing', () {
    final json = renderedJson(wakeFacts: facts(deficit: 2, buffer: 1));
    final evaluation = json['evaluation'] as Map<String, dynamic>;
    // Root-level, and per-criterion.
    expect(evaluation['daysToRecover'], 2);
    expect(evaluation['bufferDays'], 1);
    final steps = (evaluation['criterionResults'] as List).single;
    expect((steps as Map<String, dynamic>)['daysToRecover'], 2);
    expect(steps['bufferDays'], 1);
  });

  test('active ads carry freshness; a stale-marked ad is exposed as such', () {
    final recordedOutcome = GoalNudgeRating(
      activation: 1,
      ratedAt: now.subtract(const Duration(hours: 1)),
      rating: 4,
    );
    final json = renderedJson(
      nudges: [
        nudge(
          id: 'ad-fresh',
          status: GoalNudgeStatus.active,
          activatedAt: now.subtract(const Duration(hours: 6)),
          staleAt: now.add(const Duration(hours: 66)),
          ratings: [recordedOutcome],
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
    expect(fresh['outcomeRecorded'], isTrue);
    final stale = active.singleWhere((a) => a['adId'] == 'ad-stale');
    expect(stale['fresh'], isFalse);
    expect(stale['markedStale'], isTrue);
    expect(stale['outcomeRecorded'], isFalse);
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

  test('a dismissal quiets the rest of ITS calendar day; yesterday does '
      'not carry over', () {
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
    // Same local day (test clock is 2026-08-09 12:00): quiet.
    expect(cooldown(DateTime(2026, 8, 9, 8)), isTrue);
    expect(cooldown(DateTime(2026, 8, 9, 23, 30)), isTrue);
    // Late last night — a rolling 24h would still be quiet; a new day
    // must not be.
    expect(cooldown(DateTime(2026, 8, 8, 23)), isFalse);
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

  test(
    'criterionJson labels tracked category time and its local daily band',
    () {
      final json = criterionJson(
        const GoalCriterion.categoryTime(
          criterionId: 'late-coding',
          categoryId: 'vibe-coding',
          window: GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.sum,
          targetHours: 0,
          title: 'Late-night coding',
          dailyTimeRange: GoalDailyTimeRange(
            startMinute: 21 * 60 + 30,
            endMinute: 7 * 60,
          ),
        ),
      );

      expect(json['categoryTime'], 'vibe-coding');
      expect(json['title'], 'Late-night coding');
      expect(json['targetHours'], 0);
      expect(json['direction'], 'atMost');
      expect(json['evidence'], 'tracked Lotti time entries only');
      expect(json['dailyTimeRange'], {
        'startMinute': 21 * 60 + 30,
        'endMinute': 7 * 60,
      });
    },
  );

  test(
    'category session evidence exposes local timing without deciding success',
    () {
      final json = renderedJson(
        wakeFacts: facts(
          categoryTimeSessions: {
            'vibe-coding': [
              GoalCategoryTimeSession(
                categoryId: 'vibe-coding',
                dateFrom: DateTime(2026, 8, 8, 23, 15),
                dateTo: DateTime(2026, 8, 9, 1, 45),
              ),
            ],
          },
          categoryTimeEvidenceStart: DateTime(2026, 8, 2),
          categoryTimeEvidenceEnd: DateTime(2026, 8, 10),
        ),
      );

      final signals = json['signals'] as Map<String, dynamic>;
      expect(signals['categoryTimeEvidenceStart'], '2026-08-02T00:00:00.000');
      expect(signals['categoryTimeEvidenceEnd'], '2026-08-10T00:00:00.000');
      final session =
          (signals['categoryTimeSessions'] as List).single
              as Map<String, dynamic>;
      expect(session['categoryId'], 'vibe-coding');
      expect(session['startedAtLocal'], '2026-08-08T23:15:00.000');
      expect(session['endedAtLocal'], '2026-08-09T01:45:00.000');
      expect(session['durationMinutes'], 150);
      expect(session.containsKey('satisfied'), isFalse);
      final summary =
          (signals['categoryTimeLifetimeSummary'] as List).single
              as Map<String, dynamic>;
      expect(summary['sessionCount'], 1);
      expect(summary['totalMinutes'], 150);
      final minutesByHour = summary['minutesByLocalHour'] as List;
      expect(minutesByHour[23], 45);
      expect(minutesByHour[0], 60);
      expect(minutesByHour[1], 45);
    },
  );

  test('lifetime category evidence keeps a bounded recent raw sample', () {
    final sessions = [
      for (var index = 0; index < 205; index++)
        GoalCategoryTimeSession(
          categoryId: 'vibe-coding',
          dateFrom: DateTime(2026).add(Duration(hours: index)),
          dateTo: DateTime(2026).add(
            Duration(hours: index, minutes: 30),
          ),
        ),
    ];

    final json = renderedJson(
      wakeFacts: facts(
        categoryTimeSessions: {'vibe-coding': sessions},
        categoryTimeEvidenceStart: DateTime(2026),
        categoryTimeEvidenceEnd: DateTime(2026, 8, 10),
      ),
    );
    final signals = json['signals'] as Map<String, dynamic>;

    expect(signals['categoryTimeSessionCount'], 205);
    expect(signals['categoryTimeSessionsOmitted'], 5);
    expect(signals['categoryTimeSessions'], hasLength(200));
    final recent = signals['categoryTimeSessions'] as List;
    expect(
      (recent.first as Map<String, dynamic>)['startedAtLocal'],
      sessions[5].dateFrom.toIso8601String(),
      reason: 'the bounded sample must retain the most recent raw sessions',
    );
    final summary =
        (signals['categoryTimeLifetimeSummary'] as List).single
            as Map<String, dynamic>;
    expect(summary['sessionCount'], 205);
    expect(summary['totalMinutes'], 205 * 30);
  });
}
