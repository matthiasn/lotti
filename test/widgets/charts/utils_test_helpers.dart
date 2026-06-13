import 'package:glados/glados.dart'
    show Any, CombinableAny, Generator, IntAnys, ListAnys;
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/widgets/charts/utils.dart';

import '../../test_data/test_data.dart';

/// A measurement landing on day `offset` (relative to the range start) with
/// the given numeric `value`.
typedef DaySpec = ({int offset, int value});

class SumByDayScenario {
  const SumByDayScenario({required this.rangeDays, required this.rawSpecs});

  final int rangeDays;
  final List<DaySpec> rawSpecs;

  static final DateTime base = DateTime(2024);

  DateTime get rangeStart => base;
  DateTime get rangeEnd => base.add(Duration(days: rangeDays));

  /// Every measurement clamped into the `[0, rangeDays)` window so the output
  /// is exactly one observation per range day (no out-of-range extra keys).
  Iterable<DaySpec> get specs =>
      rawSpecs.map((s) => (offset: s.offset % rangeDays, value: s.value));

  List<JournalEntity> get entities => [
    for (final (index, spec) in specs.indexed)
      buildMeasurementEntry(
        id: 'm$index',
        timestamp: base.add(Duration(days: spec.offset, hours: 12)),
        value: spec.value,
      ),
  ];

  List<Observation> get expected {
    final sums = <int, int>{for (var d = 0; d < rangeDays; d++) d: 0};
    for (final spec in specs) {
      sums[spec.offset] = sums[spec.offset]! + spec.value;
    }
    return [
      for (var d = 0; d < rangeDays; d++)
        Observation(base.add(Duration(days: d)), sums[d]!),
    ];
  }

  @override
  String toString() =>
      'SumByDayScenario(rangeDays: $rangeDays, rawSpecs: $rawSpecs)';
}

extension AnySumByDay on Any {
  Generator<DaySpec> get daySpec => combine2(
    intInRange(0, 7),
    intInRange(-3, 11),
    (int offset, int value) => (
      offset: offset,
      value: value,
    ),
  );

  Generator<SumByDayScenario> get sumByDayScenario => combine2(
    intInRange(1, 8),
    listWithLengthInRange(0, 15, daySpec),
    (int rangeDays, List<DaySpec> rawSpecs) =>
        SumByDayScenario(rangeDays: rangeDays, rawSpecs: rawSpecs),
  );
}

// ---------------------------------------------------------------------------
// Scenario for aggregateAvgByDay property tests
//
// Like SumByDayScenario, but the expected output omits days with no
// measurements and emits the arithmetic mean instead of the sum.
// ---------------------------------------------------------------------------

/// A measurement landing on day `offset` (relative to range start)
/// with the given signed integer `value`.  Same record shape as `DaySpec`.
typedef AvgDaySpec = ({int offset, int value});

class AvgByDayScenario {
  const AvgByDayScenario({required this.rangeDays, required this.rawSpecs});

  final int rangeDays;
  final List<AvgDaySpec> rawSpecs;

  static final DateTime base = DateTime(2024, 6);

  DateTime get rangeStart => base;
  DateTime get rangeEnd => base.add(Duration(days: rangeDays));

  /// Specs clamped into `[0, rangeDays)` so every offset is in-range.
  Iterable<AvgDaySpec> get specs =>
      rawSpecs.map((s) => (offset: s.offset % rangeDays, value: s.value));

  List<JournalEntity> get entities => <JournalEntity>[
    for (final (index, spec) in specs.indexed)
      buildMeasurementEntry(
        id: 'a$index',
        timestamp: base.add(Duration(days: spec.offset, hours: 6)),
        value: spec.value,
      ),
  ];

  /// Expected per-day arithmetic means (only days with ≥1 measurement).
  Map<String, double> get expectedMeanForDay {
    final sums = <int, int>{};
    final counts = <int, int>{};
    for (final spec in specs) {
      sums[spec.offset] = (sums[spec.offset] ?? 0) + spec.value;
      counts[spec.offset] = (counts[spec.offset] ?? 0) + 1;
    }
    final result = <String, double>{};
    for (final entry in counts.entries) {
      final dayOffset = entry.key;
      final count = entry.value;
      final day = base.add(Duration(days: dayOffset));
      final dayString = day.toIso8601String().substring(0, 10);
      result[dayString] = sums[dayOffset]! / count;
    }
    return result;
  }

  /// Number of days in range that carry ≥1 measurement.
  int get measuredDayCount => specs.map((s) => s.offset).toSet().length;

  @override
  String toString() =>
      'AvgByDayScenario(rangeDays: $rangeDays, rawSpecs: $rawSpecs)';
}

extension AnyAvgByDay on Any {
  Generator<AvgDaySpec> get avgDaySpec => combine2(
    intInRange(0, 7),
    intInRange(-5, 15),
    (int offset, int value) => (offset: offset, value: value),
  );

  Generator<AvgByDayScenario> get avgByDayScenario => combine2(
    intInRange(1, 8),
    listWithLengthInRange(0, 15, avgDaySpec),
    (int rangeDays, List<AvgDaySpec> rawSpecs) =>
        AvgByDayScenario(rangeDays: rangeDays, rawSpecs: rawSpecs),
  );
}
