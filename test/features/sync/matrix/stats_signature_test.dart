import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/stats.dart';
import 'package:lotti/features/sync/matrix/stats_signature.dart';

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
