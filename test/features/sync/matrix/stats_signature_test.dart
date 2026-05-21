import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/matrix/stats.dart';
import 'package:lotti/features/sync/matrix/stats_signature.dart';

enum _GeneratedMetricKeySlot { alpha, beta, gamma, delta, alphaAgain }

String _generatedMetricKey(_GeneratedMetricKeySlot slot) {
  return switch (slot) {
    _GeneratedMetricKeySlot.alpha => 'alpha',
    _GeneratedMetricKeySlot.beta => 'beta',
    _GeneratedMetricKeySlot.gamma => 'gamma',
    _GeneratedMetricKeySlot.delta => 'delta',
    _GeneratedMetricKeySlot.alphaAgain => 'alpha',
  };
}

class _GeneratedMetricEntry {
  const _GeneratedMetricEntry({
    required this.keySlot,
    required this.value,
  });

  final _GeneratedMetricKeySlot keySlot;
  final int value;

  String get key => _generatedMetricKey(keySlot);

  @override
  String toString() {
    return '_GeneratedMetricEntry(key: $key, value: $value)';
  }
}

class _GeneratedMetricsScenario {
  const _GeneratedMetricsScenario({
    required this.entries,
    required this.sentCount,
  });

  final List<_GeneratedMetricEntry> entries;
  final int sentCount;

  Map<String, int> get map {
    final out = <String, int>{};
    for (final entry in entries) {
      out[entry.key] = entry.value;
    }
    return out;
  }

  @override
  String toString() {
    return '_GeneratedMetricsScenario('
        'entries: $entries, sentCount: $sentCount)';
  }
}

extension _AnyGeneratedMetrics on glados.Any {
  glados.Generator<_GeneratedMetricKeySlot> get metricKeySlot =>
      glados.AnyUtils(this).choose(_GeneratedMetricKeySlot.values);

  glados.Generator<_GeneratedMetricEntry> get metricEntry =>
      glados.CombinableAny(this).combine2(
        metricKeySlot,
        glados.IntAnys(this).intInRange(0, 10000),
        (_GeneratedMetricKeySlot keySlot, int value) =>
            _GeneratedMetricEntry(keySlot: keySlot, value: value),
      );

  glados.Generator<_GeneratedMetricsScenario> get metricsScenario =>
      glados.CombinableAny(this).combine2(
        glados.ListAnys(this).listWithLengthInRange(0, 20, metricEntry),
        glados.IntAnys(this).intInRange(0, 1000),
        (List<_GeneratedMetricEntry> entries, int sentCount) =>
            _GeneratedMetricsScenario(
              entries: entries,
              sentCount: sentCount,
            ),
      );
}

void main() {
  group('buildMatrixStatsSignature', () {
    test('includes sent count and sorted keys', () {
      const stats = MatrixStats(
        sentCount: 3,
        messageCounts: {'b': 2, 'a': 1},
      );

      final sig = buildMatrixStatsSignature(stats);

      expect(sig, 'sent=3;a=1;b=2;');
    });

    test('empty messageCounts produces only sent prefix', () {
      const stats = MatrixStats(
        sentCount: 0,
        messageCounts: {},
      );

      final sig = buildMatrixStatsSignature(stats);

      expect(sig, 'sent=0;');
    });

    test('deterministic regardless of insertion order', () {
      const stats1 = MatrixStats(
        sentCount: 1,
        messageCounts: {'z': 9, 'a': 1, 'm': 5},
      );
      const stats2 = MatrixStats(
        sentCount: 1,
        messageCounts: {'a': 1, 'm': 5, 'z': 9},
      );

      expect(
        buildMatrixStatsSignature(stats1),
        buildMatrixStatsSignature(stats2),
      );
    });

    glados.Glados(
      glados.any.metricsScenario,
      glados.ExploreConfig(numRuns: 140),
    ).test('matches generated metric-map signature with sent prefix', (
      scenario,
    ) {
      final stats = MatrixStats(
        sentCount: scenario.sentCount,
        messageCounts: scenario.map,
      );
      final expected = _expectedSignature(
        scenario.map,
        sentCount: scenario.sentCount,
      );

      expect(buildMatrixStatsSignature(stats), expected, reason: '$scenario');
    }, tags: 'glados');
  });

  group('matrixStatsSignature', () {
    test('returns null for null input', () {
      expect(matrixStatsSignature(null), isNull);
    });

    test('delegates to buildMatrixStatsSignature for non-null', () {
      const stats = MatrixStats(
        sentCount: 2,
        messageCounts: {'x': 1},
      );

      expect(
        matrixStatsSignature(stats),
        buildMatrixStatsSignature(stats),
      );
    });
  });

  group('buildMetricsMapSignature', () {
    test('sorts keys alphabetically', () {
      final sig = buildMetricsMapSignature({'c': 3, 'a': 1, 'b': 2});

      expect(sig, 'a=1;b=2;c=3;');
    });

    test('empty map returns empty string', () {
      expect(buildMetricsMapSignature({}), '');
    });

    test('single entry', () {
      expect(buildMetricsMapSignature({'key': 42}), 'key=42;');
    });

    glados.Glados(
      glados.any.metricsScenario,
      glados.ExploreConfig(numRuns: 140),
    ).test(
      'is deterministic for generated maps regardless of entry order',
      (
        scenario,
      ) {
        final forward = scenario.map;
        final sameEntriesDifferentOrder = <String, int>{};
        for (final entry in forward.entries.toList().reversed) {
          sameEntriesDifferentOrder[entry.key] = entry.value;
        }

        expect(
          buildMetricsMapSignature(forward),
          _expectedSignature(forward),
          reason: '$scenario',
        );
        expect(
          buildMetricsMapSignature(sameEntriesDifferentOrder),
          _expectedSignature(sameEntriesDifferentOrder),
          reason: '$scenario',
        );
        expect(
          buildMetricsMapSignature(forward),
          buildMetricsMapSignature(sameEntriesDifferentOrder),
          reason: '$scenario',
        );
      },
      tags: 'glados',
    );
  });

  group('metricsMapSignature', () {
    test('returns null for null input', () {
      expect(metricsMapSignature(null), isNull);
    });

    test('returns null for empty map', () {
      expect(metricsMapSignature({}), isNull);
    });

    test('delegates to buildMetricsMapSignature for non-empty', () {
      final map = {'key': 1};

      expect(metricsMapSignature(map), buildMetricsMapSignature(map));
    });
  });
}

String _expectedSignature(
  Map<String, int> map, {
  int? sentCount,
}) {
  final keys = map.keys.toList()..sort();
  final buffer = StringBuffer();
  if (sentCount != null) {
    buffer.write('sent=$sentCount;');
  }
  for (final key in keys) {
    buffer.write('$key=${map[key]};');
  }
  return buffer.toString();
}
