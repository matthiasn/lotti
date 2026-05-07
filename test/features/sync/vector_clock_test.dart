import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/vector_clock.dart';

class _GeneratedClockBuckets {
  const _GeneratedClockBuckets(this.counters);

  final List<int> counters;

  VectorClock toClock({bool sparse = false}) {
    final values = <String, int>{};
    for (var index = 0; index < counters.length; index++) {
      final value = counters[index];
      if (sparse && value == 0) continue;
      values['node-$index'] = value;
    }
    return VectorClock(values);
  }

  @override
  String toString() => '_GeneratedClockBuckets($counters)';
}

class _GeneratedClockPair {
  const _GeneratedClockPair({
    required this.a,
    required this.b,
  });

  final _GeneratedClockBuckets a;
  final _GeneratedClockBuckets b;

  @override
  String toString() => '_GeneratedClockPair(a: $a, b: $b)';
}

class _GeneratedClockTriple {
  const _GeneratedClockTriple({
    required this.a,
    required this.b,
    required this.c,
  });

  final _GeneratedClockBuckets a;
  final _GeneratedClockBuckets b;
  final _GeneratedClockBuckets c;

  @override
  String toString() => '_GeneratedClockTriple(a: $a, b: $b, c: $c)';
}

class _GeneratedInvalidClockPair {
  const _GeneratedInvalidClockPair({
    required this.valid,
    required this.invalidSlot,
  });

  final _GeneratedClockBuckets valid;
  final int invalidSlot;

  VectorClock get invalidClock {
    final values = Map<String, int>.from(valid.toClock().vclock);
    values['node-$invalidSlot'] = -1;
    return VectorClock(values);
  }

  @override
  String toString() {
    return '_GeneratedInvalidClockPair('
        'valid: $valid, '
        'invalidSlot: $invalidSlot'
        ')';
  }
}

extension _AnyVectorClockScenario on glados.Any {
  glados.Generator<_GeneratedClockBuckets> get clockBuckets =>
      glados.ListAnys(
            this,
          )
          .listWithLengthInRange(
            0,
            6,
            glados.IntAnys(this).intInRange(0, 5),
          )
          .map(_GeneratedClockBuckets.new);

  glados.Generator<_GeneratedClockPair> get clockPair =>
      glados.CombinableAny(this).combine2(
        clockBuckets,
        clockBuckets,
        (
          _GeneratedClockBuckets a,
          _GeneratedClockBuckets b,
        ) => _GeneratedClockPair(a: a, b: b),
      );

  glados.Generator<_GeneratedClockTriple> get clockTriple =>
      glados.CombinableAny(this).combine3(
        clockBuckets,
        clockBuckets,
        clockBuckets,
        (
          _GeneratedClockBuckets a,
          _GeneratedClockBuckets b,
          _GeneratedClockBuckets c,
        ) => _GeneratedClockTriple(a: a, b: b, c: c),
      );

  glados.Generator<_GeneratedInvalidClockPair> get invalidClockPair =>
      glados.CombinableAny(this).combine2(
        clockBuckets,
        glados.IntAnys(this).intInRange(0, 6),
        (
          _GeneratedClockBuckets valid,
          int invalidSlot,
        ) => _GeneratedInvalidClockPair(
          valid: valid,
          invalidSlot: invalidSlot,
        ),
      );
}

VclockStatus _invert(VclockStatus status) {
  switch (status) {
    case VclockStatus.equal:
    case VclockStatus.concurrent:
      return status;
    case VclockStatus.a_gt_b:
      return VclockStatus.b_gt_a;
    case VclockStatus.b_gt_a:
      return VclockStatus.a_gt_b;
  }
}

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

    group('generated algebraic properties', () {
      glados.Glados(
        glados.any.clockPair,
        glados.ExploreConfig(numRuns: 160),
      ).test('compare is symmetric up to dominance inversion', (scenario) {
        final a = scenario.a.toClock();
        final b = scenario.b.toClock();

        expect(VectorClock.compare(a, b), _invert(VectorClock.compare(b, a)));
      });

      glados.Glados(
        glados.any.clockPair,
        glados.ExploreConfig(numRuns: 120),
      ).test('missing nodes with zero counters compare equal', (scenario) {
        expect(
          VectorClock.compare(
            scenario.a.toClock(),
            scenario.a.toClock(sparse: true),
          ),
          VclockStatus.equal,
        );
      });

      glados.Glados(
        glados.any.clockPair,
        glados.ExploreConfig(numRuns: 160),
      ).test('merge dominates both operands', (scenario) {
        final a = scenario.a.toClock(sparse: true);
        final b = scenario.b.toClock(sparse: true);
        final merged = VectorClock.merge(a, b);

        expect(
          VectorClock.compare(merged, a),
          anyOf(VclockStatus.equal, VclockStatus.a_gt_b),
        );
        expect(
          VectorClock.compare(merged, b),
          anyOf(VclockStatus.equal, VclockStatus.a_gt_b),
        );
      });

      glados.Glados(
        glados.any.clockTriple,
        glados.ExploreConfig(numRuns: 160),
      ).test('merge is commutative, associative, and idempotent', (scenario) {
        final a = scenario.a.toClock(sparse: true);
        final b = scenario.b.toClock(sparse: true);
        final c = scenario.c.toClock(sparse: true);

        expect(VectorClock.merge(a, b).vclock, VectorClock.merge(b, a).vclock);
        expect(VectorClock.merge(a, a).vclock, a.vclock);
        expect(
          VectorClock.merge(VectorClock.merge(a, b), c).vclock,
          VectorClock.merge(a, VectorClock.merge(b, c)).vclock,
        );
      });

      glados.Glados(
        glados.any.invalidClockPair,
        glados.ExploreConfig(numRuns: 80),
      ).test('negative counters are invalid and rejected by compare', (
        scenario,
      ) {
        final valid = scenario.valid.toClock();
        final invalid = scenario.invalidClock;

        expect(invalid.isValid(), isFalse);
        expect(
          () => VectorClock.compare(invalid, valid),
          throwsA(isA<VclockException>()),
        );
        expect(
          () => VectorClock.compare(valid, invalid),
          throwsA(isA<VclockException>()),
        );
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
