import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/logic/habits/autocomplete_update.dart';

class _GeneratedAutoCompleteRuleScenario {
  const _GeneratedAutoCompleteRuleScenario({
    required this.depth,
    required this.seed,
    required this.pathIndex,
    required this.replacementSeed,
  });

  final int depth;
  final int seed;
  final int pathIndex;
  final int replacementSeed;

  AutoCompleteRule get rule => _buildRule(depth: depth, seed: seed);

  AutoCompleteRule get replacement => _leafRule(replacementSeed + 100000);

  List<List<int>> get validPaths => _rulePaths(rule);

  List<int> get targetPath => validPaths[pathIndex % validPaths.length];

  AutoCompleteRule? get expectedReplacement =>
      _replaceExpected(rule, targetPath, replacement);

  AutoCompleteRule? get expectedRemoval =>
      _replaceExpected(rule, targetPath, null);

  List<int> get missingPath => const [0, 99];

  @override
  String toString() {
    return '_GeneratedAutoCompleteRuleScenario('
        'depth: $depth, '
        'seed: $seed, '
        'targetPath: $targetPath, '
        'replacementSeed: $replacementSeed)';
  }
}

extension _AnyGeneratedAutoCompleteRuleScenario on glados.Any {
  glados.Generator<_GeneratedAutoCompleteRuleScenario>
  get autoCompleteRuleScenario => glados.CombinableAny(this).combine4(
    glados.IntAnys(this).intInRange(0, 4),
    glados.IntAnys(this).intInRange(0, 10000),
    glados.IntAnys(this).intInRange(0, 10000),
    glados.IntAnys(this).intInRange(0, 10000),
    (
      int depth,
      int seed,
      int pathIndex,
      int replacementSeed,
    ) => _GeneratedAutoCompleteRuleScenario(
      depth: depth,
      seed: seed,
      pathIndex: pathIndex,
      replacementSeed: replacementSeed,
    ),
  );
}

AutoCompleteRule _buildRule({
  required int depth,
  required int seed,
}) {
  if (depth == 0) return _leafRule(seed);

  return switch (seed % 7) {
    0 || 1 || 2 || 3 => _leafRule(seed),
    4 => AutoCompleteRule.and(
      rules: _childRules(depth: depth, seed: seed),
      title: 'and-$seed',
    ),
    5 => AutoCompleteRule.or(
      rules: _childRules(depth: depth, seed: seed),
      title: 'or-$seed',
    ),
    _ => AutoCompleteRule.multiple(
      rules: _childRules(depth: depth, seed: seed),
      successes: (seed % 3) + 1,
      title: 'multiple-$seed',
    ),
  };
}

List<AutoCompleteRule> _childRules({
  required int depth,
  required int seed,
}) {
  final childCount = seed % 4;
  return [
    for (var index = 0; index < childCount; index++)
      _buildRule(depth: depth - 1, seed: seed * 31 + index + 1),
  ];
}

AutoCompleteRule _leafRule(int seed) {
  return switch (seed % 4) {
    0 => AutoCompleteRule.health(
      dataType: 'health-$seed',
      minimum: seed % 100,
      title: 'health-title-$seed',
    ),
    1 => AutoCompleteRule.workout(
      dataType: 'workout-$seed',
      maximum: seed % 200,
      title: 'workout-title-$seed',
    ),
    2 => AutoCompleteRule.measurable(
      dataTypeId: 'measurable-$seed',
      minimum: seed % 300,
      maximum: (seed % 300) + 10,
      title: 'measurable-title-$seed',
    ),
    _ => AutoCompleteRule.habit(
      habitId: 'habit-$seed',
      title: 'habit-title-$seed',
    ),
  };
}

List<List<int>> _rulePaths(AutoCompleteRule rule) {
  final paths = <List<int>>[
    [0],
  ];

  void visit(AutoCompleteRule current, List<int> prefix) {
    final children = _childrenOf(current);
    if (children == null) return;

    for (final (index, child) in children.indexed) {
      final childPath = [...prefix, index];
      paths.add(childPath);
      visit(child, childPath);
    }
  }

  visit(rule, [0]);
  return paths;
}

List<AutoCompleteRule>? _childrenOf(AutoCompleteRule rule) {
  if (rule is AutoCompleteRuleAnd) return rule.rules;
  if (rule is AutoCompleteRuleOr) return rule.rules;
  if (rule is AutoCompleteRuleMultiple) return rule.rules;
  return null;
}

AutoCompleteRule _copyWithChildren(
  AutoCompleteRule rule,
  List<AutoCompleteRule> children,
) {
  if (rule is AutoCompleteRuleAnd) {
    return AutoCompleteRule.and(rules: children, title: rule.title);
  }
  if (rule is AutoCompleteRuleOr) {
    return AutoCompleteRule.or(rules: children, title: rule.title);
  }
  final multiple = rule as AutoCompleteRuleMultiple;
  return AutoCompleteRule.multiple(
    rules: children,
    successes: multiple.successes,
    title: multiple.title,
  );
}

AutoCompleteRule? _replaceExpected(
  AutoCompleteRule rule,
  List<int> path,
  AutoCompleteRule? replacement,
) {
  if (path.length == 1 && path.first == 0) return replacement;
  if (path.isEmpty || path.first != 0) return rule;
  return _replaceDescendant(rule, path.sublist(1), replacement);
}

AutoCompleteRule _replaceDescendant(
  AutoCompleteRule rule,
  List<int> descendantPath,
  AutoCompleteRule? replacement,
) {
  if (descendantPath.isEmpty) return replacement ?? rule;

  final children = _childrenOf(rule);
  final childIndex = descendantPath.first;
  if (children == null || childIndex < 0 || childIndex >= children.length) {
    return rule;
  }

  final updatedChild = descendantPath.length == 1
      ? replacement
      : _replaceDescendant(
          children[childIndex],
          descendantPath.sublist(1),
          replacement,
        );
  final updatedChildren = <AutoCompleteRule>[];

  for (final (index, child) in children.indexed) {
    if (index == childIndex) {
      if (updatedChild != null) updatedChildren.add(updatedChild);
    } else {
      updatedChildren.add(child);
    }
  }

  return _copyWithChildren(rule, updatedChildren);
}

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
