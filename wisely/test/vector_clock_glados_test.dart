import 'package:collection/collection.dart';
import 'package:glados/glados.dart';
import 'package:wisely/sync/vector_clock.dart';

extension AnyVectorClock on Any {
  Generator<VectorClock> get vc =>
      any.combine2(any.positiveIntOrZero, any.positiveIntOrZero,
          (int v1, int v2) {
        return VectorClock({'a': v1, 'b': v2});
      });
  Generator<VectorClock> get vc3 => any.combine3(
          any.positiveIntOrZero, any.positiveIntOrZero, any.positiveIntOrZero,
          (int v1, int v2, int v3) {
        return VectorClock({'a': v1, 'b': v2, 'c': v3});
      });
  Generator<VectorClock> get possiblyInvalidVc =>
      any.combine2(any.int, any.int, (int v1, int v2) {
        return VectorClock({'a': v1, 'b': v2});
      });
}

bool aGtB(VectorClock a, VectorClock b) {
  Set<String> nodeIds = <String>{};
  nodeIds.addAll(a.vclock.keys);
  nodeIds.addAll(b.vclock.keys);

  for (String nodeId in nodeIds) {
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

  Glados2<VectorClock, VectorClock>().test('compare two vector clocks',
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
  });

  Glados2<VectorClock, VectorClock>(any.vc3, any.vc3)
      .test('compare two vector clocks with three nodes', (vc1, vc2) {
    if (const DeepCollectionEquality().equals(vc1.vclock, vc2.vclock)) {
      expect(VectorClock.compare(vc1, vc2), VclockStatus.equal);
    } else if (aGtB(vc1, vc2)) {
      expect(VectorClock.compare(vc1, vc2), VclockStatus.a_gt_b);
    } else if (aGtB(vc2, vc1)) {
      expect(VectorClock.compare(vc1, vc2), VclockStatus.b_gt_a);
    } else {
      expect(VectorClock.compare(vc1, vc2), VclockStatus.concurrent);
    }
  });

  Glados2<VectorClock, VectorClock>(any.vc, any.vc3)
      .test('compare two vector clocks, one with three nodes', (vc1, vc2) {
    if (const DeepCollectionEquality().equals(vc1.vclock, vc2.vclock)) {
      expect(VectorClock.compare(vc1, vc2), VclockStatus.equal);
    } else if (aGtB(vc1, vc2)) {
      expect(VectorClock.compare(vc1, vc2), VclockStatus.a_gt_b);
    } else if (aGtB(vc2, vc1)) {
      expect(VectorClock.compare(vc1, vc2), VclockStatus.b_gt_a);
    } else {
      expect(VectorClock.compare(vc1, vc2), VclockStatus.concurrent);
    }
  });

  Glados2<VectorClock, VectorClock>(
          any.possiblyInvalidVc, any.possiblyInvalidVc)
      .test('compare two vector clocks, throw exception when invalid',
          (vc1, vc2) {
    if (!vc1.isValid() || !vc2.isValid()) {
      expect(
          () => VectorClock.compare(vc1, vc2),
          throwsA(predicate((e) =>
              e is VclockException &&
              e.toString() == 'Invalid vector clock inputs')));
    }
  });
}
