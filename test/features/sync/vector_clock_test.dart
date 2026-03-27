import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/vector_clock.dart';

void main() {
  group('VectorClock', () {
    group('compare', () {
      test('returns equal for identical clocks', () {
        const a = VectorClock({'node1': 1, 'node2': 2});
        const b = VectorClock({'node1': 1, 'node2': 2});

        expect(VectorClock.compare(a, b), VclockStatus.equal);
      });

      test('returns equal for two empty clocks', () {
        const a = VectorClock({});
        const b = VectorClock({});

        expect(VectorClock.compare(a, b), VclockStatus.equal);
      });

      test('returns a_gt_b when A strictly dominates B', () {
        const a = VectorClock({'node1': 3, 'node2': 2});
        const b = VectorClock({'node1': 1, 'node2': 2});

        expect(VectorClock.compare(a, b), VclockStatus.a_gt_b);
      });

      test('returns b_gt_a when B strictly dominates A', () {
        const a = VectorClock({'node1': 1, 'node2': 2});
        const b = VectorClock({'node1': 3, 'node2': 2});

        expect(VectorClock.compare(a, b), VclockStatus.b_gt_a);
      });

      test('returns concurrent when neither dominates', () {
        const a = VectorClock({'node1': 3, 'node2': 1});
        const b = VectorClock({'node1': 1, 'node2': 3});

        expect(VectorClock.compare(a, b), VclockStatus.concurrent);
      });

      test('handles disjoint node sets where A has extra node', () {
        const a = VectorClock({'node1': 1, 'node2': 1});
        const b = VectorClock({'node1': 1});

        expect(VectorClock.compare(a, b), VclockStatus.a_gt_b);
      });

      test('handles disjoint node sets where B has extra node', () {
        const a = VectorClock({'node1': 1});
        const b = VectorClock({'node1': 1, 'node2': 1});

        expect(VectorClock.compare(a, b), VclockStatus.b_gt_a);
      });

      test('returns concurrent when both have unique extra nodes', () {
        const a = VectorClock({'nodeA': 1});
        const b = VectorClock({'nodeB': 1});

        expect(VectorClock.compare(a, b), VclockStatus.concurrent);
      });

      test('throws VclockException for negative counters in A', () {
        const a = VectorClock({'node1': -1});
        const b = VectorClock({'node1': 1});

        expect(
          () => VectorClock.compare(a, b),
          throwsA(isA<VclockException>()),
        );
      });

      test('throws VclockException for negative counters in B', () {
        const a = VectorClock({'node1': 1});
        const b = VectorClock({'node1': -1});

        expect(
          () => VectorClock.compare(a, b),
          throwsA(isA<VclockException>()),
        );
      });
    });

    group('merge', () {
      test('merges two clocks by taking max of each counter', () {
        const a = VectorClock({'node1': 3, 'node2': 1});
        const b = VectorClock({'node1': 1, 'node2': 5});

        final merged = VectorClock.merge(a, b);

        expect(merged.vclock, {'node1': 3, 'node2': 5});
      });

      test('merges with null first argument', () {
        const b = VectorClock({'node1': 2});

        final merged = VectorClock.merge(null, b);

        expect(merged.vclock, {'node1': 2});
      });

      test('merges with null second argument', () {
        const a = VectorClock({'node1': 2});

        final merged = VectorClock.merge(a, null);

        expect(merged.vclock, {'node1': 2});
      });

      test('merges two nulls into empty clock', () {
        final merged = VectorClock.merge(null, null);

        expect(merged.vclock, <String, int>{});
      });

      test('includes nodes from both clocks', () {
        const a = VectorClock({'nodeA': 1});
        const b = VectorClock({'nodeB': 2});

        final merged = VectorClock.merge(a, b);

        expect(merged.vclock, {'nodeA': 1, 'nodeB': 2});
      });
    });

    group('mergeUniqueClocks', () {
      test('returns null for empty iterable', () {
        final result = VectorClock.mergeUniqueClocks([]);

        expect(result, isNull);
      });

      test('returns null when all values are null', () {
        final result = VectorClock.mergeUniqueClocks([null, null]);

        expect(result, isNull);
      });

      test('deduplicates equal clocks', () {
        const clock = VectorClock({'node1': 1});
        final result = VectorClock.mergeUniqueClocks([clock, clock]);

        expect(result, hasLength(1));
        expect(result!.first, clock);
      });

      test('keeps distinct clocks', () {
        const a = VectorClock({'node1': 1});
        const b = VectorClock({'node1': 2});
        final result = VectorClock.mergeUniqueClocks([a, b]);

        expect(result, hasLength(2));
      });

      test('filters out null values', () {
        const a = VectorClock({'node1': 1});
        final result = VectorClock.mergeUniqueClocks([null, a, null]);

        expect(result, hasLength(1));
        expect(result!.first, a);
      });
    });

    group('get', () {
      test('returns value for existing node', () {
        const clock = VectorClock({'node1': 42});

        expect(clock.get('node1'), 42);
      });

      test('returns 0 for non-existing node', () {
        const clock = VectorClock({'node1': 42});

        expect(clock.get('nonexistent'), 0);
      });
    });

    group('isValid', () {
      test('returns true for valid clock', () {
        const clock = VectorClock({'node1': 1, 'node2': 0});

        expect(clock.isValid(), isTrue);
      });

      test('returns true for empty clock', () {
        const clock = VectorClock({});

        expect(clock.isValid(), isTrue);
      });

      test('returns false for clock with negative counter', () {
        const clock = VectorClock({'node1': -1});

        expect(clock.isValid(), isFalse);
      });
    });

    group('serialization', () {
      test('fromJson round-trips with toJson', () {
        const original = VectorClock({'node1': 1, 'node2': 2});
        final json = original.toJson();
        final restored = VectorClock.fromJson(json);

        expect(restored, original);
      });

      test('toString returns map representation', () {
        const clock = VectorClock({'node1': 1});

        expect(clock.toString(), '{node1: 1}');
      });
    });

    group('equality', () {
      test('equal clocks have same hashCode', () {
        const a = VectorClock({'node1': 1});
        const b = VectorClock({'node1': 1});

        expect(a, b);
        expect(a.hashCode, b.hashCode);
      });

      test('different clocks are not equal', () {
        const a = VectorClock({'node1': 1});
        const b = VectorClock({'node1': 2});

        expect(a, isNot(b));
      });
    });
  });

  group('VclockException', () {
    test('toString returns expected message', () {
      expect(VclockException().toString(), 'Invalid vector clock inputs');
    });
  });
}
