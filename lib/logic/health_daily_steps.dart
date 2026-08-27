import 'package:health/health.dart';

/// Resolves one day's step total from what the health store hands back.
///
/// [mergedTotal] is the store's own de-duplicated sum over every source
/// (`getTotalStepsInInterval`). HealthKit builds that figure by resolving
/// overlapping samples in favour of the source ranked highest under *Data
/// Sources & Access*, which is what quietly discards a wearable's count: an
/// iPhone that sat on a desk still writes samples whenever it moved, and every
/// wearable sample those overlap loses to it. A band that syncs its day once,
/// overnight, is the worst case — its one sample overlaps everything.
///
/// [samples] are the raw `STEPS` samples for the same day, which the store
/// hands over unmerged and stamped with their source. Every source counts the
/// same person's steps over the same day, so the largest single-source total
/// is the best complete count on record — and the merged figure can only be
/// less than or equal to the best source when priority dropped that source's
/// samples. The answer is therefore the larger of the two, never a sum across
/// sources, which would double-count.
///
/// Samples without a numeric value are ignored; a `null` [mergedTotal] (no
/// answer from the store) counts as zero.
int resolveDailySteps(int? mergedTotal, List<HealthDataPoint> samples) {
  final bySource = <String, double>{};
  for (final sample in samples) {
    final value = sample.value;
    if (value is NumericHealthValue) {
      bySource.update(
        sample.sourceId,
        (total) => total + value.numericValue,
        ifAbsent: () => value.numericValue.toDouble(),
      );
    }
  }
  final bestSource = bySource.values.fold<double>(
    0,
    (best, total) => total > best ? total : best,
  );
  final merged = mergedTotal ?? 0;
  return bestSource > merged ? bestSource.round() : merged;
}
