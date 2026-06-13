import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/sync/vector_clock.dart';

enum GeneratedAutoCompleteRuleKind {
  health,
  workout,
  measurable,
  habit,
  and,
  or,
  multiple,
}

class GeneratedChecklistCorrectionExample {
  const GeneratedChecklistCorrectionExample({
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
    return 'GeneratedChecklistCorrectionExample('
        'before: "$before", '
        'after: "$after", '
        'capturedAtSlot: $capturedAtSlot)';
  }
}

class GeneratedAutoCompleteRule {
  const GeneratedAutoCompleteRule({
    required this.kind,
    required this.dataSlot,
    required this.minimumSlot,
    required this.maximumSlot,
    required this.titleSlot,
    required this.successes,
    required this.childASlot,
    required this.childBSlot,
  });

  final GeneratedAutoCompleteRuleKind kind;
  final int dataSlot;
  final int minimumSlot;
  final int maximumSlot;
  final int titleSlot;
  final int successes;
  final int childASlot;
  final int childBSlot;

  AutoCompleteRule get rule => switch (kind) {
    GeneratedAutoCompleteRuleKind.health => AutoCompleteRule.health(
      dataType: 'HealthDataType.$dataSlot',
      minimum: hOptionalNum(minimumSlot),
      maximum: hOptionalNum(maximumSlot),
      title: hOptionalText(titleSlot, 'Health'),
    ),
    GeneratedAutoCompleteRuleKind.workout => AutoCompleteRule.workout(
      dataType: 'WorkoutType.$dataSlot',
      minimum: hOptionalNum(minimumSlot),
      maximum: hOptionalNum(maximumSlot),
      title: hOptionalText(titleSlot, 'Workout'),
    ),
    GeneratedAutoCompleteRuleKind.measurable => AutoCompleteRule.measurable(
      dataTypeId: 'measurable-$dataSlot',
      minimum: hOptionalNum(minimumSlot),
      maximum: hOptionalNum(maximumSlot),
      title: hOptionalText(titleSlot, 'Measurable'),
    ),
    GeneratedAutoCompleteRuleKind.habit => AutoCompleteRule.habit(
      habitId: 'habit-$dataSlot',
      title: hOptionalText(titleSlot, 'Habit'),
    ),
    GeneratedAutoCompleteRuleKind.and => AutoCompleteRule.and(
      rules: [hLeafRule(childASlot), hLeafRule(childBSlot)],
      title: hOptionalText(titleSlot, 'And'),
    ),
    GeneratedAutoCompleteRuleKind.or => AutoCompleteRule.or(
      rules: [hLeafRule(childASlot), hLeafRule(childBSlot)],
      title: hOptionalText(titleSlot, 'Or'),
    ),
    GeneratedAutoCompleteRuleKind.multiple => AutoCompleteRule.multiple(
      rules: [hLeafRule(childASlot), hLeafRule(childBSlot)],
      successes: successes,
      title: hOptionalText(titleSlot, 'Multiple'),
    ),
  };

  @override
  String toString() {
    return 'GeneratedAutoCompleteRule('
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

extension AnyEntityDefinitions on glados.Any {
  glados.Generator<String> get _entityDefinitionText =>
      glados.AnyUtils(this).choose(const [
        '',
        'test flight',
        'TestFlight',
        'with "quotes"',
        r'with \ slash',
        'line\nbreak',
      ]);

  glados.Generator<GeneratedChecklistCorrectionExample>
  get generatedChecklistCorrectionExample =>
      glados.CombinableAny(this).combine3(
        _entityDefinitionText,
        _entityDefinitionText,
        glados.IntAnys(this).intInRange(0, 240),
        (
          String before,
          String after,
          int capturedAtSlot,
        ) => GeneratedChecklistCorrectionExample(
          before: before,
          after: after,
          capturedAtSlot: capturedAtSlot,
        ),
      );

  glados.Generator<GeneratedAutoCompleteRuleKind> get _autoCompleteRuleKind =>
      glados.AnyUtils(this).choose(GeneratedAutoCompleteRuleKind.values);

  glados.Generator<GeneratedAutoCompleteRule> get generatedAutoCompleteRule =>
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
          GeneratedAutoCompleteRuleKind kind,
          int dataSlot,
          int minimumSlot,
          int maximumSlot,
          int titleSlot,
          int successes,
          int childASlot,
          int childBSlot,
        ) => GeneratedAutoCompleteRule(
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

AutoCompleteRule hLeafRule(int slot) {
  return switch (slot % 4) {
    0 => AutoCompleteRule.health(
      dataType: 'HealthDataType.child$slot',
      minimum: hOptionalNum(slot),
      maximum: hOptionalNum(slot + 1),
      title: hOptionalText(slot, 'Child health'),
    ),
    1 => AutoCompleteRule.workout(
      dataType: 'WorkoutType.child$slot',
      minimum: hOptionalNum(slot),
      maximum: hOptionalNum(slot + 1),
      title: hOptionalText(slot, 'Child workout'),
    ),
    2 => AutoCompleteRule.measurable(
      dataTypeId: 'child-measurable-$slot',
      minimum: hOptionalNum(slot),
      maximum: hOptionalNum(slot + 1),
      title: hOptionalText(slot, 'Child measurable'),
    ),
    _ => AutoCompleteRule.habit(
      habitId: 'child-habit-$slot',
      title: hOptionalText(slot, 'Child habit'),
    ),
  };
}

num? hOptionalNum(int slot) => slot % 3 == 0 ? null : slot * 10;

String? hOptionalText(int slot, String prefix) {
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

enum GeneratedDashboardItemKind {
  measurement,
  healthChart,
  workoutChart,
  habitChart,
  surveyChart,
}

enum GeneratedEntityDefinitionKind {
  measurableDataType,
  categoryDefinition,
  labelDefinition,
  habit,
  dashboard,
}

class GeneratedDashboardItem {
  const GeneratedDashboardItem({
    required this.kind,
    required this.idSlot,
    required this.colorSlot,
    required this.aggregationSlot,
    required this.workoutValueSlot,
  });

  final GeneratedDashboardItemKind kind;
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
    GeneratedDashboardItemKind.measurement => DashboardItem.measurement(
      id: 'dt-$idSlot',
      aggregationType: _aggregationType,
    ),
    GeneratedDashboardItemKind.healthChart => DashboardItem.healthChart(
      color: _colors[colorSlot % _colors.length],
      healthType: 'HealthDataType.TYPE_$idSlot',
    ),
    GeneratedDashboardItemKind.workoutChart => DashboardItem.workoutChart(
      workoutType: 'HKWorkoutActivityType$idSlot',
      displayName: 'Workout $idSlot',
      color: _colors[colorSlot % _colors.length],
      valueType: _workoutValueType,
    ),
    GeneratedDashboardItemKind.habitChart => DashboardItem.habitChart(
      habitId: 'habit-$idSlot',
    ),
    GeneratedDashboardItemKind.surveyChart => DashboardItem.surveyChart(
      colorsByScoreKey: {'score-$idSlot': _colors[colorSlot % _colors.length]},
      surveyType: 'Survey$idSlot',
      surveyName: 'Survey Name $idSlot',
    ),
  };

  @override
  String toString() => 'GeneratedDashboardItem(kind: $kind, idSlot: $idSlot)';
}

class GeneratedEntityDefinition {
  const GeneratedEntityDefinition({
    required this.kind,
    required this.idSlot,
    required this.dateSlot,
    required this.nameSlot,
    required this.hasVectorClock,
    required this.scheduleKindSlot,
    required this.itemCountSlot,
    required this.optionalsSlot,
  });

  final GeneratedEntityDefinitionKind kind;
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
    GeneratedEntityDefinitionKind.measurableDataType =>
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
    GeneratedEntityDefinitionKind.categoryDefinition =>
      EntityDefinition.categoryDefinition(
        id: 'cat-$idSlot',
        createdAt: _date,
        updatedAt: _date,
        name: 'Category $nameSlot',
        vectorClock: _vc,
        private: optionalsSlot.isOdd,
        active: optionalsSlot.isEven,
        isAvailableForDayPlan: optionalsSlot % 3 == 0
            ? null
            : optionalsSlot.isEven,
        color: optionalsSlot % 3 == 0
            ? null
            : '#${idSlot.toRadixString(16).padLeft(6, '0')}',
        defaultLanguageCode: optionalsSlot % 4 == 0 ? null : 'en',
        speechDictionary: optionalsSlot.isEven
            ? null
            : ['word-$idSlot', 'word-${idSlot + 1}'],
      ),
    GeneratedEntityDefinitionKind.labelDefinition =>
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
    GeneratedEntityDefinitionKind.habit => EntityDefinition.habit(
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
    GeneratedEntityDefinitionKind.dashboard => EntityDefinition.dashboard(
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
      'GeneratedEntityDefinition(kind: $kind, idSlot: $idSlot, '
      'nameSlot: $nameSlot, optionalsSlot: $optionalsSlot)';
}

extension AnyEntityDefinitionExtended on glados.Any {
  glados.Generator<GeneratedDashboardItemKind> get _dashboardItemKind =>
      glados.AnyUtils(this).choose(GeneratedDashboardItemKind.values);

  glados.Generator<GeneratedEntityDefinitionKind> get _entityDefinitionKind =>
      glados.AnyUtils(this).choose(GeneratedEntityDefinitionKind.values);

  glados.Generator<GeneratedDashboardItem> get generatedDashboardItem =>
      glados.CombinableAny(this).combine5(
        _dashboardItemKind,
        glados.IntAnys(this).intInRange(0, 40),
        glados.IntAnys(this).intInRange(0, 3),
        glados.IntAnys(this).intInRange(0, 4),
        glados.IntAnys(this).intInRange(0, 2),
        (kind, idSlot, colorSlot, aggregationSlot, workoutValueSlot) =>
            GeneratedDashboardItem(
              kind: kind,
              idSlot: idSlot,
              colorSlot: colorSlot,
              aggregationSlot: aggregationSlot,
              workoutValueSlot: workoutValueSlot,
            ),
      );

  glados.Generator<GeneratedEntityDefinition> get generatedEntityDefinition =>
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
        ) => GeneratedEntityDefinition(
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
