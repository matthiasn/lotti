import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/sync/vector_clock.dart';

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

  // -------------------------------------------------------------------------
  // DashboardItem — all 5 variants
  // -------------------------------------------------------------------------
  group('DashboardItem JSON round-trips — static examples', () {
    DashboardItem roundTrip(DashboardItem item) => DashboardItem.fromJson(
      jsonDecode(jsonEncode(item.toJson())) as Map<String, dynamic>,
    );

    test('DashboardItem.measurement round-trips', () {
      const item = DashboardItem.measurement(id: 'dt-1');
      final decoded = roundTrip(item);
      expect(decoded, item, reason: 'measurement item round-trip');
      expect((decoded as DashboardMeasurementItem).id, 'dt-1');
    });

    test('DashboardItem.measurement with aggregationType round-trips', () {
      const item = DashboardItem.measurement(
        id: 'dt-2',
        aggregationType: AggregationType.dailySum,
      );
      final decoded = roundTrip(item);
      expect(decoded, item);
      expect(
        (decoded as DashboardMeasurementItem).aggregationType,
        AggregationType.dailySum,
      );
    });

    test('DashboardItem.healthChart round-trips', () {
      const item = DashboardItem.healthChart(
        color: '#FF0000',
        healthType: 'HealthDataType.STEPS',
      );
      final decoded = roundTrip(item);
      expect(decoded, item, reason: 'healthChart item round-trip');
      expect((decoded as DashboardHealthItem).color, '#FF0000');
    });

    test('DashboardItem.workoutChart round-trips', () {
      const item = DashboardItem.workoutChart(
        workoutType: 'HKWorkoutActivityTypeRunning',
        displayName: 'Running',
        color: '#00FF00',
        valueType: WorkoutValueType.distance,
      );
      final decoded = roundTrip(item);
      expect(decoded, item, reason: 'workoutChart item round-trip');
      expect(
        (decoded as DashboardWorkoutItem).valueType,
        WorkoutValueType.distance,
      );
    });

    test('DashboardItem.habitChart round-trips', () {
      const item = DashboardItem.habitChart(habitId: 'habit-abc');
      final decoded = roundTrip(item);
      expect(decoded, item, reason: 'habitChart item round-trip');
      expect((decoded as DashboardHabitItem).habitId, 'habit-abc');
    });

    test('DashboardItem.surveyChart round-trips', () {
      const item = DashboardItem.surveyChart(
        colorsByScoreKey: {'stress': '#FF6600', 'energy': '#00CCFF'},
        surveyType: 'PHQ9',
        surveyName: 'PHQ-9 Depression',
      );
      final decoded = roundTrip(item);
      expect(decoded, item, reason: 'surveyChart item round-trip');
      expect(
        (decoded as DashboardSurveyItem).colorsByScoreKey,
        {'stress': '#FF6600', 'energy': '#00CCFF'},
      );
    });
  });

  // -------------------------------------------------------------------------
  // EntityDefinition — all 5 variants
  // -------------------------------------------------------------------------
  group('EntityDefinition JSON round-trips — static examples', () {
    final date = DateTime(2024, 1, 15, 9);
    const vc = VectorClock({'node-1': 5});

    EntityDefinition roundTrip(EntityDefinition def) =>
        EntityDefinition.fromJson(
          jsonDecode(jsonEncode(def.toJson())) as Map<String, dynamic>,
        );

    test('MeasurableDataType round-trips', () {
      final def = EntityDefinition.measurableDataType(
        id: 'mdt-1',
        createdAt: date,
        updatedAt: date,
        displayName: 'Weight',
        description: 'Body weight in kg',
        unitName: 'kg',
        version: 1,
        vectorClock: vc,
        aggregationType: AggregationType.dailyAvg,
        private: false,
        favorite: true,
        categoryId: 'cat-health',
      );
      final decoded = roundTrip(def);
      expect(decoded, def, reason: 'MeasurableDataType round-trip');
      final typed = decoded as MeasurableDataType;
      expect(typed.displayName, 'Weight');
      expect(typed.unitName, 'kg');
      expect(typed.aggregationType, AggregationType.dailyAvg);
      expect(typed.vectorClock?.vclock, {'node-1': 5});
    });

    test('MeasurableDataType with null vectorClock round-trips', () {
      final def = EntityDefinition.measurableDataType(
        id: 'mdt-2',
        createdAt: date,
        updatedAt: date,
        displayName: 'Steps',
        description: 'Step count',
        unitName: 'steps',
        version: 2,
        vectorClock: null,
      );
      final decoded = roundTrip(def);
      expect(decoded, def);
      expect((decoded as MeasurableDataType).vectorClock, isNull);
    });

    test('CategoryDefinition round-trips', () {
      final def = EntityDefinition.categoryDefinition(
        id: 'cat-1',
        createdAt: date,
        updatedAt: date,
        name: 'Health',
        vectorClock: vc,
        private: false,
        active: true,
        favorite: true,
        color: '#336699',
        defaultLanguageCode: 'en',
        speechDictionary: ['kg', 'steps', 'HR'],
      );
      final decoded = roundTrip(def);
      expect(decoded, def, reason: 'CategoryDefinition round-trip');
      final typed = decoded as CategoryDefinition;
      expect(typed.name, 'Health');
      expect(typed.speechDictionary, ['kg', 'steps', 'HR']);
    });

    test('LabelDefinition round-trips', () {
      final def = EntityDefinition.labelDefinition(
        id: 'lbl-1',
        createdAt: date,
        updatedAt: date,
        name: 'Urgent',
        color: '#FF0000',
        vectorClock: vc,
        description: 'High priority label',
        sortOrder: 1,
        applicableCategoryIds: ['cat-1', 'cat-2'],
      );
      final decoded = roundTrip(def);
      expect(decoded, def, reason: 'LabelDefinition round-trip');
      final typed = decoded as LabelDefinition;
      expect(typed.name, 'Urgent');
      expect(typed.sortOrder, 1);
      expect(typed.applicableCategoryIds, ['cat-1', 'cat-2']);
    });

    test('HabitDefinition round-trips with daily schedule', () {
      final def = EntityDefinition.habit(
        id: 'habit-1',
        createdAt: date,
        updatedAt: date,
        name: 'Exercise',
        description: 'Daily workout',
        habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
        vectorClock: vc,
        active: true,
        private: false,
        categoryId: 'cat-health',
      );
      final decoded = roundTrip(def);
      expect(decoded, def, reason: 'HabitDefinition round-trip');
      final typed = decoded as HabitDefinition;
      expect(typed.name, 'Exercise');
      final schedule = typed.habitSchedule as DailyHabitSchedule;
      expect(schedule.requiredCompletions, 1);
    });

    test('HabitDefinition with autoCompleteRule round-trips', () {
      final def = EntityDefinition.habit(
        id: 'habit-2',
        createdAt: date,
        updatedAt: date,
        name: 'Sleep',
        description: 'Sleep tracking',
        habitSchedule: const HabitSchedule.weekly(requiredCompletions: 5),
        vectorClock: null,
        active: true,
        private: false,
        autoCompleteRule: const AutoCompleteRule.health(
          dataType: 'HealthDataType.SLEEP_ASLEEP',
          minimum: 420,
        ),
      );
      final decoded = roundTrip(def);
      expect(
        decoded,
        def,
        reason: 'HabitDefinition with autoComplete round-trip',
      );
      final typed = decoded as HabitDefinition;
      expect(typed.autoCompleteRule, isNotNull);
    });

    test('DashboardDefinition with @Default(30) days round-trips', () {
      final def = EntityDefinition.dashboard(
        id: 'dash-1',
        createdAt: date,
        updatedAt: date,
        lastReviewed: date,
        name: 'Health Dashboard',
        description: 'Overview',
        items: const [
          DashboardItem.measurement(id: 'dt-1'),
          DashboardItem.habitChart(habitId: 'habit-1'),
        ],
        version: '1.0',
        vectorClock: vc,
        active: true,
        private: false,
      );
      final decoded = roundTrip(def);
      expect(decoded, def, reason: 'DashboardDefinition round-trip');
      final typed = decoded as DashboardDefinition;
      expect(typed.days, 30, reason: '@Default(30) preserved');
      expect(typed.items.length, 2);
      expect(typed.items[0], const DashboardItem.measurement(id: 'dt-1'));
    });

    test('DashboardDefinition with custom days survives round-trip', () {
      final def = EntityDefinition.dashboard(
        id: 'dash-2',
        createdAt: date,
        updatedAt: date,
        lastReviewed: date,
        name: 'Weekly',
        description: 'Weekly view',
        items: const [],
        version: '2.0',
        vectorClock: null,
        active: false,
        private: true,
        days: 7,
        reviewAt: DateTime(2024, 6, 30),
        categoryId: 'cat-productivity',
      );
      final decoded = roundTrip(def);
      expect(decoded, def, reason: 'DashboardDefinition days=7 round-trip');
      expect((decoded as DashboardDefinition).days, 7);
    });
  });

  // -------------------------------------------------------------------------
  // DashboardItem and EntityDefinition Glados round-trips
  // -------------------------------------------------------------------------
  group('DashboardItem Glados round-trips', () {
    glados.Glados(
      glados.any.generatedDashboardItem,
      glados.ExploreConfig(numRuns: 120),
    ).test('DashboardItem round-trips through JSON', (scenario) {
      final item = scenario.item;
      final decoded = DashboardItem.fromJson(
        jsonDecode(jsonEncode(item.toJson())) as Map<String, dynamic>,
      );
      expect(decoded, item, reason: '$scenario');
    }, tags: 'glados');
  });

  group('EntityDefinition Glados round-trips', () {
    glados.Glados(
      glados.any.generatedEntityDefinition,
      glados.ExploreConfig(),
    ).test('EntityDefinition round-trips through JSON', (scenario) {
      final def = scenario.definition;
      final decoded = EntityDefinition.fromJson(
        jsonDecode(jsonEncode(def.toJson())) as Map<String, dynamic>,
      );
      expect(decoded, def, reason: '$scenario');
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

// ---------------------------------------------------------------------------
// DashboardItem and EntityDefinition generators.
// ---------------------------------------------------------------------------

enum _GeneratedDashboardItemKind {
  measurement,
  healthChart,
  workoutChart,
  habitChart,
  surveyChart,
}

enum _GeneratedEntityDefinitionKind {
  measurableDataType,
  categoryDefinition,
  labelDefinition,
  habit,
  dashboard,
}

class _GeneratedDashboardItem {
  const _GeneratedDashboardItem({
    required this.kind,
    required this.idSlot,
    required this.colorSlot,
    required this.aggregationSlot,
    required this.workoutValueSlot,
  });

  final _GeneratedDashboardItemKind kind;
  final int idSlot;
  final int colorSlot;
  final int aggregationSlot;
  final int workoutValueSlot;

  static const _colors = ['#FF0000', '#00FF00', '#0000FF', '#FFAA00'];

  AggregationType? get _aggregationType {
    if (aggregationSlot % 5 == 0) return null;
    return AggregationType.values[aggregationSlot %
        AggregationType.values.length];
  }

  WorkoutValueType get _workoutValueType =>
      WorkoutValueType.values[workoutValueSlot %
          WorkoutValueType.values.length];

  DashboardItem get item => switch (kind) {
    _GeneratedDashboardItemKind.measurement => DashboardItem.measurement(
      id: 'dt-$idSlot',
      aggregationType: _aggregationType,
    ),
    _GeneratedDashboardItemKind.healthChart => DashboardItem.healthChart(
      color: _colors[colorSlot % _colors.length],
      healthType: 'HealthDataType.TYPE_$idSlot',
    ),
    _GeneratedDashboardItemKind.workoutChart => DashboardItem.workoutChart(
      workoutType: 'HKWorkoutActivityType$idSlot',
      displayName: 'Workout $idSlot',
      color: _colors[colorSlot % _colors.length],
      valueType: _workoutValueType,
    ),
    _GeneratedDashboardItemKind.habitChart => DashboardItem.habitChart(
      habitId: 'habit-$idSlot',
    ),
    _GeneratedDashboardItemKind.surveyChart => DashboardItem.surveyChart(
      colorsByScoreKey: {'score-$idSlot': _colors[colorSlot % _colors.length]},
      surveyType: 'Survey$idSlot',
      surveyName: 'Survey Name $idSlot',
    ),
  };

  @override
  String toString() => '_GeneratedDashboardItem(kind: $kind, idSlot: $idSlot)';
}

class _GeneratedEntityDefinition {
  const _GeneratedEntityDefinition({
    required this.kind,
    required this.idSlot,
    required this.dateSlot,
    required this.nameSlot,
    required this.hasVectorClock,
    required this.scheduleKindSlot,
    required this.itemCountSlot,
    required this.optionalsSlot,
  });

  final _GeneratedEntityDefinitionKind kind;
  final int idSlot;
  final int dateSlot;
  final int nameSlot;
  final bool hasVectorClock;
  final int scheduleKindSlot;
  final int itemCountSlot;
  final int optionalsSlot;

  DateTime get _date =>
      DateTime.utc(2024, (dateSlot % 12) + 1, (dateSlot % 28) + 1);

  VectorClock? get _vc =>
      hasVectorClock ? VectorClock({'node-$idSlot': optionalsSlot % 20}) : null;

  EntityDefinition get definition => switch (kind) {
    _GeneratedEntityDefinitionKind.measurableDataType =>
      EntityDefinition.measurableDataType(
        id: 'mdt-$idSlot',
        createdAt: _date,
        updatedAt: _date,
        displayName: 'Measurable $nameSlot',
        description: 'Desc $nameSlot',
        unitName: 'unit-$nameSlot',
        version: optionalsSlot % 5 + 1,
        vectorClock: _vc,
        aggregationType: optionalsSlot.isEven
            ? null
            : AggregationType.values[optionalsSlot %
                  AggregationType.values.length],
        private: optionalsSlot % 3 == 0 ? null : optionalsSlot.isOdd,
        favorite: optionalsSlot % 4 == 0 ? null : optionalsSlot.isEven,
        categoryId: optionalsSlot % 5 == 0 ? null : 'cat-$idSlot',
      ),
    _GeneratedEntityDefinitionKind.categoryDefinition =>
      EntityDefinition.categoryDefinition(
        id: 'cat-$idSlot',
        createdAt: _date,
        updatedAt: _date,
        name: 'Category $nameSlot',
        vectorClock: _vc,
        private: optionalsSlot.isOdd,
        active: optionalsSlot.isEven,
        color: optionalsSlot % 3 == 0
            ? null
            : '#${idSlot.toRadixString(16).padLeft(6, '0')}',
        defaultLanguageCode: optionalsSlot % 4 == 0 ? null : 'en',
        speechDictionary: optionalsSlot.isEven
            ? null
            : ['word-$idSlot', 'word-${idSlot + 1}'],
      ),
    _GeneratedEntityDefinitionKind.labelDefinition =>
      EntityDefinition.labelDefinition(
        id: 'lbl-$idSlot',
        createdAt: _date,
        updatedAt: _date,
        name: 'Label $nameSlot',
        color: '#${nameSlot.toRadixString(16).padLeft(6, '0').substring(0, 6)}',
        vectorClock: _vc,
        description: optionalsSlot % 3 == 0 ? null : 'Desc $nameSlot',
        sortOrder: optionalsSlot % 4 == 0 ? null : optionalsSlot,
        applicableCategoryIds: optionalsSlot % 5 == 0 ? null : ['cat-$idSlot'],
        private: optionalsSlot.isOdd ? null : false,
      ),
    _GeneratedEntityDefinitionKind.habit => EntityDefinition.habit(
      id: 'habit-$idSlot',
      createdAt: _date,
      updatedAt: _date,
      name: 'Habit $nameSlot',
      description: 'Habit desc $nameSlot',
      habitSchedule: switch (scheduleKindSlot % 3) {
        0 => HabitSchedule.daily(requiredCompletions: (optionalsSlot % 3) + 1),
        1 => HabitSchedule.weekly(requiredCompletions: (optionalsSlot % 5) + 1),
        _ => HabitSchedule.monthly(
          requiredCompletions: (optionalsSlot % 4) + 1,
        ),
      },
      vectorClock: _vc,
      active: optionalsSlot.isEven,
      private: optionalsSlot.isOdd,
      categoryId: optionalsSlot % 3 == 0 ? null : 'cat-$idSlot',
      priority: optionalsSlot % 4 == 0 ? null : optionalsSlot.isEven,
    ),
    _GeneratedEntityDefinitionKind.dashboard => EntityDefinition.dashboard(
      id: 'dash-$idSlot',
      createdAt: _date,
      updatedAt: _date,
      lastReviewed: _date,
      name: 'Dashboard $nameSlot',
      description: 'Dashboard desc $nameSlot',
      items: List.generate(
        itemCountSlot % 3,
        (i) => DashboardItem.measurement(id: 'dt-$idSlot-$i'),
      ),
      version: '${optionalsSlot % 5}.0',
      vectorClock: _vc,
      active: optionalsSlot.isEven,
      private: optionalsSlot.isOdd,
      days: optionalsSlot.isEven ? 30 : (optionalsSlot % 90) + 1,
      categoryId: optionalsSlot % 4 == 0 ? null : 'cat-$idSlot',
    ),
  };

  @override
  String toString() =>
      '_GeneratedEntityDefinition(kind: $kind, idSlot: $idSlot, '
      'nameSlot: $nameSlot, optionalsSlot: $optionalsSlot)';
}

extension _AnyEntityDefinitionExtended on glados.Any {
  glados.Generator<_GeneratedDashboardItemKind> get _dashboardItemKind =>
      glados.AnyUtils(this).choose(_GeneratedDashboardItemKind.values);

  glados.Generator<_GeneratedEntityDefinitionKind> get _entityDefinitionKind =>
      glados.AnyUtils(this).choose(_GeneratedEntityDefinitionKind.values);

  glados.Generator<_GeneratedDashboardItem> get generatedDashboardItem =>
      glados.CombinableAny(this).combine5(
        _dashboardItemKind,
        glados.IntAnys(this).intInRange(0, 40),
        glados.IntAnys(this).intInRange(0, 3),
        glados.IntAnys(this).intInRange(0, 4),
        glados.IntAnys(this).intInRange(0, 2),
        (kind, idSlot, colorSlot, aggregationSlot, workoutValueSlot) =>
            _GeneratedDashboardItem(
              kind: kind,
              idSlot: idSlot,
              colorSlot: colorSlot,
              aggregationSlot: aggregationSlot,
              workoutValueSlot: workoutValueSlot,
            ),
      );

  glados.Generator<_GeneratedEntityDefinition> get generatedEntityDefinition =>
      glados.CombinableAny(this).combine8(
        _entityDefinitionKind,
        glados.IntAnys(this).intInRange(0, 40),
        glados.IntAnys(this).intInRange(0, 40),
        glados.IntAnys(this).intInRange(0, 40),
        glados.any.bool,
        glados.IntAnys(this).intInRange(0, 2),
        glados.IntAnys(this).intInRange(0, 3),
        glados.IntAnys(this).intInRange(0, 15),
        (
          kind,
          idSlot,
          dateSlot,
          nameSlot,
          hasVectorClock,
          scheduleKindSlot,
          itemCountSlot,
          optionalsSlot,
        ) => _GeneratedEntityDefinition(
          kind: kind,
          idSlot: idSlot,
          dateSlot: dateSlot,
          nameSlot: nameSlot,
          hasVectorClock: hasVectorClock,
          scheduleKindSlot: scheduleKindSlot,
          itemCountSlot: itemCountSlot,
          optionalsSlot: optionalsSlot,
        ),
      );
}
