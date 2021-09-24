import 'package:collection/collection.dart';
import 'package:glados/glados.dart';
import 'package:wisely/sync/vector_clock.dart';

extension AnyVectorClock on Any {
  Generator<VectorClock> get vc =>
      any.combine2(any.positiveIntOrZero, any.positiveIntOrZero,
          (int v1, int v2) {
        return VectorClock({'a': v1, 'b': v2});
      });
}

void main() {
  Any.setDefault<VectorClock>(any.vc);

  Glados2<VectorClock, VectorClock>().test('compare two vector clocks',
      (vc1, vc2) {
    if (const DeepCollectionEquality().equals(vc1.vclock, vc2.vclock)) {
      expect(VectorClock.compare(vc1, vc2), VclockStatus.equal);
    } else if ((vc1.vclock['a'] ?? 0) >= (vc2.vclock['a'] ?? 0) &&
        (vc1.vclock['b'] ?? 0) >= (vc2.vclock['b'] ?? 0) &&
        ((vc1.vclock['a'] ?? 0) + (vc1.vclock['b'] ?? 0)) >
            ((vc2.vclock['a'] ?? 0) + (vc2.vclock['b'] ?? 0))) {
      expect(VectorClock.compare(vc1, vc2), VclockStatus.a_gt_b);
    } else if ((vc1.vclock['a'] ?? 0) <= (vc2.vclock['a'] ?? 0) &&
        (vc1.vclock['b'] ?? 0) <= (vc2.vclock['b'] ?? 0) &&
        ((vc1.vclock['a'] ?? 0) + (vc1.vclock['b'] ?? 0)) <
            ((vc2.vclock['a'] ?? 0) + (vc2.vclock['b'] ?? 0))) {
      expect(VectorClock.compare(vc1, vc2), VclockStatus.b_gt_a);
    } else {
      expect(VectorClock.compare(vc1, vc2), VclockStatus.concurrent);
    }
  });
}
