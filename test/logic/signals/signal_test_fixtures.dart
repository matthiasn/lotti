import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';

/// Journal entities for the signals tests. Dates are deterministic local
/// wall-clock instants; ids default to the timestamp so two samples at the
/// same instant must pass an explicit id to be distinct.
Metadata signalMeta(DateTime dateFrom, {String? id, DateTime? dateTo}) =>
    Metadata(
      id: id ?? 'e-${dateFrom.millisecondsSinceEpoch}',
      createdAt: dateFrom,
      updatedAt: dateFrom,
      dateFrom: dateFrom,
      dateTo: dateTo ?? dateFrom,
    );

JournalEntity stepsEntity(DateTime at, num value) => JournalEntity.quantitative(
  meta: signalMeta(at),
  data: QuantitativeData.cumulativeQuantityData(
    dateFrom: at,
    dateTo: at,
    value: value,
    dataType: 'cumulative_step_count',
    unit: 'count',
  ),
);

JournalEntity weightEntity(DateTime at, num value, {String? id}) =>
    JournalEntity.quantitative(
      meta: signalMeta(at, id: id),
      data: QuantitativeData.discreteQuantityData(
        dateFrom: at,
        dateTo: at,
        value: value,
        dataType: 'HealthDataType.WEIGHT',
        unit: 'kg',
      ),
    );

JournalEntity measurementEntity(
  DateTime at,
  num value, {
  String dataTypeId = 'water',
  String? id,
}) => JournalEntity.measurement(
  meta: signalMeta(at, id: id),
  data: MeasurementData(
    dateFrom: at,
    dateTo: at,
    value: value,
    dataTypeId: dataTypeId,
  ),
);

JournalEntity workoutEntity(
  DateTime from, {
  required Duration length,
  String workoutType = 'running',
  num? distance,
  num? energy,
}) => JournalEntity.workout(
  meta: signalMeta(from, dateTo: from.add(length)),
  data: WorkoutData(
    dateFrom: from,
    dateTo: from.add(length),
    id: 'w-${from.millisecondsSinceEpoch}',
    workoutType: workoutType,
    energy: energy,
    distance: distance,
    source: null,
  ),
);

JournalEntity habitCompletionEntity(
  DateTime at,
  HabitCompletionType? type, {
  String habitId = 'habit-a',
}) => JournalEntity.habitCompletion(
  meta: signalMeta(at),
  data: HabitCompletionData(
    dateFrom: at,
    dateTo: at,
    habitId: habitId,
    completionType: type,
  ),
);
