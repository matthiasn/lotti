import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';

void main() {
  group('Entity definitions tests', () {
    group('ChecklistCorrectionExample', () {
      test('can be serialized and deserialized with capturedAt', () {
        final example = ChecklistCorrectionExample(
          before: 'test flight',
          after: 'TestFlight',
          capturedAt: DateTime(2025, 1, 15, 10, 30),
        );

        final json = jsonEncode(example.toJson());
        final fromJson = ChecklistCorrectionExample.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );

        expect(fromJson.before, equals('test flight'));
        expect(fromJson.after, equals('TestFlight'));
        expect(fromJson.capturedAt, equals(DateTime(2025, 1, 15, 10, 30)));
      });

      test('can be serialized and deserialized without capturedAt', () {
        const example = ChecklistCorrectionExample(
          before: 'mac os',
          after: 'macOS',
        );

        final json = jsonEncode(example.toJson());
        final fromJson = ChecklistCorrectionExample.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );

        expect(fromJson.before, equals('mac os'));
        expect(fromJson.after, equals('macOS'));
        expect(fromJson.capturedAt, isNull);
      });

      test('supports equality', () {
        final example1 = ChecklistCorrectionExample(
          before: 'test',
          after: 'Test',
          capturedAt: DateTime(2025),
        );
        final example2 = ChecklistCorrectionExample(
          before: 'test',
          after: 'Test',
          capturedAt: DateTime(2025),
        );

        expect(example1, equals(example2));
      });

      glados.Glados(
        glados.any.generatedChecklistCorrectionExample,
        glados.ExploreConfig(numRuns: 140),
      ).test('round-trips generated correction examples through JSON', (
        scenario,
      ) {
        final example = scenario.example;

        final fromJson = ChecklistCorrectionExample.fromJson(
          jsonDecode(jsonEncode(example.toJson())) as Map<String, dynamic>,
        );

        expect(fromJson, equals(example), reason: '$scenario');
        expect(fromJson.capturedAt, example.capturedAt, reason: '$scenario');
      }, tags: 'glados');
    });

    test('Recursive autocomplete can be serialized and deserialized', () {
      const sleepAutoComplete = AutoCompleteRuleOr(
        rules: [
          AutoCompleteRule.and(
            rules: [
              AutoCompleteRuleHealth(
                dataType: 'HealthDataType.SLEEP_ASLEEP_CORE',
                minimum: 360,
              ),
              AutoCompleteRule.measurable(
                dataTypeId: 'dataTypeId',
                minimum: 2000,
              ),
            ],
          ),
          AutoCompleteRuleHealth(
            dataType: 'HealthDataType.SLEEP_ASLEEP_REM',
            minimum: 60,
          ),
        ],
      );

      final json = jsonEncode(sleepAutoComplete);
      final fromJson = AutoCompleteRule.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );

      expect(fromJson, sleepAutoComplete);
    });

    glados.Glados(
      glados.any.generatedAutoCompleteRule,
      glados.ExploreConfig(numRuns: 160),
    ).test('round-trips generated autocomplete rule trees through JSON', (
      scenario,
    ) {
      final rule = scenario.rule;

      final fromJson = AutoCompleteRule.fromJson(
        jsonDecode(jsonEncode(rule.toJson())) as Map<String, dynamic>,
      );

      expect(fromJson, equals(rule), reason: '$scenario');
    }, tags: 'glados');
  });
}

enum _GeneratedAutoCompleteRuleKind {
  health,
  workout,
  measurable,
  habit,
  and,
  or,
  multiple,
}

class _GeneratedChecklistCorrectionExample {
  const _GeneratedChecklistCorrectionExample({
    required this.before,
    required this.after,
    required this.capturedAtSlot,
  });

  final String before;
  final String after;
  final int capturedAtSlot;

  ChecklistCorrectionExample get example => ChecklistCorrectionExample(
    before: before,
    after: after,
    capturedAt: capturedAtSlot.isEven
        ? null
        : DateTime.utc(
            2025,
            (capturedAtSlot % 12) + 1,
            (capturedAtSlot % 28) + 1,
            capturedAtSlot % 24,
            capturedAtSlot % 60,
          ),
  );

  @override
  String toString() {
    return '_GeneratedChecklistCorrectionExample('
        'before: "$before", '
        'after: "$after", '
        'capturedAtSlot: $capturedAtSlot)';
  }
}

class _GeneratedAutoCompleteRule {
  const _GeneratedAutoCompleteRule({
    required this.kind,
    required this.dataSlot,
    required this.minimumSlot,
    required this.maximumSlot,
    required this.titleSlot,
    required this.successes,
    required this.childASlot,
    required this.childBSlot,
  });

  final _GeneratedAutoCompleteRuleKind kind;
  final int dataSlot;
  final int minimumSlot;
  final int maximumSlot;
  final int titleSlot;
  final int successes;
  final int childASlot;
  final int childBSlot;

  AutoCompleteRule get rule => switch (kind) {
    _GeneratedAutoCompleteRuleKind.health => AutoCompleteRule.health(
      dataType: 'HealthDataType.$dataSlot',
      minimum: _optionalNum(minimumSlot),
      maximum: _optionalNum(maximumSlot),
      title: _optionalText(titleSlot, 'Health'),
    ),
    _GeneratedAutoCompleteRuleKind.workout => AutoCompleteRule.workout(
      dataType: 'WorkoutType.$dataSlot',
      minimum: _optionalNum(minimumSlot),
      maximum: _optionalNum(maximumSlot),
      title: _optionalText(titleSlot, 'Workout'),
    ),
    _GeneratedAutoCompleteRuleKind.measurable => AutoCompleteRule.measurable(
      dataTypeId: 'measurable-$dataSlot',
      minimum: _optionalNum(minimumSlot),
      maximum: _optionalNum(maximumSlot),
      title: _optionalText(titleSlot, 'Measurable'),
    ),
    _GeneratedAutoCompleteRuleKind.habit => AutoCompleteRule.habit(
      habitId: 'habit-$dataSlot',
      title: _optionalText(titleSlot, 'Habit'),
    ),
    _GeneratedAutoCompleteRuleKind.and => AutoCompleteRule.and(
      rules: [_leafRule(childASlot), _leafRule(childBSlot)],
      title: _optionalText(titleSlot, 'And'),
    ),
    _GeneratedAutoCompleteRuleKind.or => AutoCompleteRule.or(
      rules: [_leafRule(childASlot), _leafRule(childBSlot)],
      title: _optionalText(titleSlot, 'Or'),
    ),
    _GeneratedAutoCompleteRuleKind.multiple => AutoCompleteRule.multiple(
      rules: [_leafRule(childASlot), _leafRule(childBSlot)],
      successes: successes,
      title: _optionalText(titleSlot, 'Multiple'),
    ),
  };

  @override
  String toString() {
    return '_GeneratedAutoCompleteRule('
        'kind: $kind, '
        'dataSlot: $dataSlot, '
        'minimumSlot: $minimumSlot, '
        'maximumSlot: $maximumSlot, '
        'titleSlot: $titleSlot, '
        'successes: $successes, '
        'childASlot: $childASlot, '
        'childBSlot: $childBSlot)';
  }
}

extension _AnyEntityDefinitions on glados.Any {
  glados.Generator<String> get _entityDefinitionText =>
      glados.AnyUtils(this).choose(const [
        '',
        'test flight',
        'TestFlight',
        'with "quotes"',
        r'with \ slash',
        'line\nbreak',
      ]);

  glados.Generator<_GeneratedChecklistCorrectionExample>
  get generatedChecklistCorrectionExample =>
      glados.CombinableAny(this).combine3(
        _entityDefinitionText,
        _entityDefinitionText,
        glados.IntAnys(this).intInRange(0, 240),
        (
          String before,
          String after,
          int capturedAtSlot,
        ) => _GeneratedChecklistCorrectionExample(
          before: before,
          after: after,
          capturedAtSlot: capturedAtSlot,
        ),
      );

  glados.Generator<_GeneratedAutoCompleteRuleKind> get _autoCompleteRuleKind =>
      glados.AnyUtils(this).choose(_GeneratedAutoCompleteRuleKind.values);

  glados.Generator<_GeneratedAutoCompleteRule> get generatedAutoCompleteRule =>
      glados.CombinableAny(this).combine8(
        _autoCompleteRuleKind,
        glados.IntAnys(this).intInRange(0, 40),
        glados.IntAnys(this).intInRange(0, 40),
        glados.IntAnys(this).intInRange(0, 40),
        glados.IntAnys(this).intInRange(0, 40),
        glados.IntAnys(this).intInRange(0, 4),
        glados.IntAnys(this).intInRange(0, 40),
        glados.IntAnys(this).intInRange(0, 40),
        (
          _GeneratedAutoCompleteRuleKind kind,
          int dataSlot,
          int minimumSlot,
          int maximumSlot,
          int titleSlot,
          int successes,
          int childASlot,
          int childBSlot,
        ) => _GeneratedAutoCompleteRule(
          kind: kind,
          dataSlot: dataSlot,
          minimumSlot: minimumSlot,
          maximumSlot: maximumSlot,
          titleSlot: titleSlot,
          successes: successes,
          childASlot: childASlot,
          childBSlot: childBSlot,
        ),
      );
}

AutoCompleteRule _leafRule(int slot) {
  return switch (slot % 4) {
    0 => AutoCompleteRule.health(
      dataType: 'HealthDataType.child$slot',
      minimum: _optionalNum(slot),
      maximum: _optionalNum(slot + 1),
      title: _optionalText(slot, 'Child health'),
    ),
    1 => AutoCompleteRule.workout(
      dataType: 'WorkoutType.child$slot',
      minimum: _optionalNum(slot),
      maximum: _optionalNum(slot + 1),
      title: _optionalText(slot, 'Child workout'),
    ),
    2 => AutoCompleteRule.measurable(
      dataTypeId: 'child-measurable-$slot',
      minimum: _optionalNum(slot),
      maximum: _optionalNum(slot + 1),
      title: _optionalText(slot, 'Child measurable'),
    ),
    _ => AutoCompleteRule.habit(
      habitId: 'child-habit-$slot',
      title: _optionalText(slot, 'Child habit'),
    ),
  };
}

num? _optionalNum(int slot) => slot % 3 == 0 ? null : slot * 10;

String? _optionalText(int slot, String prefix) {
  return switch (slot % 4) {
    0 => null,
    1 => '$prefix $slot',
    2 => '$prefix "$slot"',
    _ => '$prefix \\ $slot',
  };
}
