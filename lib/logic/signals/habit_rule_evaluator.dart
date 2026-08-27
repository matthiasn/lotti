import 'package:flutter/foundation.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/logic/signals/signal_day_buckets.dart';
import 'package:lotti/logic/signals/signal_window.dart';

/// What one leaf of an [AutoCompleteRule] tree saw on the evaluated day.
///
/// [value] is the day's aggregate the thresholds were compared against — a
/// measurable total, a health reading, a workout dimension in display units,
/// or `null` when nothing was recorded (or the leaf has no numeric value, as
/// for "any workout" and habit leaves). [present] says whether the day has
/// any entry at all, which is what "any entry" rules are about.
@immutable
class HabitLeafVerdict {
  const HabitLeafVerdict({
    required this.rule,
    required this.satisfied,
    required this.present,
    this.value,
  });

  final AutoCompleteRule rule;
  final bool satisfied;
  final bool present;
  final num? value;

  @override
  bool operator ==(Object other) =>
      other is HabitLeafVerdict &&
      other.rule == rule &&
      other.satisfied == satisfied &&
      other.present == present &&
      other.value == value;

  @override
  int get hashCode => Object.hash(rule, satisfied, present, value);

  @override
  String toString() =>
      'HabitLeafVerdict($rule, satisfied: $satisfied, present: $present, '
      'value: $value)';
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
      ):
        final value = window.measurableTotalsByDay[dataTypeId]?[day];
        return _leaf(rule, value, minimum, maximum, leaves);
      case AutoCompleteRuleHealth(
        :final dataType,
        :final minimum,
        :final maximum,
      ):
        final value = window.quantitativeByDay[dataType]?[day];
        return _leaf(rule, value, minimum, maximum, leaves);
      case AutoCompleteRuleWorkout(
        :final dataType,
        :final minimum,
        :final maximum,
        :final valueType,
      ):
        final workouts = window.workoutsByDay[dataType]?[day] ?? const [];
        if (valueType == null) {
          final present = workouts.isNotEmpty;
          leaves.add(
            HabitLeafVerdict(rule: rule, satisfied: present, present: present),
          );
          return present;
        }
        final value = workouts.isEmpty
            ? null
            : workouts
                  .map((workout) => workoutSignalValue(workout, valueType))
                  .fold<num>(0, (sum, value) => sum + value);
        return _leaf(rule, value, minimum, maximum, leaves);
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

  bool _leaf(
    AutoCompleteRule rule,
    num? value,
    num? minimum,
    num? maximum,
    List<HabitLeafVerdict> leaves,
  ) {
    final present = value != null;
    final satisfied =
        present &&
        (minimum == null || value >= minimum) &&
        (maximum == null || value <= maximum);
    leaves.add(
      HabitLeafVerdict(
        rule: rule,
        satisfied: satisfied,
        present: present,
        value: value,
      ),
    );
    return satisfied;
  }
}
