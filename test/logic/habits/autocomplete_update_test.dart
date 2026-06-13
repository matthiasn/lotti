import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/logic/habits/autocomplete_update.dart';
import 'autocomplete_update_test_helpers.dart';

void main() {
  group('AutoComplete Rule Manipulation Tests - ', () {
    // Test data
    const healthRule = AutoCompleteRule.health(
      dataType: 'steps',
      minimum: 10000,
      title: 'Steps',
    );

    const workoutRule = AutoCompleteRule.workout(
      dataType: 'running',
      minimum: 5,
      title: 'Running',
    );

    const measurableRule = AutoCompleteRule.measurable(
      dataTypeId: 'water',
      minimum: 2000,
      title: 'Water',
    );

    const habitRule = AutoCompleteRule.habit(
      habitId: 'floss',
      title: 'Flossing',
    );

    // Root replacement is type-independent: every node type (leaf or empty
    // container) at the root is swapped wholesale for the replacement.
    const rootReplacementCases = <(String, AutoCompleteRule)>[
      ('health leaf', healthRule),
      ('workout leaf', workoutRule),
      ('measurable leaf', measurableRule),
      ('habit leaf', habitRule),
      ('empty AND', AutoCompleteRule.and(rules: [])),
      ('empty OR', AutoCompleteRule.or(rules: [])),
      ('empty MULTIPLE', AutoCompleteRule.multiple(rules: [], successes: 0)),
    ];

    for (final (description, rule) in rootReplacementCases) {
      test('replaceAtRecursive at root replaces $description wholesale', () {
        final result = replaceAtRecursive(
          rule: rule,
          replaceWith: habitRule,
          currentPath: [0],
          replaceAtPath: [0],
        );

        expect(result, habitRule);
      });
    }

    // One worked example per container type: replace one child, assert the
    // full resulting tree (which also covers sibling order and, for MULTIPLE,
    // preservation of `successes`).
    final containerReplacementCases =
        <
          ({
            String description,
            AutoCompleteRule container,
            int replaceIndex,
            AutoCompleteRule expected,
          })
        >[
          (
            description: 'AND',
            container: const AutoCompleteRule.and(
              rules: [healthRule, workoutRule],
              title: 'Health and Workout',
            ),
            replaceIndex: 0,
            expected: const AutoCompleteRule.and(
              rules: [measurableRule, workoutRule],
              title: 'Health and Workout',
            ),
          ),
          (
            description: 'OR',
            container: const AutoCompleteRule.or(
              rules: [healthRule, workoutRule],
              title: 'Health or Workout',
            ),
            replaceIndex: 1,
            expected: const AutoCompleteRule.or(
              rules: [healthRule, measurableRule],
              title: 'Health or Workout',
            ),
          ),
          (
            description: 'MULTIPLE',
            container: const AutoCompleteRule.multiple(
              rules: [healthRule, workoutRule, habitRule],
              successes: 2,
              title: 'At least 2',
            ),
            replaceIndex: 2,
            expected: const AutoCompleteRule.multiple(
              rules: [healthRule, workoutRule, measurableRule],
              successes: 2,
              title: 'At least 2',
            ),
          ),
        ];

    for (final scenario in containerReplacementCases) {
      test(
        'replaceAtRecursive replaces child ${scenario.replaceIndex} inside '
        '${scenario.description}',
        () {
          final result = replaceAtRecursive(
            rule: scenario.container,
            replaceWith: measurableRule,
            currentPath: [0],
            replaceAtPath: [0, scenario.replaceIndex],
          );

          expect(result, scenario.expected);
        },
      );
    }

    test('replaceAtRecursive with nested AND/OR rules', () {
      const nestedRule = AutoCompleteRule.and(
        rules: [
          AutoCompleteRule.or(
            rules: [healthRule, workoutRule],
          ),
          measurableRule,
        ],
      );

      final result = replaceAtRecursive(
        rule: nestedRule,
        replaceWith: habitRule,
        currentPath: [0],
        replaceAtPath: [0, 0, 1],
      );

      expect(
        result,
        const AutoCompleteRule.and(
          rules: [
            AutoCompleteRule.or(
              rules: [healthRule, habitRule],
            ),
            measurableRule,
          ],
        ),
      );
    });

    test('replaceAtRecursive with deeply nested structure', () {
      const deeplyNested = AutoCompleteRule.and(
        rules: [
          AutoCompleteRule.or(
            rules: [
              AutoCompleteRule.multiple(
                rules: [healthRule, workoutRule],
                successes: 1,
              ),
              measurableRule,
            ],
          ),
          habitRule,
        ],
      );

      const heartRateRule = AutoCompleteRule.health(
        dataType: 'heart_rate',
        minimum: 60,
      );

      final result = replaceAtRecursive(
        rule: deeplyNested,
        replaceWith: heartRateRule,
        currentPath: [0],
        replaceAtPath: [0, 0, 0, 1],
      );

      expect(
        result,
        const AutoCompleteRule.and(
          rules: [
            AutoCompleteRule.or(
              rules: [
                AutoCompleteRule.multiple(
                  rules: [healthRule, heartRateRule],
                  successes: 1,
                ),
                measurableRule,
              ],
            ),
            habitRule,
          ],
        ),
      );
    });

    test('replaceAtRecursive returns null when replacing with null', () {
      final result = replaceAtRecursive(
        rule: healthRule,
        replaceWith: null,
        currentPath: [0],
        replaceAtPath: [0],
      );

      expect(result, null);
    });

    test('replaceAtRecursive with non-matching path returns unchanged', () {
      final result = replaceAtRecursive(
        rule: healthRule,
        replaceWith: workoutRule,
        currentPath: [0, 1],
        replaceAtPath: [0],
      );

      expect(result, healthRule);
    });

    test('replaceAt helper function - simple case', () {
      final result = replaceAt(
        healthRule,
        replaceAtPath: [0],
        replaceWith: workoutRule,
      );

      expect(result, workoutRule);
    });

    test('replaceAt helper with nested structure', () {
      const nestedRule = AutoCompleteRule.and(
        rules: [healthRule, workoutRule, measurableRule],
      );

      final result = replaceAt(
        nestedRule,
        replaceAtPath: [0, 1],
        replaceWith: habitRule,
      );

      expect(
        result,
        const AutoCompleteRule.and(
          rules: [healthRule, habitRule, measurableRule],
        ),
      );
    });

    test('removeAt helper function - simple case', () {
      final result = removeAt(
        healthRule,
        path: [0],
      );

      expect(result, null);
    });

    test('removeAt helper with nested structure drops the child', () {
      const nestedRule = AutoCompleteRule.and(
        rules: [healthRule, workoutRule, measurableRule],
      );

      final result = removeAt(
        nestedRule,
        path: [0, 1],
      );

      expect(
        result,
        const AutoCompleteRule.and(
          rules: [healthRule, measurableRule],
        ),
      );
    });

    test('replaceAtRecursive filters out null values from lists', () {
      const andRule = AutoCompleteRule.and(
        rules: [healthRule, workoutRule, measurableRule],
      );

      final result = replaceAtRecursive(
        rule: andRule,
        replaceWith: null,
        currentPath: [0],
        replaceAtPath: [0, 1],
      );

      expect(
        result,
        const AutoCompleteRule.and(
          rules: [healthRule, measurableRule],
        ),
      );
    });

    test(
      'null rule input: replace returns replacement, remove returns null',
      () {
        expect(
          replaceAtRecursive(
            rule: null,
            replaceWith: healthRule,
            currentPath: [0],
            replaceAtPath: [0],
          ),
          healthRule,
        );
        expect(
          replaceAt(null, replaceAtPath: [0], replaceWith: healthRule),
          healthRule,
        );
        expect(removeAt(null, path: [0]), null);
      },
    );

    glados.Glados(
      glados.any.autoCompleteRuleScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test('matches generated replacement and removal tree invariants', (
      scenario,
    ) {
      final rule = scenario.rule;

      expect(
        replaceAt(
          rule,
          replaceAtPath: scenario.targetPath,
          replaceWith: scenario.replacement,
        ),
        scenario.expectedReplacement,
        reason: '$scenario',
      );

      expect(
        removeAt(rule, path: scenario.targetPath),
        scenario.expectedRemoval,
        reason: '$scenario',
      );

      expect(
        replaceAt(
          rule,
          replaceAtPath: scenario.missingPath,
          replaceWith: scenario.replacement,
        ),
        rule,
        reason: '$scenario',
      );
    }, tags: 'glados');
  });

  group('Edit Autocomplete Rule Tests - realistic nested structure', () {
    // Named building blocks for a realistic deeply nested rule tree. The
    // tests below compose both the input tree and the expected result from
    // these constants, so the asserted difference is explicit instead of
    // restating an entire 60-line literal per test.
    const pushUps = AutoCompleteRule.measurable(
      dataTypeId: 'push-ups',
      minimum: 25,
    );
    const pullUps = AutoCompleteRule.measurable(
      dataTypeId: 'pull-ups',
      minimum: 10,
    );
    const sitUps = AutoCompleteRule.measurable(
      dataTypeId: 'sit-ups',
      minimum: 70,
    );
    const lunges = AutoCompleteRule.measurable(
      dataTypeId: 'lunges',
      minimum: 30,
    );
    const plank = AutoCompleteRule.measurable(
      dataTypeId: 'plank',
      minimum: 70,
    );
    const squats = AutoCompleteRule.measurable(
      dataTypeId: 'squats',
      minimum: 10,
    );
    const allExercises = [pushUps, pullUps, sitUps, lunges, plank, squats];

    const gymWorkout = AutoCompleteRule.workout(
      dataType: 'functionalStrengthTraining.duration',
      title: 'Gym workout without tracking exercises',
      minimum: 30,
    );

    const cardioOr = AutoCompleteRule.or(
      title: 'Daily Cardio',
      rules: [
        AutoCompleteRule.health(
          dataType: 'cumulative_step_count',
          minimum: 10000,
        ),
        AutoCompleteRule.workout(dataType: 'walking.duration', minimum: 60),
        AutoCompleteRule.workout(dataType: 'swimming.duration', minimum: 20),
        AutoCompleteRule.workout(dataType: 'cycling.duration', minimum: 120),
      ],
    );

    const hydration = AutoCompleteRule.measurable(
      dataTypeId: 'water',
      minimum: 2000,
      title: 'Stay hydrated.',
    );

    AutoCompleteRule buildTree({
      List<AutoCompleteRule> exercises = allExercises,
      bool includeHydration = true,
    }) {
      return AutoCompleteRule.and(
        title: 'Physical Exercises and Hydration',
        rules: [
          AutoCompleteRule.or(
            title: 'Body weight exercises or Gym',
            rules: [
              AutoCompleteRule.multiple(
                successes: 5,
                title: 'Daily body weight exercises',
                rules: exercises,
              ),
              gymWorkout,
            ],
          ),
          cardioOr,
          if (includeHydration) hydration,
        ],
      );
    }

    final testAutoComplete = buildTree();

    test('Remove top level rule returns null', () {
      expect(removeAt(testAutoComplete, path: [0]), null);
    });

    test('Remove last rule in top level AND: hydration', () {
      expect(
        removeAt(testAutoComplete, path: [0, 2]),
        buildTree(includeHydration: false),
      );
    });

    test('Remove deeply nested pull-ups rule', () {
      expect(
        removeAt(testAutoComplete, path: [0, 0, 0, 1]),
        buildTree(exercises: const [pushUps, sitUps, lunges, plank, squats]),
      );
    });

    test('Replace deeply nested pull-ups rule with harder minimum', () {
      const harderPullUps = AutoCompleteRule.measurable(
        dataTypeId: 'pull-ups',
        minimum: 18,
      );

      expect(
        replaceAt(
          testAutoComplete,
          replaceAtPath: [0, 0, 0, 1],
          replaceWith: harderPullUps,
        ),
        buildTree(
          exercises: const [
            pushUps,
            harderPullUps,
            sitUps,
            lunges,
            plank,
            squats,
          ],
        ),
      );
    });
  });
}
