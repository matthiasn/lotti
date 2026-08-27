import 'dart:math';

import 'package:collection/collection.dart';
import 'package:health/health.dart';

/// Sums the numeric values in [dataPoints], ignoring any other value kind.
num sumNumericHealthValues(List<HealthDataPoint> dataPoints) => dataPoints
    .map((point) => point.value)
    .whereType<NumericHealthValue>()
    .map((value) => value.numericValue)
    .sum;

/// Resolves one day's step total: the larger of the store's own merged sum
/// ([mergedTotal], `getTotalStepsInInterval`) and the best single source's sum
/// over the raw [samples] for the same day.
///
/// HealthKit builds the merged figure by resolving overlapping samples in
/// favour of the source ranked highest under *Data Sources & Access*, which
/// discards a wearable ranked below the phone wherever the two overlap. Every
/// source counts the same person's day, so the largest single-source total is
/// the best complete count on record; taking the larger of the two restores a
/// dropped source and never sums across sources, which would double-count.
/// Background in `knowledge/features/health_import.md`.
///
/// A source is its `sourceId`, falling back to `sourceName` — Health Connect
/// hands over step records with an empty id and the provider's package name.
/// A `null` [mergedTotal] counts as zero.
int resolveDailySteps(int? mergedTotal, List<HealthDataPoint> samples) {
  final bestSource = samples
      .groupListsBy(
        (sample) =>
            sample.sourceId.isNotEmpty ? sample.sourceId : sample.sourceName,
      )
      .values
      .map(sumNumericHealthValues)
      .fold<num>(0, max);
  return max(bestSource.round(), mergedTotal ?? 0);
}
