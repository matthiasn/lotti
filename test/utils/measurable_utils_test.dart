import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/utils/measurable_utils.dart';

enum _GeneratedPopularityEntryKind {
  measurement,
  journalEntry,
}

class _GeneratedPopularityEntry {
  const _GeneratedPopularityEntry({
    required this.value,
    required this.kind,
    required this.seed,
  });

  final int value;
  final _GeneratedPopularityEntryKind kind;
  final int seed;

  bool get isMeasurement => kind == _GeneratedPopularityEntryKind.measurement;

  JournalEntity toJournalEntity(int index) {
    final testDate = DateTime(2024, 3, 15, 10, 30);
    final meta = Metadata(
      id: 'generated-$index-$seed',
      createdAt: testDate,
      updatedAt: testDate,
      dateFrom: testDate,
      dateTo: testDate,
    );

    return switch (kind) {
      _GeneratedPopularityEntryKind.measurement => MeasurementEntry(
        meta: meta,
        data: MeasurementData(
          value: value,
          dateFrom: testDate,
          dateTo: testDate,
          dataTypeId: 'dataTypeId',
        ),
      ),
      _GeneratedPopularityEntryKind.journalEntry => JournalEntity.journalEntry(
        meta: meta,
        entryText: EntryText(plainText: 'ignored $value'),
      ),
    };
  }

  @override
  String toString() {
    return '_GeneratedPopularityEntry('
        'value: $value, '
        'kind: $kind, '
        'seed: $seed)';
  }
}

class _GeneratedPopularityScenario {
  const _GeneratedPopularityScenario({
    required this.entries,
    required this.limit,
  });

  final List<_GeneratedPopularityEntry> entries;
  final int limit;

  List<JournalEntity> get journalEntities => List.generate(
    entries.length,
    (index) => entries[index].toJournalEntity(index),
  );

  Map<num, int> get measurementCounts {
    final counts = <num, int>{};
    for (final entry in entries.where((entry) => entry.isMeasurement)) {
      counts[entry.value] = (counts[entry.value] ?? 0) + 1;
    }
    return counts;
  }

  @override
  String toString() {
    return '_GeneratedPopularityScenario('
        'entries: $entries, '
        'limit: $limit)';
  }
}

extension _AnyPopularityScenario on glados.Any {
  glados.Generator<_GeneratedPopularityEntryKind> get popularityEntryKind =>
      glados.AnyUtils(this).choose(_GeneratedPopularityEntryKind.values);

  glados.Generator<_GeneratedPopularityEntry> get popularityEntry =>
      glados.CombinableAny(this).combine3(
        glados.IntAnys(this).intInRange(0, 8),
        popularityEntryKind,
        glados.IntAnys(this).intInRange(0, 10000),
        (
          int value,
          _GeneratedPopularityEntryKind kind,
          int seed,
        ) => _GeneratedPopularityEntry(value: value, kind: kind, seed: seed),
      );

  glados.Generator<_GeneratedPopularityScenario> get popularityScenario =>
      glados.CombinableAny(this).combine2(
        glados.ListAnys(this).listWithLengthInRange(0, 30, popularityEntry),
        glados.IntAnys(this).intInRange(0, 8),
        (
          List<_GeneratedPopularityEntry> entries,
          int limit,
        ) => _GeneratedPopularityScenario(entries: entries, limit: limit),
      );
}

void main() {
  group('Measurable utils test', () {
    test('Ranked values for null value returns empty list.', () {
      expect(
        rankedByPopularity(measurements: null),
        <num>[],
      );
    });
    test(
      'Ranked values for empty list of measurements returns empty list.',
      () {
        expect(
          rankedByPopularity(measurements: []),
          <num>[],
        );
      },
    );
    test(
      'Ranked values returns the most common measurement values.',
      () {
        final measurements = testMeasurements(
          <num>[111, 500, 250, 500, 250, 500, 250, 500, 100, 100, 50],
        );

        expect(
          rankedByPopularity(measurements: measurements),
          <num>[500, 250, 100],
        );
      },
    );

    glados.Glados(
      glados.any.popularityScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'returns generated measurement values ordered by non-increasing count',
      (scenario) {
        final counts = scenario.measurementCounts;
        final ranked = rankedByPopularity(
          measurements: scenario.journalEntities,
          n: scenario.limit,
        );
        final expectedLength = _minInt(scenario.limit, counts.length);

        expect(
          ranked.length,
          expectedLength,
          reason: '$scenario',
        );
        expect(ranked.toSet(), hasLength(ranked.length), reason: '$scenario');
        expect(
          ranked.every(counts.containsKey),
          isTrue,
          reason: '$scenario',
        );

        for (var i = 1; i < ranked.length; i++) {
          expect(
            counts[ranked[i - 1]],
            greaterThanOrEqualTo(counts[ranked[i]]!),
            reason: '$scenario',
          );
        }

        if (scenario.limit >= counts.length) {
          expect(ranked.toSet(), counts.keys.toSet(), reason: '$scenario');
        }

        if (ranked.isNotEmpty) {
          final lowestIncludedCount = ranked
              .map((value) => counts[value]!)
              .reduce((a, b) => a < b ? a : b);
          for (final excluded in counts.keys.where(
            (value) => !ranked.contains(value),
          )) {
            expect(
              counts[excluded],
              lessThanOrEqualTo(lowestIncludedCount),
              reason: '$scenario excluded: $excluded',
            );
          }
        }
      },
      tags: 'glados',
    );
  });
}

List<MeasurementEntry> testMeasurements(List<num> values) {
  final testDate = DateTime(2024, 3, 15, 10, 30);
  return values
      .map(
        (value) => MeasurementEntry(
          meta: Metadata(
            id: 'foo',
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
          ),
          data: MeasurementData(
            value: value,
            dateFrom: testDate,
            dateTo: testDate,
            dataTypeId: 'dataTypeId',
          ),
        ),
      )
      .toList();
}

int _minInt(int a, int b) => a < b ? a : b;
