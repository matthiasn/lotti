import 'dart:math';

import 'package:collection/collection.dart';
import 'package:glados/glados.dart';
import 'package:lotti/features/sync/vector_clock.dart';

extension AnyVectorClock on Any {
  Generator<VectorClock> get vc => any.combine2(
    any.positiveIntOrZero,
    any.positiveIntOrZero,
    (int v1, int v2) {
      return VectorClock({'a': v1, 'b': v2});
    },
  );
  Generator<VectorClock> get vc3 => any.combine3(
    any.positiveIntOrZero,
    any.positiveIntOrZero,
    any.positiveIntOrZero,
    (int v1, int v2, int v3) {
      return VectorClock({'a': v1, 'b': v2, 'c': v3});
    },
  );
  Generator<VectorClock> get sparseVc => any
      .listWithLengthInRange(0, 7, any.choose<int?>([null, 0, 1, 2, 100]))
      .map(
        (counters) => VectorClock({
          for (var i = 0; i < counters.length; i++)
            if (counters[i] case final int counter) 'node-$i': counter,
        }),
      );
}

// Compare components directly: summing counters can overflow and an empty
// clock has no values to reduce. This oracle does not call production helpers.
bool _dominates(VectorClock a, VectorClock b) {
  final nodes = {...a.vclock.keys, ...b.vclock.keys};
  return nodes.every(
        (node) => (a.vclock[node] ?? 0) >= (b.vclock[node] ?? 0),
      ) &&
      nodes.any((node) => (a.vclock[node] ?? 0) > (b.vclock[node] ?? 0));
}

void main() {
  Glados<VectorClock>(any.vc3).test(
    'fromJson(toJson(vc)) round-trips to an equal clock',
    (vc) {
      final restored = VectorClock.fromJson(vc.toJson());
      // Equatable value equality + the underlying map must match exactly.
      expect(restored, vc);
      expect(
        const DeepCollectionEquality().equals(restored.vclock, vc.vclock),
        isTrue,
      );
    },
    tags: 'glados',
  );

  for (final (a, b) in const [
    (VectorClock({'a': 1, 'b': 2}), VectorClock({'a': 1, 'b': 2, 'c': 0})),
    (VectorClock({}), VectorClock({'a': 0})),
    (VectorClock({}), VectorClock({'a': 1})),
    (VectorClock({'a': 1}), VectorClock({'b': 1})),
  ]) {
    test('comparison oracle handles sparse clocks $a and $b', () {
      _expectComparison(a, b);
      _expectComparison(b, a);
    });
  }

  for (final (name, first, second) in [
    ('two nodes', any.vc, any.vc),
    ('three nodes', any.vc3, any.vc3),
    ('different node sets', any.vc, any.vc3),
    ('sparse node sets including empty clocks', any.sparseVc, any.sparseVc),
  ]) {
    Glados2<VectorClock, VectorClock>(first, second).test(
      'compare clocks with $name',
      _expectComparison,
      tags: 'glados',
    );
  }

  Glados2<VectorClock, int>(any.sparseVc, any.negativeInt).test(
    'rejects a negative counter in either operand',
    (valid, negative) {
      final invalid = VectorClock({...valid.vclock, 'invalid': negative});
      for (final (a, b) in [(invalid, valid), (valid, invalid)]) {
        expect(
          () => VectorClock.compare(a, b),
          throwsA(isA<VclockException>()),
          reason: '$a vs $b',
        );
      }
    },
    tags: 'glados',
  );

  Glados<VectorClock>(any.sparseVc).test(
    'adding explicit zero counters preserves causal equality',
    (clock) {
      final padded = VectorClock({...clock.vclock, 'unused-node': 0});
      expect(VectorClock.compare(clock, padded), VclockStatus.equal);
      expect(VectorClock.compare(padded, clock), VclockStatus.equal);
    },
    tags: 'glados',
  );

  Glados3<VectorClock, VectorClock, VectorClock>(
    any.sparseVc,
    any.sparseVc,
    any.sparseVc,
  ).test('merge is associative across sparse clocks', (a, b, c) {
    expect(
      VectorClock.merge(VectorClock.merge(a, b), c),
      VectorClock.merge(a, VectorClock.merge(b, c)),
      reason: '$a, $b, $c',
    );
  }, tags: 'glados');

  group('VectorClock.merge — algebraic laws', () {
    Glados2<VectorClock, VectorClock>(any.vc, any.vc3).test(
      'merge is commutative (per node)',
      (a, b) {
        expect(
          VectorClock.merge(a, b).vclock,
          VectorClock.merge(b, a).vclock,
          reason: '$a vs $b',
        );
      },
      tags: 'glados',
    );

    Glados<VectorClock>(any.vc3).test(
      'merge is idempotent',
      (a) {
        expect(VectorClock.merge(a, a).vclock, a.vclock, reason: '$a');
      },
      tags: 'glados',
    );

    Glados2<VectorClock, VectorClock>(any.vc3, any.vc3).test(
      'merge takes the per-node maximum (least upper bound)',
      (a, b) {
        final merged = VectorClock.merge(a, b);
        for (final node in {...a.vclock.keys, ...b.vclock.keys}) {
          expect(
            merged.get(node),
            max(a.get(node), b.get(node)),
            reason: 'node $node: $a ⊔ $b',
          );
        }
      },
      tags: 'glados',
    );

    test('treats null operands as identity, and null+null as empty', () {
      const a = VectorClock({'a': 3, 'b': 1});
      expect(VectorClock.merge(a, null).vclock, a.vclock);
      expect(VectorClock.merge(null, a).vclock, a.vclock);
      expect(VectorClock.merge(null, null).vclock, <String, int>{});
    });
  });

  group('VectorClock.mergeUniqueClocks', () {
    test('returns null when there are no non-null clocks', () {
      expect(VectorClock.mergeUniqueClocks(const []), isNull);
      expect(VectorClock.mergeUniqueClocks([null, null]), isNull);
    });

    test('deduplicates value-equal clocks and drops nulls', () {
      const a = VectorClock({'a': 1});
      const aCopy = VectorClock({'a': 1});
      const b = VectorClock({'b': 2});
      final result = VectorClock.mergeUniqueClocks([a, null, aCopy, b, null]);
      expect(result, isNotNull);
      expect(result!.length, 2);
      expect(result.contains(a), isTrue);
      expect(result.contains(b), isTrue);
    });
  });
}

void _expectComparison(VectorClock a, VectorClock b) {
  Map<String, int> nonZeroCounters(VectorClock clock) => {
    for (final entry in clock.vclock.entries)
      if (entry.value != 0) entry.key: entry.value,
  };
  final expected =
      const DeepCollectionEquality().equals(
        nonZeroCounters(a),
        nonZeroCounters(b),
      )
      ? VclockStatus.equal
      : _dominates(a, b)
      ? VclockStatus.a_gt_b
      : _dominates(b, a)
      ? VclockStatus.b_gt_a
      : VclockStatus.concurrent;
  expect(VectorClock.compare(a, b), expected, reason: '$a vs $b');
}
