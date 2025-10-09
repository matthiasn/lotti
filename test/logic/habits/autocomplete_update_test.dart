import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/logic/habits/autocomplete_update.dart';

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

    test('replaceAtRecursive with health rule returns rule unchanged', () {
      final result = replaceAtRecursive(
        rule: healthRule,
        replaceWith: workoutRule,
        currentPath: [0],
        replaceAtPath: [0],
      );

      expect(result, workoutRule);
    });

    test('replaceAtRecursive with workout rule returns rule unchanged', () {
      final result = replaceAtRecursive(
        rule: workoutRule,
        replaceWith: healthRule,
        currentPath: [0],
        replaceAtPath: [0],
      );

      expect(result, healthRule);
    });

    test('replaceAtRecursive with measurable rule returns rule unchanged', () {
      final result = replaceAtRecursive(
        rule: measurableRule,
        replaceWith: healthRule,
        currentPath: [0],
        replaceAtPath: [0],
      );

      expect(result, healthRule);
    });

    test('replaceAtRecursive with habit rule returns rule unchanged', () {
      final result = replaceAtRecursive(
        rule: habitRule,
        replaceWith: healthRule,
        currentPath: [0],
        replaceAtPath: [0],
      );

      expect(result, healthRule);
    });

    test('replaceAtRecursive with AND rule - simple replacement', () {
      const andRule = AutoCompleteRule.and(
        rules: [healthRule, workoutRule],
        title: 'Health and Workout',
      );

      final result = replaceAtRecursive(
        rule: andRule,
        replaceWith: measurableRule,
        currentPath: [0],
        replaceAtPath: [0, 0],
      );

      expect(result, isA<AutoCompleteRuleAnd>());
      final resultAnd = result! as AutoCompleteRuleAnd;
      expect(resultAnd.rules.length, 2);
      expect(resultAnd.rules[0], measurableRule);
      expect(resultAnd.rules[1], workoutRule);
    });

    test('replaceAtRecursive with OR rule - simple replacement', () {
      const orRule = AutoCompleteRule.or(
        rules: [healthRule, workoutRule],
        title: 'Health or Workout',
      );

      final result = replaceAtRecursive(
        rule: orRule,
        replaceWith: measurableRule,
        currentPath: [0],
        replaceAtPath: [0, 1],
      );

      expect(result, isA<AutoCompleteRuleOr>());
      final resultOr = result! as AutoCompleteRuleOr;
      expect(resultOr.rules.length, 2);
      expect(resultOr.rules[0], healthRule);
      expect(resultOr.rules[1], measurableRule);
    });

    test('replaceAtRecursive with MULTIPLE rule - simple replacement', () {
      const multipleRule = AutoCompleteRule.multiple(
        rules: [healthRule, workoutRule, measurableRule],
        successes: 2,
        title: 'At least 2',
      );

      final result = replaceAtRecursive(
        rule: multipleRule,
        replaceWith: habitRule,
        currentPath: [0],
        replaceAtPath: [0, 2],
      );

      expect(result, isA<AutoCompleteRuleMultiple>());
      final resultMultiple = result! as AutoCompleteRuleMultiple;
      expect(resultMultiple.rules.length, 3);
      expect(resultMultiple.rules[0], healthRule);
      expect(resultMultiple.rules[1], workoutRule);
      expect(resultMultiple.rules[2], habitRule);
      expect(resultMultiple.successes, 2);
    });

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

      expect(result, isA<AutoCompleteRuleAnd>());
      final resultAnd = result! as AutoCompleteRuleAnd;
      expect(resultAnd.rules.length, 2);

      final firstRule = resultAnd.rules[0] as AutoCompleteRuleOr;
      expect(firstRule.rules.length, 2);
      expect(firstRule.rules[0], healthRule);
      expect(firstRule.rules[1], habitRule);
      expect(resultAnd.rules[1], measurableRule);
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

      expect(result, isA<AutoCompleteRuleAnd>());
      final resultAnd = result! as AutoCompleteRuleAnd;
      expect(resultAnd.rules[1], habitRule);
    });

    test('removeAt helper function - simple case', () {
      final result = removeAt(
        healthRule,
        path: [0],
      );

      expect(result, null);
    });

    test('removeAt helper with nested structure', () {
      const nestedRule = AutoCompleteRule.and(
        rules: [healthRule, workoutRule, measurableRule],
      );

      final result = removeAt(
        nestedRule,
        path: [0, 1],
      );

      expect(result, isA<AutoCompleteRuleAnd>());
      final resultAnd = result! as AutoCompleteRuleAnd;
      expect(resultAnd.rules.length, 2);
      expect(resultAnd.rules[0], healthRule);
      expect(resultAnd.rules[1], measurableRule);
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

      final result = replaceAtRecursive(
        rule: deeplyNested,
        replaceWith: const AutoCompleteRule.health(
          dataType: 'heart_rate',
          minimum: 60,
        ),
        currentPath: [0],
        replaceAtPath: [0, 0, 0, 1],
      );

      expect(result, isA<AutoCompleteRuleAnd>());
      final resultAnd = result! as AutoCompleteRuleAnd;
      final firstOr = resultAnd.rules[0] as AutoCompleteRuleOr;
      final firstMultiple = firstOr.rules[0] as AutoCompleteRuleMultiple;
      expect(firstMultiple.rules[1], isA<AutoCompleteRuleHealth>());
      final healthRuleReplaced =
          firstMultiple.rules[1] as AutoCompleteRuleHealth;
      expect(healthRuleReplaced.dataType, 'heart_rate');
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

      expect(result, isA<AutoCompleteRuleAnd>());
      final resultAnd = result! as AutoCompleteRuleAnd;
      expect(resultAnd.rules.length, 2);
      expect(resultAnd.rules[0], healthRule);
      expect(resultAnd.rules[1], measurableRule);
    });

    test('replaceAtRecursive handles null rule input', () {
      final result = replaceAtRecursive(
        rule: null,
        replaceWith: healthRule,
        currentPath: [0],
        replaceAtPath: [0],
      );

      expect(result, healthRule);
    });

    test('replaceAt with null rule input', () {
      final result = replaceAt(
        null,
        replaceAtPath: [0],
        replaceWith: healthRule,
      );

      expect(result, healthRule);
    });

    test('removeAt with null rule input', () {
      final result = removeAt(
        null,
        path: [0],
      );

      expect(result, null);
    });

    test('replaceAtRecursive with empty AND rule preserves structure', () {
      const emptyAnd = AutoCompleteRule.and(rules: []);

      final result = replaceAtRecursive(
        rule: emptyAnd,
        replaceWith: healthRule,
        currentPath: [0],
        replaceAtPath: [0],
      );

      expect(result, healthRule);
    });

    test('replaceAtRecursive with empty OR rule preserves structure', () {
      const emptyOr = AutoCompleteRule.or(rules: []);

      final result = replaceAtRecursive(
        rule: emptyOr,
        replaceWith: healthRule,
        currentPath: [0],
        replaceAtPath: [0],
      );

      expect(result, healthRule);
    });

    test('replaceAtRecursive with empty MULTIPLE rule preserves structure', () {
      const emptyMultiple = AutoCompleteRule.multiple(
        rules: [],
        successes: 0,
      );

      final result = replaceAtRecursive(
        rule: emptyMultiple,
        replaceWith: healthRule,
        currentPath: [0],
        replaceAtPath: [0],
      );

      expect(result, healthRule);
    });
  });
}
