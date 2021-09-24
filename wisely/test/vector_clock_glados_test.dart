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

void main() {
  Any.setDefault<VectorClock>(any.vc);

  Glados2<VectorClock, VectorClock>().test('compare two vector clocks',
      (vc1, vc2) {
    if (const DeepCollectionEquality().equals(vc1.vclock, vc2.vclock)) {
      expect(VectorClock.compare(vc1, vc2), VclockStatus.equal);
    } else if (vc1.get('a') >= vc2.get('a') &&
        vc1.get('b') >= vc2.get('b') &&
        (vc1.get('a') + vc1.get('b')) > (vc2.get('a') + vc2.get('b'))) {
      expect(VectorClock.compare(vc1, vc2), VclockStatus.a_gt_b);
    } else if (vc1.get('a') <= vc2.get('a') &&
        vc1.get('b') <= vc2.get('b') &&
        (vc1.get('a') + vc1.get('b')) < (vc2.get('a') + vc2.get('b'))) {
      expect(VectorClock.compare(vc1, vc2), VclockStatus.b_gt_a);
    } else {
      expect(VectorClock.compare(vc1, vc2), VclockStatus.concurrent);
    }
  });

  Glados2<VectorClock, VectorClock>(any.vc3, any.vc3)
      .test('compare two vector clocks with three nodes', (vc1, vc2) {
    if (const DeepCollectionEquality().equals(vc1.vclock, vc2.vclock)) {
      expect(VectorClock.compare(vc1, vc2), VclockStatus.equal);
    } else if (vc1.get('a') >= vc2.get('a') &&
        vc1.get('b') >= vc2.get('b') &&
        vc1.get('c') >= vc2.get('c') &&
        (vc1.get('a') + vc1.get('b') + vc1.get('c')) >
            (vc2.get('a') + vc2.get('b') + vc2.get('c'))) {
      expect(VectorClock.compare(vc1, vc2), VclockStatus.a_gt_b);
    } else if (vc1.get('a') <= vc2.get('a') &&
        vc1.get('b') <= vc2.get('b') &&
        vc1.get('c') <= vc2.get('c') &&
        (vc1.get('a') + vc1.get('b') + vc1.get('c')) <
            (vc2.get('a') + vc2.get('b') + vc2.get('c'))) {
      expect(VectorClock.compare(vc1, vc2), VclockStatus.b_gt_a);
    } else {
      expect(VectorClock.compare(vc1, vc2), VclockStatus.concurrent);
    }
  });

  Glados2<VectorClock, VectorClock>(any.vc, any.vc3)
      .test('compare two vector clocks, one with three nodes', (vc1, vc2) {
    if (const DeepCollectionEquality().equals(vc1.vclock, vc2.vclock)) {
      expect(VectorClock.compare(vc1, vc2), VclockStatus.equal);
    } else if (vc1.get('a') >= vc2.get('a') &&
        vc1.get('b') >= vc2.get('b') &&
        vc1.get('c') >= vc2.get('c') &&
        (vc1.get('a') + vc1.get('b') + vc1.get('c')) >
            (vc2.get('a') + vc2.get('b') + vc2.get('c'))) {
      expect(VectorClock.compare(vc1, vc2), VclockStatus.a_gt_b);
    } else if (vc1.get('a') <= vc2.get('a') &&
        vc1.get('b') <= vc2.get('b') &&
        vc1.get('c') <= vc2.get('c') &&
        (vc1.get('a') + vc1.get('b') + vc1.get('c')) <
            (vc2.get('a') + vc2.get('b') + vc2.get('c'))) {
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
          () => VectorClock.compare(vc1, vc2), throwsA(isA<VclockException>()));
    }
  });
}
