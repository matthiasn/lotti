import 'package:collection/collection.dart';
import 'package:glados/glados.dart';
import 'package:wisely/sync/vector_clock.dart';

extension AnyVectorClock on Any {
  Generator<VectorClock> get vc =>
      any.combine2(any.positiveIntOrZero, any.positiveIntOrZero,
          (int v1, int v2) {
        return VectorClock({'a': v1, 'b': v2});
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

  Glados2<VectorClock, VectorClock>(
          any.possiblyInvalidVc, any.possiblyInvalidVc)
      .test('compare two vector clocks, throw exception when invalid',
          (vc1, vc2) {
    if (vc1.get('a') < 0 ||
        vc2.get('a') < 0 ||
        vc1.get('b') < 0 ||
        vc2.get('b') < 0) {
      expect(
          () => VectorClock.compare(vc1, vc2), throwsA(isA<VclockException>()));
    }
  });
}
