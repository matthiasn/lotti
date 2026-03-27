import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/stats.dart';

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

    test('identical instances are equal', () {
      const stats = MatrixStats(
        sentCount: 1,
        messageCounts: {'a': 1},
      );

      expect(stats, stats);
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
  });
}
