import 'package:lotti/blocs/journal/journal_page_cubit.dart';

/// Computes the allowed entry types based on feature flags.
///
/// - When [events] is false, excludes `JournalEvent`.
/// - When [habits] is false, excludes `HabitCompletionEntry`.
/// - When [dashboards] is false, excludes `MeasurementEntry`, `QuantitativeEntry`,
///   `SurveyEntry`, and `WorkoutEntry`.
List<String> computeAllowedEntryTypes({
  required bool events,
  required bool habits,
  required bool dashboards,
}) {
  final disallowed = <String>{};

  if (!events) {
    disallowed.add('JournalEvent');
  }
  if (!habits) {
    disallowed.add('HabitCompletionEntry');
  }
  if (!dashboards) {
    disallowed.addAll({
      'MeasurementEntry',
      'QuantitativeEntry',
      'SurveyEntry',
      'WorkoutEntry',
    });
  }

  return entryTypes.where((t) => !disallowed.contains(t)).toList();
}
