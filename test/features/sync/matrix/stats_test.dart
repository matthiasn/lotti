import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/matrix/stats.dart';

enum _GeneratedStatsKeySlot { alpha, beta, gamma, delta, alphaAgain }

String _generatedStatsKey(_GeneratedStatsKeySlot slot) {
  return switch (slot) {
    _GeneratedStatsKeySlot.alpha => 'alpha',
    _GeneratedStatsKeySlot.beta => 'beta',
    _GeneratedStatsKeySlot.gamma => 'gamma',
    _GeneratedStatsKeySlot.delta => 'delta',
    _GeneratedStatsKeySlot.alphaAgain => 'alpha',
  };
}

class _GeneratedStatsEntry {
  const _GeneratedStatsEntry({
    required this.keySlot,
    required this.value,
  });

  final _GeneratedStatsKeySlot keySlot;
  final int value;

  String get key => _generatedStatsKey(keySlot);

  @override
  String toString() => '_GeneratedStatsEntry(key: $key, value: $value)';
}

class _GeneratedStatsScenario {
  const _GeneratedStatsScenario({
    required this.entries,
    required this.sentCount,
  });

  final List<_GeneratedStatsEntry> entries;
  final int sentCount;

  Map<String, int> get messageCounts {
    final out = <String, int>{};
    for (final entry in entries) {
      out[entry.key] = entry.value;
    }
    return out;
  }

  @override
  String toString() =>
      '_GeneratedStatsScenario(entries: $entries, sentCount: $sentCount)';
}

extension _AnyGeneratedStats on glados.Any {
  glados.Generator<_GeneratedStatsKeySlot> get statsKeySlot =>
      glados.AnyUtils(this).choose(_GeneratedStatsKeySlot.values);

  glados.Generator<_GeneratedStatsEntry> get statsEntry =>
      glados.CombinableAny(this).combine2(
        statsKeySlot,
        glados.IntAnys(this).intInRange(0, 10000),
        (_GeneratedStatsKeySlot keySlot, int value) =>
            _GeneratedStatsEntry(keySlot: keySlot, value: value),
      );

  glados.Generator<_GeneratedStatsScenario> get statsScenario =>
      glados.CombinableAny(this).combine2(
        glados.ListAnys(this).listWithLengthInRange(0, 20, statsEntry),
        glados.IntAnys(this).intInRange(0, 1000),
        (List<_GeneratedStatsEntry> entries, int sentCount) =>
            _GeneratedStatsScenario(entries: entries, sentCount: sentCount),
      );
}

void main() {
  group('MatrixStats', () {
    test('constructor sets fields', () {
      const stats = MatrixStats(
        sentCount: 5,
        messageCounts: {'type1': 3, 'type2': 2},
      );

      expect(stats.sentCount, 5);
      expect(stats.messageCounts, {'type1': 3, 'type2': 2});
    });

    test('equality for identical instances', () {
      const a = MatrixStats(
        sentCount: 5,
        messageCounts: {'type1': 3},
      );
      const b = MatrixStats(
        sentCount: 5,
        messageCounts: {'type1': 3},
      );

      expect(a, b);
    });

    test('inequality for different sentCount', () {
      const a = MatrixStats(
        sentCount: 5,
        messageCounts: {'type1': 3},
      );
      const b = MatrixStats(
        sentCount: 6,
        messageCounts: {'type1': 3},
      );

      expect(a, isNot(b));
    });

    test('inequality for different messageCounts', () {
      const a = MatrixStats(
        sentCount: 5,
        messageCounts: {'type1': 3},
      );
      const b = MatrixStats(
        sentCount: 5,
        messageCounts: {'type1': 4},
      );

      expect(a, isNot(b));
    });

    test('inequality with different types', () {
      const stats = MatrixStats(
        sentCount: 0,
        messageCounts: {},
      );

      // ignore: unrelated_type_equality_checks
      expect(stats == 'not a MatrixStats', isFalse);
    });

    test('hashCode is consistent for equal objects', () {
      const a = MatrixStats(
        sentCount: 5,
        messageCounts: {'type1': 3},
      );
      const b = MatrixStats(
        sentCount: 5,
        messageCounts: {'type1': 3},
      );

      expect(a.hashCode, b.hashCode);
    });

    test('empty messageCounts', () {
      const stats = MatrixStats(
        sentCount: 0,
        messageCounts: {},
      );

      expect(stats.sentCount, 0);
      expect(stats.messageCounts, isEmpty);
    });

    glados.Glados(
      glados.any.statsScenario,
      glados.ExploreConfig(numRuns: 140),
    ).test(
      'value-equal instances are equal and share a hash code; a single field '
      'change breaks equality',
      (scenario) {
        final a = MatrixStats(
          sentCount: scenario.sentCount,
          messageCounts: scenario.messageCounts,
        );
        // Distinct map instance with the same entries: equality is by value,
        // not identity, so these must compare equal and hash identically.
        final b = MatrixStats(
          sentCount: scenario.sentCount,
          messageCounts: {...scenario.messageCounts},
        );

        expect(a, b, reason: '$scenario');
        expect(a.hashCode, b.hashCode, reason: '$scenario');

        final differentCount = MatrixStats(
          sentCount: scenario.sentCount + 1,
          messageCounts: scenario.messageCounts,
        );
        expect(a, isNot(differentCount), reason: '$scenario');

        // Mutating any value (or adding a key to an empty map) must break
        // equality, proving messageCounts participates in ==.
        final mutated = {...scenario.messageCounts};
        if (mutated.isEmpty) {
          mutated['__added__'] = 1;
        } else {
          final firstKey = mutated.keys.first;
          mutated[firstKey] = mutated[firstKey]! + 1;
        }
        final differentCounts = MatrixStats(
          sentCount: scenario.sentCount,
          messageCounts: mutated,
        );
        expect(a, isNot(differentCounts), reason: '$scenario');
      },
      tags: 'glados',
    );
  });
}
