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
  Generator<VectorClock> get possiblyInvalidVc =>
      any.combine2(any.int, any.int, (int v1, int v2) {
        return VectorClock({'a': v1, 'b': v2});
      });
}

bool aGtB(VectorClock a, VectorClock b) {
  final nodeIds = <String>{}
    ..addAll(a.vclock.keys)
    ..addAll(b.vclock.keys);

  for (final nodeId in nodeIds) {
    if (b.get(nodeId) > a.get(nodeId)) {
      return false;
    }
  }

  if (b.vclock.values.reduce((acc, elem) => acc + elem) >=
      a.vclock.values.reduce((acc, elem) => acc + elem)) {
    return false;
  }

  return true;
}

void main() {
  Any.setDefault<VectorClock>(any.vc);

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

  Glados2<VectorClock, VectorClock>().test('compare two vector clocks', (
    vc1,
    vc2,
  ) {
    if (const DeepCollectionEquality().equals(vc1.vclock, vc2.vclock)) {
      expect(VectorClock.compare(vc1, vc2), VclockStatus.equal);
    } else if (aGtB(vc1, vc2)) {
      expect(VectorClock.compare(vc1, vc2), VclockStatus.a_gt_b);
    } else if (aGtB(vc2, vc1)) {
      expect(VectorClock.compare(vc1, vc2), VclockStatus.b_gt_a);
    } else {
      expect(VectorClock.compare(vc1, vc2), VclockStatus.concurrent);
    }
  }, tags: 'glados');

  Glados2<VectorClock, VectorClock>(any.vc3, any.vc3).test(
    'compare two vector clocks with three nodes',
    (vc1, vc2) {
      if (const DeepCollectionEquality().equals(vc1.vclock, vc2.vclock)) {
        expect(VectorClock.compare(vc1, vc2), VclockStatus.equal);
      } else if (aGtB(vc1, vc2)) {
        expect(VectorClock.compare(vc1, vc2), VclockStatus.a_gt_b);
      } else if (aGtB(vc2, vc1)) {
        expect(VectorClock.compare(vc1, vc2), VclockStatus.b_gt_a);
      } else {
        expect(VectorClock.compare(vc1, vc2), VclockStatus.concurrent);
      }
    },
    tags: 'glados',
  );

  Glados2<VectorClock, VectorClock>(any.vc, any.vc3).test(
    'compare two vector clocks, one with three nodes',
    (vc1, vc2) {
      if (const DeepCollectionEquality().equals(vc1.vclock, vc2.vclock)) {
        expect(VectorClock.compare(vc1, vc2), VclockStatus.equal);
      } else if (aGtB(vc1, vc2)) {
        expect(VectorClock.compare(vc1, vc2), VclockStatus.a_gt_b);
      } else if (aGtB(vc2, vc1)) {
        expect(VectorClock.compare(vc1, vc2), VclockStatus.b_gt_a);
      } else {
        expect(VectorClock.compare(vc1, vc2), VclockStatus.concurrent);
      }
    },
    tags: 'glados',
  );

  Glados2<VectorClock, VectorClock>(
    any.possiblyInvalidVc,
    any.possiblyInvalidVc,
  ).test('compare two vector clocks, throw exception when invalid', (vc1, vc2) {
    if (!vc1.isValid() || !vc2.isValid()) {
      expect(
        () => VectorClock.compare(vc1, vc2),
        throwsA(
          predicate(
            (e) =>
                e is VclockException &&
                e.toString() == 'Invalid vector clock inputs',
          ),
        ),
      );
    }
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
