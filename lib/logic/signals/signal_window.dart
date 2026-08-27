import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:lotti/classes/entity_definitions.dart';

/// Journal signals for one rule tree, bucketed by calendar day.
///
/// Every map is keyed by the same midnight-UTC day key as `signalDayKey`.
/// The window is a plain value: evaluators and UI read it, only
/// `SignalReader` builds it, and it carries no feature knowledge, so goals
/// and habits can both consume it without importing each other.
@immutable
class SignalWindow {
  const SignalWindow({
    required this.start,
    required this.end,
    this.quantitativeByDay = const {},
    this.measurableTotalsByDay = const {},
    this.workoutsByDay = const {},
    this.habitSuccessDays = const {},
  });

  /// First day key covered (inclusive).
  final DateTime start;

  /// Last day key covered (inclusive).
  final DateTime end;

  /// Health data type → day → the day's aggregated value.
  final Map<String, Map<DateTime, num>> quantitativeByDay;

  /// Measurable id → day → sum of that day's measurements. A day with an
  /// entry is present even when its total is zero.
  final Map<String, Map<DateTime, num>> measurableTotalsByDay;

  /// Workout type (raw imported string) → day → that day's workouts.
  final Map<String, Map<DateTime, List<WorkoutData>>> workoutsByDay;

  /// Habit id → days whose latest completion was a success.
  final Map<String, Set<DateTime>> habitSuccessDays;

  static const _equality = DeepCollectionEquality();

  @override
  bool operator ==(Object other) =>
      other is SignalWindow &&
      other.start == start &&
      other.end == end &&
      _equality.equals(other.quantitativeByDay, quantitativeByDay) &&
      _equality.equals(other.measurableTotalsByDay, measurableTotalsByDay) &&
      _equality.equals(other.workoutsByDay, workoutsByDay) &&
      _equality.equals(other.habitSuccessDays, habitSuccessDays);

  @override
  int get hashCode => Object.hash(
    start,
    end,
    _equality.hash(quantitativeByDay),
    _equality.hash(measurableTotalsByDay),
    _equality.hash(workoutsByDay),
    _equality.hash(habitSuccessDays),
  );
}
