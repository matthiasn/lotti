import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:research_package/model.dart';

/// Creates a [QuantitativeEntry] for testing health data aggregation.
/// A quantitative sample for aggregation tests.
///
/// [dateTo] defaults to [dateFrom], which suits an instantaneous reading such
/// as a weight. Pass it explicitly for a sample that covers a span — a sleep
/// segment above all, whose end day is what it is aggregated by.
QuantitativeEntry makeQuantitativeEntry({
  required DateTime dateFrom,
  required num value,
  required String dataType,
  DateTime? dateTo,
  String unit = 'unit',
  String? id,
}) {
  final entryId = id ?? 'quant-${dateFrom.toIso8601String()}-$value';
  final end = dateTo ?? dateFrom;
  return QuantitativeEntry(
    meta: Metadata(
      id: entryId,
      createdAt: dateFrom,
      dateFrom: dateFrom,
      dateTo: end,
      updatedAt: dateFrom,
      starred: false,
    ),
    data: QuantitativeData.discreteQuantityData(
      dateFrom: dateFrom,
      dateTo: end,
      value: value,
      dataType: dataType,
      unit: unit,
    ),
  );
}

/// Creates a [WorkoutEntry] for testing workout data aggregation.
WorkoutEntry makeWorkoutEntry({
  required DateTime dateFrom,
  required DateTime dateTo,
  required String workoutType,
  num? energy,
  num? distance,
  String? id,
}) {
  final entryId = id ?? 'workout-${dateFrom.toIso8601String()}';
  return WorkoutEntry(
    meta: Metadata(
      id: entryId,
      createdAt: dateFrom,
      dateFrom: dateFrom,
      dateTo: dateTo,
      updatedAt: dateTo,
      starred: false,
    ),
    data: WorkoutData(
      dateFrom: dateFrom,
      dateTo: dateTo,
      workoutType: workoutType,
      energy: energy,
      distance: distance,
      id: entryId,
      source: '',
    ),
  );
}

/// Creates a [SurveyEntry] for testing survey data aggregation.
SurveyEntry makeSurveyEntry({
  required DateTime dateFrom,
  required Map<String, int> calculatedScores,
  String? id,
}) {
  final entryId = id ?? 'survey-${dateFrom.toIso8601String()}';
  return SurveyEntry(
    meta: Metadata(
      id: entryId,
      createdAt: dateFrom,
      dateFrom: dateFrom,
      dateTo: dateFrom,
      updatedAt: dateFrom,
      starred: false,
      vectorClock: const VectorClock({}),
    ),
    data: SurveyData(
      taskResult: RPTaskResult(identifier: 'test'),
      scoreDefinitions: const {},
      calculatedScores: calculatedScores,
    ),
  );
}
