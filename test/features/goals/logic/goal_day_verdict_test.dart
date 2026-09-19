import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/features/goals/logic/goal_day_verdict.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';

void main() {
  final today = DateTime.utc(2026, 8, 11);
  final yesterday = today.subtract(const Duration(days: 1));

  GoalProgressDay hit(DateTime day) => GoalProgressDay(day: day, value: 1);
  GoalProgressDay miss(DateTime day) => GoalProgressDay(day: day, value: 0);
  GoalProgressDay unobserved(DateTime day) =>
      GoalProgressDay(day: day, value: 0, isObserved: false);

  GoalHabitProgressView habit(String id, List<GoalProgressDay> days) =>
      GoalHabitProgressView(
        habitId: id,
        name: id,
        targetCount: 7,
        days: days,
        successfulWeeks: 0,
      );

  GoalMetricProgressView steps(List<GoalProgressDay> days) =>
      GoalMetricProgressView(
        name: 'Steps',
        target: 10000,
        days: days,
      );

  group('suggestedDayVerdict', () {
    test('every criterion met suggests Met', () {
      final progress = GoalProgressView(
        today: today,
        habits: [
          habit('gym', [hit(yesterday), hit(today)]),
        ],
        metrics: [
          steps([
            GoalProgressDay(day: yesterday, value: 12000),
            GoalProgressDay(day: today, value: 11000),
          ]),
        ],
      );

      expect(suggestedDayVerdict(progress, today), DayVerdict.met);
    });

    test('logged everything and met nothing suggests Missed', () {
      final progress = GoalProgressView(
        today: today,
        habits: [
          habit('gym', [miss(today)]),
        ],
        metrics: [
          steps([GoalProgressDay(day: today, value: 3000)]),
        ],
      );

      // The steps day IS observed — the user logged and fell short. That is a
      // real Missed, unlike a day nobody recorded.
      expect(suggestedDayVerdict(progress, today), DayVerdict.missed);
    });

    test('a day with no observations at all suggests nothing', () {
      final progress = GoalProgressView(
        today: today,
        habits: [
          habit('gym', [miss(today)]),
        ],
        metrics: [
          steps([unobserved(today)]),
        ],
      );

      // Suggesting Missed here would be the app passing judgement on its own
      // blind spot: nothing was recorded, so nothing is known.
      expect(suggestedDayVerdict(progress, today), isNull);
    });

    test('more met than yesterday suggests Improving, otherwise Mixed', () {
      GoalProgressView progressWith({required bool betterThanYesterday}) =>
          GoalProgressView(
            today: today,
            habits: [
              habit('gym', [
                if (betterThanYesterday) miss(yesterday) else hit(yesterday),
                hit(today),
              ]),
            ],
            metrics: [
              steps([
                GoalProgressDay(day: yesterday, value: 3000),
                GoalProgressDay(day: today, value: 4000),
              ]),
            ],
          );

      // One of two met today either way. What separates the two verdicts is
      // yesterday — which is precisely the distinction a three-way Met/Mixed/
      // Missed could not express.
      expect(
        suggestedDayVerdict(progressWith(betterThanYesterday: true), today),
        DayVerdict.improving,
      );
      expect(
        suggestedDayVerdict(progressWith(betterThanYesterday: false), today),
        DayVerdict.mixed,
      );
    });

    test('a deliberately recorded failure is evidence, not silence', () {
      final progress = GoalProgressView(
        today: today,
        habits: [
          GoalHabitProgressView(
            habitId: 'gym',
            name: 'gym',
            targetCount: 7,
            days: [
              GoalProgressDay(
                day: today,
                value: 0,
                habitCompletionType: HabitCompletionType.fail,
              ),
            ],
            successfulWeeks: 0,
          ),
        ],
      );

      // A logged failure carries no value, so checking `hasValue` alone read
      // a day the user explicitly marked as missed as a day they never
      // opened — and the sheet then fell back to suggesting Met.
      expect(suggestedDayVerdict(progress, today), DayVerdict.missed);
    });

    test('improving needs a day to have improved on', () {
      final progress = GoalProgressView(
        today: today,
        habits: [
          habit('gym', [hit(today)]),
        ],
        metrics: [
          steps([GoalProgressDay(day: today, value: 3000)]),
        ],
      );

      // One of two met today and NOTHING recorded yesterday. Yesterday's zero
      // is missing data, not a worse day, so calling today an improvement on
      // it would invent the baseline — and then record that invention as a
      // suggestion the user accepted.
      expect(suggestedDayVerdict(progress, today), DayVerdict.mixed);
    });

    test('a goal with nothing tracked suggests nothing', () {
      expect(
        suggestedDayVerdict(GoalProgressView(today: today), today),
        isNull,
      );
    });

    test('an at-most metric is met by staying under its target', () {
      final progress = GoalProgressView(
        today: today,
        metrics: [
          GoalMetricProgressView(
            name: 'Screen time',
            target: 60,
            direction: GoalDirection.atMost,
            days: [GoalProgressDay(day: today, value: 45)],
          ),
        ],
      );

      expect(suggestedDayVerdict(progress, today), DayVerdict.met);
    });
  });

  group('goalDayOutcome', () {
    test(
      'an unrecorded criterion counts toward the total, never toward met',
      () {
        final progress = GoalProgressView(
          today: today,
          habits: [
            habit('gym', [hit(today)]),
            habit('read', const []),
          ],
        );

        // "Not recorded" is not "met": a day nobody logged must never read as a
        // clean sweep.
        expect(goalDayOutcome(progress, today), (met: 1, total: 2));
      },
    );
  });

  group('properties', () {
    // Local calendar days, including the days after the EU and US DST
    // switches, where "yesterday" is not 24 hours back.
    final day = glados.any.choose([
      DateTime(2026, 3, 9),
      DateTime(2026, 3, 30),
      DateTime(2026, 6, 15),
      DateTime(2026, 10, 26),
      DateTime(2026, 11, 2),
    ]);
    // Per criterion and day: 0 absent, 1 hit, 2 miss, 3 unobserved.
    final marks = glados.any.combine2(
      glados.any.intInRange(0, 4),
      glados.any.intInRange(0, 4),
      (int yesterday, int today) => (yesterday: yesterday, today: today),
    );

    glados.Glados3(
      day,
      glados.any.listWithLengthInRange(0, 4, marks),
      glados.any.listWithLengthInRange(0, 3, marks),
      glados.ExploreConfig(numRuns: 300),
    ).test(
      'the suggestion follows the documented rules on every calendar day',
      (day, habitMarks, metricMarks) {
        final previous = DateTime(day.year, day.month, day.day - 1);

        List<GoalProgressDay> habitDays(({int yesterday, int today}) m) => [
          for (final (at, mark) in [(previous, m.yesterday), (day, m.today)])
            if (mark == 1) hit(at) else if (mark != 0) miss(at),
        ];
        List<GoalProgressDay> metricDays(({int yesterday, int today}) m) => [
          for (final (at, mark) in [(previous, m.yesterday), (day, m.today)])
            if (mark == 1)
              GoalProgressDay(day: at, value: 12000)
            else if (mark == 2)
              GoalProgressDay(day: at, value: 3000)
            else if (mark == 3)
              unobserved(at),
        ];

        final progress = GoalProgressView(
          today: day,
          habits: [
            for (final (i, m) in habitMarks.indexed)
              habit('habit-$i', habitDays(m)),
          ],
          metrics: [for (final m in metricMarks) steps(metricDays(m))],
        );

        // Evidence: a habit done, or a metric observed (hit or short).
        bool evidence(int Function(({int yesterday, int today})) pick) =>
            habitMarks.any((m) => pick(m) == 1) ||
            metricMarks.any((m) => pick(m) == 1 || pick(m) == 2);
        final todayHasEvidence = evidence((m) => m.today);
        final yesterdayHasEvidence = evidence((m) => m.yesterday);

        final outcome = goalDayOutcome(progress, day);
        final before = goalDayOutcome(progress, previous);
        expect(outcome.total, habitMarks.length + metricMarks.length);
        expect(outcome.met, inInclusiveRange(0, outcome.total));

        final expected =
            outcome.total == 0 || outcome.met == 0 && !todayHasEvidence
            ? null
            : outcome.met == outcome.total
            ? DayVerdict.met
            : outcome.met == 0
            ? DayVerdict.missed
            : yesterdayHasEvidence && outcome.met > before.met
            ? DayVerdict.improving
            : DayVerdict.mixed;
        expect(suggestedDayVerdict(progress, day), expected);
      },
      tags: 'glados',
    );
  });
}
