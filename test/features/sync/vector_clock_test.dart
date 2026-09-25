import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/vector_clock.dart';

/// Generated counters, one per node; -1 leaves the node out of the clock, so
/// a generated clock mixes absent nodes with nodes at counter 0.
class _GeneratedClockBuckets {
  const _GeneratedClockBuckets(this.counters);

  final List<int> counters;

  /// The clock; [sparse] also leaves out every node at counter 0.
  VectorClock toClock({bool sparse = false}) {
    final values = <String, int>{};
    for (var index = 0; index < counters.length; index++) {
      final value = counters[index];
      if (value < 0 || (sparse && value == 0)) continue;
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
            glados.IntAnys(this).intInRange(-1, 5),
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

/// The causal order itself, independent of [VectorClock.compare]: [a] is at
/// or below [b] when every node present in [a] is present in [b] with a
/// counter at least as large. A present node, at counter 0 too, says the
/// host wrote.
bool _causallyAtOrBelow(VectorClock a, VectorClock b) => a.vclock.entries.every(
  (e) => b.vclock.containsKey(e.key) && b.vclock[e.key]! >= e.value,
);

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

    group('an absent host and counter 0 (ADR 0080)', () {
      // Counter 0 is the first counter of every host an older build created.
      test('a new host extending a version dominates it', () {
        const stored = VectorClock({'device-a': 1});
        const edited = VectorClock({'device-a': 1, 'device-b': 0});

        expect(VectorClock.compare(stored, edited), VclockStatus.b_gt_a);
        expect(VectorClock.compare(edited, stored), VclockStatus.a_gt_b);
      });

      test('two new hosts extending one version are concurrent', () {
        expect(
          VectorClock.compare(
            const VectorClock({'device-a': 1, 'device-b': 0}),
            const VectorClock({'device-a': 1, 'device-c': 0}),
          ),
          VclockStatus.concurrent,
        );
      });

      test(
        "a newer version without the new host's entry is concurrent with the "
        "new host's edit, not above it",
        () {
          expect(
            VectorClock.compare(
              const VectorClock({'device-a': 2}),
              const VectorClock({'device-a': 1, 'device-b': 0}),
            ),
            VclockStatus.concurrent,
          );
        },
      );
    });

    group('compareCanonically', () {
      glados.Glados(
        glados.any.clockPair,
        glados.ExploreConfig(numRuns: 200),
      ).test('is antisymmetric and 0 only for identical clocks', (scenario) {
        final a = scenario.a.toClock();
        final b = scenario.b.toClock();
        expect(
          VectorClock.compareCanonically(a, b),
          -VectorClock.compareCanonically(b, a),
          reason: 'a=${a.vclock} b=${b.vclock}',
        );
        expect(
          VectorClock.compareCanonically(a, b) == 0,
          a == b,
          reason: 'a=${a.vclock} b=${b.vclock}',
        );
      }, tags: 'glados');

      glados.Glados(
        glados.any.clockTriple,
        glados.ExploreConfig(numRuns: 200),
      ).test('is transitive (a sort comparator on the sync hot path)', (
        scenario,
      ) {
        final a = scenario.a.toClock();
        final b = scenario.b.toClock();
        final c = scenario.c.toClock();
        final ab = VectorClock.compareCanonically(a, b);
        final bc = VectorClock.compareCanonically(b, c);
        if (ab > 0 && bc > 0) {
          expect(
            VectorClock.compareCanonically(a, c),
            1,
            reason: 'a=${a.vclock} b=${b.vclock} c=${c.vclock}',
          );
        }
      }, tags: 'glados');

      glados.Glados(
        glados.any.clockPair,
        glados.ExploreConfig(numRuns: 200),
      ).test('ranks a dominating clock higher', (scenario) {
        final a = scenario.a.toClock();
        final b = scenario.b.toClock();
        if (VectorClock.compare(a, b) == VclockStatus.a_gt_b) {
          expect(
            VectorClock.compareCanonically(a, b),
            1,
            reason: 'a=${a.vclock} b=${b.vclock}',
          );
        }
      }, tags: 'glados');

      test('orders by the first differing host counter', () {
        expect(
          VectorClock.compareCanonically(
            const VectorClock({'h0': 2, 'h1': 0}),
            const VectorClock({'h0': 1, 'h1': 9}),
          ),
          1,
        );
        expect(
          VectorClock.compareCanonically(
            const VectorClock({'h0': 1}),
            const VectorClock({'h0': 2}),
          ),
          -1,
        );
      });

      test('ranks an absent host below counter 0', () {
        // Two new hosts that each extended {h0: 1}: the pair must still be
        // ordered, or each replica keeps its own version.
        expect(
          VectorClock.compareCanonically(
            const VectorClock({'h0': 1, 'h1': 0}),
            const VectorClock({'h0': 1, 'h2': 0}),
          ),
          1,
        );
        expect(
          VectorClock.compareCanonically(
            const VectorClock({'h0': 1}),
            const VectorClock({'h1': 1}),
          ),
          1,
        );
      });

      test('returns 0 for identical and for empty clocks', () {
        expect(
          VectorClock.compareCanonically(
            const VectorClock({'h0': 3, 'h1': 1}),
            const VectorClock({'h0': 3, 'h1': 1}),
          ),
          0,
        );
        expect(
          VectorClock.compareCanonically(
            const VectorClock({}),
            const VectorClock({}),
          ),
          0,
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
      }, tags: 'glados');

      glados.Glados(
        glados.any.clockPair,
        glados.ExploreConfig(numRuns: 120),
      ).test(
        'a clock dominates the same clock without its zero counters',
        (scenario) {
          final dense = scenario.a.toClock();
          final sparse = scenario.a.toClock(sparse: true);
          expect(
            VectorClock.compare(dense, sparse),
            dense.vclock.containsValue(0)
                ? VclockStatus.a_gt_b
                : VclockStatus.equal,
            reason: 'dense=${dense.vclock} sparse=${sparse.vclock}',
          );
        },
        tags: 'glados',
      );

      glados.Glados(
        glados.any.clockPair,
        glados.ExploreConfig(numRuns: 200),
      ).test('compare is the causal order, absent nodes below counter 0', (
        scenario,
      ) {
        final a = scenario.a.toClock();
        final b = scenario.b.toClock();
        final atOrBelow = _causallyAtOrBelow(a, b);
        final atOrAbove = _causallyAtOrBelow(b, a);
        final expected = atOrBelow && atOrAbove
            ? VclockStatus.equal
            : atOrBelow
            ? VclockStatus.b_gt_a
            : atOrAbove
            ? VclockStatus.a_gt_b
            : VclockStatus.concurrent;
        expect(
          VectorClock.compare(a, b),
          expected,
          reason: 'a=${a.vclock} b=${b.vclock}',
        );
        // Antisymmetry: only identical clocks are equal.
        expect(
          VectorClock.compare(a, b) == VclockStatus.equal,
          a == b,
          reason: 'a=${a.vclock} b=${b.vclock}',
        );
      }, tags: 'glados');

      glados.Glados(
        glados.any.clockTriple,
        glados.ExploreConfig(numRuns: 200),
      ).test('dominance is transitive', (scenario) {
        final a = scenario.a.toClock();
        final b = scenario.b.toClock();
        final c = scenario.c.toClock();
        const atOrAbove = {VclockStatus.a_gt_b, VclockStatus.equal};
        if (atOrAbove.contains(VectorClock.compare(a, b)) &&
            atOrAbove.contains(VectorClock.compare(b, c))) {
          expect(
            VectorClock.compare(a, c),
            isIn(atOrAbove),
            reason: 'a=${a.vclock} b=${b.vclock} c=${c.vclock}',
          );
        }
      }, tags: 'glados');

      glados.Glados(
        glados.any.clockTriple,
        glados.ExploreConfig(numRuns: 200),
      ).test('merge is the least clock at or above both operands', (scenario) {
        final a = scenario.a.toClock();
        final b = scenario.b.toClock();
        final c = scenario.c.toClock();
        final merged = VectorClock.merge(a, b);
        const atOrAbove = {VclockStatus.a_gt_b, VclockStatus.equal};
        if (atOrAbove.contains(VectorClock.compare(c, a)) &&
            atOrAbove.contains(VectorClock.compare(c, b))) {
          expect(
            VectorClock.compare(c, merged),
            isIn(atOrAbove),
            reason: 'a=${a.vclock} b=${b.vclock} c=${c.vclock}',
          );
        }
      }, tags: 'glados');

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
      }, tags: 'glados');

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
      }, tags: 'glados');

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
      }, tags: 'glados');
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
