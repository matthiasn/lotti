import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/logic/signals/habit_rule_evaluator.dart';
import 'package:lotti/logic/signals/signal_window.dart';

import 'signal_test_fixtures.dart';

void main() {
  const evaluator = HabitRuleEvaluator();
  final today = DateTime(2026, 8, 8, 15, 30);
  final todayKey = DateTime.utc(2026, 8, 8);
  final yesterdayKey = DateTime.utc(2026, 8, 7);

  SignalWindow window({
    Map<String, Map<DateTime, num>> measurables = const {},
    Map<String, Map<DateTime, num>> quantitative = const {},
    Map<String, Map<DateTime, List<WorkoutData>>> workouts = const {},
    Map<String, Set<DateTime>> habits = const {},
  }) => SignalWindow(
    start: DateTime.utc(2026, 7, 26),
    end: todayKey,
    measurableTotalsByDay: measurables,
    quantitativeByDay: quantitative,
    workoutsByDay: workouts,
    habitSuccessDays: habits,
  );

  HabitRuleVerdict eval(AutoCompleteRule rule, SignalWindow w) =>
      evaluator.evaluate(rule: rule, window: w, day: today);

  group('choice measurable normalization', () {
    test('clears stale bounds recursively and preserves every other rule', () {
      const numeric = AutoCompleteRule.measurable(
        dataTypeId: 'water',
        minimum: 500,
        title: 'Water',
      );
      const choice = AutoCompleteRule.measurable(
        dataTypeId: 'hydration',
        minimum: 2,
        maximum: 4,
        title: 'Hydration',
      );
      const rule = AutoCompleteRule.and(
        rules: [
          numeric,
          AutoCompleteRule.or(
            rules: [
              choice,
              AutoCompleteRule.health(
                dataType: 'cumulative_step_count',
                minimum: 5000,
              ),
            ],
          ),
        ],
      );
      final originalNested =
          (rule as AutoCompleteRuleAnd).rules.last as AutoCompleteRuleOr;

      final normalized =
          normalizeChoiceMeasurableBounds(
                rule,
                isChoice: (id) => id == 'hydration',
              )
              as AutoCompleteRuleAnd;
      expect(normalized.rules.first, same(numeric));
      final nested = normalized.rules.last as AutoCompleteRuleOr;
      expect(
        nested.rules.first,
        const AutoCompleteRule.measurable(
          dataTypeId: 'hydration',
          title: 'Hydration',
        ),
      );
      expect(
        nested.rules.last,
        same(originalNested.rules.last),
      );
    });

    test('returns the original tree when no choice bound needs changing', () {
      const rule = AutoCompleteRule.multiple(
        rules: [AutoCompleteRule.measurable(dataTypeId: 'water')],
        successes: 1,
      );

      expect(
        normalizeChoiceMeasurableBounds(rule, isChoice: (_) => true),
        same(rule),
      );
    });
  });

  group('measurable leaf', () {
    const anyEntry = AutoCompleteRule.measurable(dataTypeId: 'water');
    const atLeast = AutoCompleteRule.measurable(
      dataTypeId: 'water',
      minimum: 1000,
    );
    const atMost = AutoCompleteRule.measurable(
      dataTypeId: 'coffee',
      maximum: 2,
    );

    test('"any entry" is satisfied by a recorded zero but not by nothing', () {
      final recordedZero = window(
        measurables: {
          'water': {todayKey: 0},
        },
      );
      expect(eval(anyEntry, recordedZero).satisfied, isTrue);
      expect(eval(anyEntry, recordedZero).leaves.single.value, 0);

      final nothing = window(
        measurables: {
          'water': {yesterdayKey: 750},
        },
      );
      final verdict = eval(anyEntry, nothing);
      expect(verdict.satisfied, isFalse);
      expect(verdict.leaves.single.present, isFalse);
      expect(verdict.leaves.single.value, isNull);
    });

    test('a minimum needs the day total to reach it', () {
      expect(
        eval(
          atLeast,
          window(
            measurables: {
              'water': {todayKey: 999},
            },
          ),
        ).satisfied,
        isFalse,
      );
      expect(
        eval(
          atLeast,
          window(
            measurables: {
              'water': {todayKey: 1000},
            },
          ),
        ).satisfied,
        isTrue,
      );
    });

    test(
      'a maximum still requires an entry — silence is not "≤ 2 coffees"',
      () {
        expect(eval(atMost, window()).satisfied, isFalse);
        expect(
          eval(
            atMost,
            window(
              measurables: {
                'coffee': {todayKey: 2},
              },
            ),
          ).satisfied,
          isTrue,
        );
        expect(
          eval(
            atMost,
            window(
              measurables: {
                'coffee': {todayKey: 3},
              },
            ),
          ).satisfied,
          isFalse,
        );
      },
    );
  });

  group('health leaf', () {
    const steps = AutoCompleteRule.health(
      dataType: 'cumulative_step_count',
      minimum: 6000,
    );

    test('reports the day value so the UI can say "4,120 so far"', () {
      final verdict = eval(
        steps,
        window(
          quantitative: {
            'cumulative_step_count': {todayKey: 4120},
          },
        ),
      );
      expect(verdict.satisfied, isFalse);
      expect(verdict.leaves.single.value, 4120);
      expect(verdict.leaves.single.present, isTrue);
    });

    test('today basis checks only today even when the weekly mean passes', () {
      final verdict = eval(
        steps,
        window(
          quantitative: {
            'cumulative_step_count': {
              for (var offset = 6; offset >= 1; offset--)
                todayKey.subtract(Duration(days: offset)): 7000,
              todayKey: 4000,
            },
          },
        ),
      );
      expect(verdict.satisfied, isFalse);
      expect(verdict.leaves.single.value, 4000);
      expect(verdict.leaves.single.sevenDayAverage, greaterThan(6000));
    });

    test('7-day average basis can pass while today is below the threshold', () {
      const averageSteps = AutoCompleteRule.health(
        dataType: 'cumulative_step_count',
        minimum: 6000,
        valueBasis: HabitSignalValueBasis.sevenDayAverage,
      );
      final verdict = eval(
        averageSteps,
        window(
          quantitative: {
            'cumulative_step_count': {
              for (var offset = 6; offset >= 1; offset--)
                todayKey.subtract(Duration(days: offset)): 7000,
              todayKey: 4000,
            },
          },
        ),
      );
      expect(verdict.satisfied, isTrue);
      expect(verdict.leaves.single.todayValue, 4000);
      expect(verdict.leaves.single.value, closeTo(6571.43, 0.01));
    });

    test('either basis passes when today or the rolling average passes', () {
      const eitherSteps = AutoCompleteRule.health(
        dataType: 'cumulative_step_count',
        minimum: 6000,
        valueBasis: HabitSignalValueBasis.todayOrSevenDayAverage,
      );
      final averageOnly = eval(
        eitherSteps,
        window(
          quantitative: {
            'cumulative_step_count': {
              for (var offset = 6; offset >= 1; offset--)
                todayKey.subtract(Duration(days: offset)): 7000,
              todayKey: 4000,
            },
          },
        ),
      );
      final todayOnly = eval(
        eitherSteps,
        window(
          quantitative: {
            'cumulative_step_count': {
              for (var offset = 6; offset >= 1; offset--)
                todayKey.subtract(Duration(days: offset)): 1000,
              todayKey: 7000,
            },
          },
        ),
      );

      expect(averageOnly.satisfied, isTrue);
      expect(averageOnly.leaves.single.value, closeTo(6571.43, 0.01));
      expect(todayOnly.satisfied, isTrue);
      expect(todayOnly.leaves.single.value, 7000);
    });
  });

  group('workout leaf', () {
    WorkoutData run(Duration length, {num? distance}) =>
        (workoutEntity(
                  DateTime(2026, 8, 8, 7),
                  length: length,
                  distance: distance,
                )
                as WorkoutEntry)
            .data;

    test(
      '"any workout" is satisfied by presence alone and carries no value',
      () {
        const any = AutoCompleteRule.workout(dataType: 'running');
        final verdict = eval(
          any,
          window(
            workouts: {
              'running': {
                todayKey: [run(const Duration(minutes: 5))],
              },
            },
          ),
        );
        expect(verdict.satisfied, isTrue);
        expect(verdict.leaves.single.value, isNull);
        expect(eval(any, window()).satisfied, isFalse);
      },
    );

    test(
      'a dimension threshold sums the day and compares in display units',
      () {
        const distance = AutoCompleteRule.workout(
          dataType: 'running',
          minimum: 5,
          valueType: WorkoutValueType.distance,
        );
        final verdict = eval(
          distance,
          window(
            workouts: {
              'running': {
                todayKey: [
                  run(const Duration(minutes: 20), distance: 3000),
                  run(const Duration(minutes: 20), distance: 2500),
                ],
              },
            },
          ),
        );
        expect(verdict.satisfied, isTrue);
        expect(verdict.leaves.single.value, 5.5);

        const duration = AutoCompleteRule.workout(
          dataType: 'running',
          minimum: 30,
          valueType: WorkoutValueType.duration,
        );
        expect(
          eval(
            duration,
            window(
              workouts: {
                'running': {
                  todayKey: [run(const Duration(minutes: 29))],
                },
              },
            ),
          ).satisfied,
          isFalse,
        );
      },
    );

    test('a thresholded rule with no workout is absent, not zero', () {
      const energy = AutoCompleteRule.workout(
        dataType: 'running',
        minimum: 1,
        valueType: WorkoutValueType.energy,
      );
      final verdict = eval(energy, window());
      expect(verdict.satisfied, isFalse);
      expect(verdict.leaves.single.present, isFalse);
      expect(verdict.leaves.single.value, isNull);
    });
  });

  group('habit leaf', () {
    test('is done when the other habit succeeded that day', () {
      const rule = AutoCompleteRule.habit(habitId: 'habit-a');
      expect(
        eval(
          rule,
          window(
            habits: {
              'habit-a': {todayKey},
            },
          ),
        ).satisfied,
        isTrue,
      );
      expect(
        eval(
          rule,
          window(
            habits: {
              'habit-a': {yesterdayKey},
            },
          ),
        ).satisfied,
        isFalse,
      );
    });
  });

  group('HabitLeafVerdict value semantics', () {
    const rule = AutoCompleteRule.measurable(dataTypeId: 'water');
    const a = HabitLeafVerdict(
      rule: rule,
      satisfied: true,
      present: true,
      value: 750,
    );

    test('equal fields are equal and hash alike', () {
      const b = HabitLeafVerdict(
        rule: rule,
        satisfied: true,
        present: true,
        value: 750,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('each field participates in equality', () {
      expect(
        a,
        isNot(
          const HabitLeafVerdict(
            rule: rule,
            satisfied: false,
            present: true,
            value: 750,
          ),
        ),
      );
      expect(
        a,
        isNot(
          const HabitLeafVerdict(
            rule: rule,
            satisfied: true,
            present: false,
            value: 750,
          ),
        ),
      );
      expect(
        a,
        isNot(
          const HabitLeafVerdict(rule: rule, satisfied: true, present: true),
        ),
      );
      expect(
        a,
        isNot(
          const HabitLeafVerdict(
            rule: AutoCompleteRule.measurable(dataTypeId: 'coffee'),
            satisfied: true,
            present: true,
            value: 750,
          ),
        ),
      );
    });

    test('toString names the fields', () {
      expect(a.toString(), contains('water'));
      expect(a.toString(), contains('satisfied: true'));
      expect(a.toString(), contains('value: 750'));
    });
  });

  group('composites', () {
    const a = AutoCompleteRule.measurable(dataTypeId: 'a');
    const b = AutoCompleteRule.measurable(dataTypeId: 'b');
    const c = AutoCompleteRule.measurable(dataTypeId: 'c');

    SignalWindow present(Set<String> ids) => window(
      measurables: {
        for (final id in ids) id: {todayKey: 1},
      },
    );

    test('and needs every child, or needs one, multiple needs N', () {
      const and = AutoCompleteRule.and(rules: [a, b]);
      const or = AutoCompleteRule.or(rules: [a, b]);
      const two = AutoCompleteRule.multiple(rules: [a, b, c], successes: 2);
      expect(eval(and, present({'a'})).satisfied, isFalse);
      expect(eval(and, present({'a', 'b'})).satisfied, isTrue);
      expect(eval(or, present({'b'})).satisfied, isTrue);
      expect(eval(or, present({})).satisfied, isFalse);
      expect(eval(two, present({'a'})).satisfied, isFalse);
      expect(eval(two, present({'a', 'c'})).satisfied, isTrue);
    });

    test('every leaf gets a verdict even after the composite is decided', () {
      const or = AutoCompleteRule.or(rules: [a, b, c]);
      final verdict = eval(or, present({'a'}));
      expect(verdict.leaves.map((leaf) => leaf.rule), [a, b, c]);
      expect(verdict.leaves.map((leaf) => leaf.satisfied), [
        true,
        false,
        false,
      ]);
      expect(verdict.satisfiedLeaves.map((leaf) => leaf.rule), [a]);
    });

    test('an empty and is vacuously true, an empty or is false', () {
      expect(
        eval(const AutoCompleteRule.and(rules: []), window()).satisfied,
        isTrue,
      );
      expect(
        eval(const AutoCompleteRule.or(rules: []), window()).satisfied,
        isFalse,
      );
    });
  });

  group('properties', () {
    // A leaf per bit; the window makes leaf i present iff bit i is set.
    const leaves = [
      AutoCompleteRule.measurable(dataTypeId: 'm0'),
      AutoCompleteRule.measurable(dataTypeId: 'm1'),
      AutoCompleteRule.measurable(dataTypeId: 'm2'),
      AutoCompleteRule.measurable(dataTypeId: 'm3'),
    ];

    SignalWindow fromBits(int bits) => window(
      measurables: {
        for (var i = 0; i < leaves.length; i++)
          if (bits & (1 << i) != 0) 'm$i': {todayKey: 1},
      },
    );

    glados.Glados2(
      glados.any.intInRange(0, 16),
      glados.any.intInRange(0, 5),
    ).test('multiple(N) agrees with counting satisfied leaves', (bits, n) {
      final rule = AutoCompleteRule.multiple(rules: leaves, successes: n);
      final verdict = eval(rule, fromBits(bits));
      final count = verdict.satisfiedLeaves.length;
      expect(count, bits.toRadixString(2).replaceAll('0', '').length);
      expect(verdict.satisfied, count >= n);
    }, tags: 'glados');

    glados.Glados(glados.any.intInRange(0, 16)).test(
      'and is multiple(all) and or is multiple(1)',
      (bits) {
        final w = fromBits(bits);
        expect(
          eval(const AutoCompleteRule.and(rules: leaves), w).satisfied,
          eval(
            const AutoCompleteRule.multiple(rules: leaves, successes: 4),
            w,
          ).satisfied,
        );
        expect(
          eval(const AutoCompleteRule.or(rules: leaves), w).satisfied,
          eval(
            const AutoCompleteRule.multiple(rules: leaves, successes: 1),
            w,
          ).satisfied,
        );
      },
      tags: 'glados',
    );
  });
}
