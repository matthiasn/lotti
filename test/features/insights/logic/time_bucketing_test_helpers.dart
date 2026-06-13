import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';

/// Generated entry spec: a start instant plus a duration, both derived from
/// bounded ints so shrinking converges to the epoch-adjacent minimal case.
class EntrySpec {
  const EntrySpec({
    required this.startMinutesFromAnchor,
    required this.durationMinutes,
    required this.categorySeed,
  });

  /// Anchored in March 2024 so generated spans regularly cross the European
  /// and US DST spring-forward transitions (Mar 10 / Mar 31, 2024).
  static final DateTime anchor = DateTime(2024, 3);

  final int startMinutesFromAnchor;
  final int durationMinutes;
  final int categorySeed;

  DateTime get start => DateTime(
    anchor.year,
    anchor.month,
    anchor.day,
    0,
    startMinutesFromAnchor,
  );

  DateTime get end => DateTime(
    anchor.year,
    anchor.month,
    anchor.day,
    0,
    startMinutesFromAnchor + durationMinutes,
  );

  String? get categoryId => categorySeed == 0 ? null : 'cat-$categorySeed';

  InsightsTimeRow get row =>
      InsightsTimeRow(dateFrom: start, dateTo: end, categoryId: categoryId);

  @override
  String toString() =>
      'EntrySpec(+${startMinutesFromAnchor}m, ${durationMinutes}m, '
      'cat:$categorySeed)';
}

extension AnyInsights on glados.Any {
  glados.Generator<EntrySpec> get entrySpec => combine3(
    // Up to ~40 days of starts → spans cross both March 2024 DST changes.
    intInRange(0, 40 * 24 * 60),
    // 1 minute … 3 days, so multi-midnight splits are exercised.
    intInRange(1, 3 * 24 * 60),
    intInRange(0, 4),
    (int start, int duration, int category) => EntrySpec(
      startMinutesFromAnchor: start,
      durationMinutes: duration,
      categorySeed: category,
    ),
  );

  glados.Generator<List<EntrySpec>> get entrySpecs => list(entrySpec);
}

int hWindowStartDay() => epochDay(EntrySpec.anchor) - 1;
