import 'package:flutter/foundation.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/logic/signals/signal_day_buckets.dart';
import 'package:lotti/logic/signals/signal_window.dart';

/// Clears numeric bounds from measurable leaves whose definitions now record
/// choices.
///
/// A choice measurement stores `value: 1` as an occurrence marker. Applying a
/// bound authored while the measurable was numeric would compare that marker
/// with the old quantity and make the runtime disagree with the editor's
/// choice-only "any entry" rule. The tree shape, titles, and every other leaf
/// remain unchanged.
AutoCompleteRule normalizeChoiceMeasurableBounds(
  AutoCompleteRule rule, {
  required bool Function(String dataTypeId) isChoice,
}) {
  switch (rule) {
    case final AutoCompleteRuleMeasurable measurable:
      if (!isChoice(measurable.dataTypeId) ||
          (measurable.minimum == null && measurable.maximum == null)) {
        return rule;
      }
      return measurable.copyWith(minimum: null, maximum: null);
    case final AutoCompleteRuleAnd composite:
      final originalRules = composite.rules;
      final rules = _normalizeChoiceChildren(originalRules, isChoice);
      return identical(rules, originalRules)
          ? rule
          : composite.copyWith(rules: rules);
    case final AutoCompleteRuleOr composite:
      final originalRules = composite.rules;
      final rules = _normalizeChoiceChildren(originalRules, isChoice);
      return identical(rules, originalRules)
          ? rule
          : composite.copyWith(rules: rules);
    case final AutoCompleteRuleMultiple composite:
      final originalRules = composite.rules;
      final rules = _normalizeChoiceChildren(originalRules, isChoice);
      return identical(rules, originalRules)
          ? rule
          : composite.copyWith(rules: rules);
    case AutoCompleteRuleHealth() ||
        AutoCompleteRuleWorkout() ||
        AutoCompleteRuleHabit():
      return rule;
  }
}

List<AutoCompleteRule> _normalizeChoiceChildren(
  List<AutoCompleteRule> rules,
  bool Function(String dataTypeId) isChoice,
) {
  var changed = false;
  final normalized = [
    for (final rule in rules)
      () {
        final next = normalizeChoiceMeasurableBounds(
          rule,
          isChoice: isChoice,
        );
        changed = changed || !identical(next, rule);
        return next;
      }(),
  ];
  return changed ? normalized : rules;
}

/// What one leaf of an [AutoCompleteRule] tree saw on the evaluated day.
///
/// [value] is the aggregate that the thresholds were compared against — the
/// day's value or its trailing seven-day average, according to the rule. It is
/// `null` when the selected basis has no data (or the leaf has no numeric
/// value, as for "any workout" and habit leaves). [present] says whether the
/// evaluated day itself has an entry, which is what "any entry" rules use.
@immutable
class HabitLeafVerdict {
  const HabitLeafVerdict({
    required this.rule,
    required this.satisfied,
    required this.present,
    this.value,
    this.todayValue,
    this.sevenDayAverage,
  });

  final AutoCompleteRule rule;
  final bool satisfied;
  final bool present;
  final num? value;

  /// The evaluated calendar day's own aggregate, independent of [value].
  final num? todayValue;

  /// The trailing seven-day mean ending on the evaluated day.
  final num? sevenDayAverage;

  @override
  bool operator ==(Object other) =>
      other is HabitLeafVerdict &&
      other.rule == rule &&
      other.satisfied == satisfied &&
      other.present == present &&
      other.value == value &&
      other.todayValue == todayValue &&
      other.sevenDayAverage == sevenDayAverage;

  @override
  int get hashCode => Object.hash(
    rule,
    satisfied,
    present,
    value,
    todayValue,
    sevenDayAverage,
  );

  @override
  String toString() =>
      'HabitLeafVerdict($rule, satisfied: $satisfied, present: $present, '
      'value: $value, today: $todayValue, average: $sevenDayAverage)';
}

/// The outcome of evaluating a whole rule tree for one day.
class HabitRuleVerdict {
  const HabitRuleVerdict({required this.satisfied, required this.leaves});

  final bool satisfied;

  /// Every leaf in tree order, so the completion sheet can show one status
  /// pill per associated signal and the engine can name what fired.
  final List<HabitLeafVerdict> leaves;

  /// The leaves that were satisfied, in tree order.
  Iterable<HabitLeafVerdict> get satisfiedLeaves =>
      leaves.where((leaf) => leaf.satisfied);
}

/// Decides whether a habit's [AutoCompleteRule] tree is satisfied on a day.
///
/// Pure and table-driven: everything it needs is in the [SignalWindow], so
/// the engine, the completion sheet and the tests all agree on "done".
///
/// Leaf semantics:
/// - measurable: the day's total must exist and lie within `minimum` /
///   `maximum`; with neither bound set any entry satisfies the leaf;
/// - health: the same over the day's aggregated reading;
/// - workout: with `valueType` unset any workout of the type satisfies the
///   leaf; with it set the day's summed dimension is compared to the bounds;
/// - habit: another habit's latest completion that day was a success;
/// - `and` / `or` / `multiple(successes)` combine their children.
class HabitRuleEvaluator {
  const HabitRuleEvaluator();

  HabitRuleVerdict evaluate({
    required AutoCompleteRule rule,
    required SignalWindow window,
    required DateTime day,
  }) {
    final key = signalDayKey(day);
    final leaves = <HabitLeafVerdict>[];
    final satisfied = _visit(rule, window, key, leaves);
    return HabitRuleVerdict(satisfied: satisfied, leaves: leaves);
  }

  bool _visit(
    AutoCompleteRule rule,
    SignalWindow window,
    DateTime day,
    List<HabitLeafVerdict> leaves,
  ) {
    switch (rule) {
      case AutoCompleteRuleMeasurable(
        :final dataTypeId,
        :final minimum,
        :final maximum,
        :final valueBasis,
      ):
        final values = window.measurableTotalsByDay[dataTypeId] ?? const {};
        return _numericLeaf(
          rule,
          values,
          day,
          minimum,
          maximum,
          valueBasis,
          leaves,
        );
      case AutoCompleteRuleHealth(
        :final dataType,
        :final minimum,
        :final maximum,
        :final valueBasis,
      ):
        final values = window.quantitativeByDay[dataType] ?? const {};
        return _numericLeaf(
          rule,
          values,
          day,
          minimum,
          maximum,
          valueBasis,
          leaves,
        );
      case AutoCompleteRuleWorkout(
        :final dataType,
        :final minimum,
        :final maximum,
        :final valueType,
        :final valueBasis,
      ):
        final workouts = window.workoutsByDay[dataType]?[day] ?? const [];
        if (valueType == null) {
          final present = workouts.isNotEmpty;
          leaves.add(
            HabitLeafVerdict(rule: rule, satisfied: present, present: present),
          );
          return present;
        }
        final values = <DateTime, num>{
          for (final entry
              in (window.workoutsByDay[dataType] ?? const {}).entries)
            if (entry.value.isNotEmpty)
              entry.key: entry.value
                  .map((workout) => workoutSignalValue(workout, valueType))
                  .fold<num>(0, (sum, value) => sum + value),
        };
        return _numericLeaf(
          rule,
          values,
          day,
          minimum,
          maximum,
          valueBasis,
          leaves,
        );
      case AutoCompleteRuleHabit(:final habitId):
        final done = window.habitSuccessDays[habitId]?.contains(day) ?? false;
        leaves.add(
          HabitLeafVerdict(rule: rule, satisfied: done, present: done),
        );
        return done;
      case AutoCompleteRuleAnd(:final rules):
        // Evaluate every child so each leaf gets a verdict; no short-circuit.
        return rules
            .map((child) => _visit(child, window, day, leaves))
            .toList()
            .every((satisfied) => satisfied);
      case AutoCompleteRuleOr(:final rules):
        return rules
            .map((child) => _visit(child, window, day, leaves))
            .toList()
            .any((satisfied) => satisfied);
      case AutoCompleteRuleMultiple(:final rules, :final successes):
        final count = rules
            .map((child) => _visit(child, window, day, leaves))
            .where((satisfied) => satisfied)
            .length;
        return count >= successes;
    }
  }

  bool _numericLeaf(
    AutoCompleteRule rule,
    Map<DateTime, num> valuesByDay,
    DateTime day,
    num? minimum,
    num? maximum,
    HabitSignalValueBasis valueBasis,
    List<HabitLeafVerdict> leaves,
  ) {
    final todayValue = valuesByDay[day];
    // "Any reading" remains today's presence check. A stored basis only
    // affects bounded rules, so older behavior cannot change invisibly when a
    // threshold is removed.
    if (minimum == null && maximum == null) {
      final present = todayValue != null;
      leaves.add(
        HabitLeafVerdict(
          rule: rule,
          satisfied: present,
          present: present,
          value: todayValue,
          todayValue: todayValue,
        ),
      );
      return present;
    }

    final average = trailingAverageOn(valuesByDay, day: day);
    final todaySatisfied = _within(todayValue, minimum, maximum);
    final averageSatisfied = _within(average, minimum, maximum);
    final (satisfied, value) = switch (valueBasis) {
      HabitSignalValueBasis.today => (todaySatisfied, todayValue),
      HabitSignalValueBasis.sevenDayAverage => (averageSatisfied, average),
      HabitSignalValueBasis.todayOrSevenDayAverage =>
        todaySatisfied ? (true, todayValue) : (averageSatisfied, average),
    };
    final present = todayValue != null;
    leaves.add(
      HabitLeafVerdict(
        rule: rule,
        satisfied: satisfied,
        present: present,
        value: value,
        todayValue: todayValue,
        sevenDayAverage: average,
      ),
    );
    return satisfied;
  }

  bool _within(num? value, num? minimum, num? maximum) =>
      value != null &&
      (minimum == null || value >= minimum) &&
      (maximum == null || value <= maximum);
}
