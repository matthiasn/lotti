import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/logic/health_workout_types.dart';

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

  /// The `JournalEntity.affectedIds` tokens a write to one of these series
  /// carries — what a consumer intersects with a notification batch to decide
  /// whether the tree needs re-evaluating.
  ///
  /// Measurables, health types and habits notify under their own id. A
  /// workout notifies under its *stored* type, and rows of one activity are
  /// stored under either era's spelling (`running` before #2041 and since the
  /// canonicalisation, `RUNNING` in between) — so each workout type expands
  /// to every spelling, the same set the reader queries. Without this a rule
  /// persisted as `RUNNING` read new `running` rows correctly but was never
  /// told they had arrived.
  Set<String> get notificationTokens => {
    ...measurableIds,
    ...quantitativeTypes,
    for (final type in workoutTypes) ...workoutTypeSpellings(type),
    ...habitIds,
  };

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
