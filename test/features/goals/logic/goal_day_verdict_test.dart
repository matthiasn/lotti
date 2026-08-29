import 'package:flutter_test/flutter_test.dart';
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
}
