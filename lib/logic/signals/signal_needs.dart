import 'package:lotti/classes/entity_definitions.dart';

/// The distinct journal series an [AutoCompleteRule] tree reads.
///
/// Collected once per read so each series is queried a single time however
/// often the tree references it.
class SignalNeeds {
  SignalNeeds();

  /// Builds the needs of [rule] and everything below it.
  factory SignalNeeds.of(AutoCompleteRule rule) => SignalNeeds()..collect(rule);

  final quantitativeTypes = <String>{};
  final measurableIds = <String>{};
  final workoutTypes = <String>{};
  final habitIds = <String>{};

  bool get isEmpty =>
      quantitativeTypes.isEmpty &&
      measurableIds.isEmpty &&
      workoutTypes.isEmpty &&
      habitIds.isEmpty;

  void collect(AutoCompleteRule rule) {
    switch (rule) {
      case AutoCompleteRuleHealth(:final dataType):
        quantitativeTypes.add(dataType);
      case AutoCompleteRuleWorkout(:final dataType):
        workoutTypes.add(dataType);
      case AutoCompleteRuleMeasurable(:final dataTypeId):
        measurableIds.add(dataTypeId);
      case AutoCompleteRuleHabit(:final habitId):
        habitIds.add(habitId);
      case AutoCompleteRuleAnd(:final rules) ||
          AutoCompleteRuleOr(:final rules) ||
          AutoCompleteRuleMultiple(:final rules):
        rules.forEach(collect);
    }
  }
}
