import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';

enum VclockStatus {
  equal,
  concurrent,
  a_gt_b,
  b_gt_a,
}

class VectorClock {
  Map<Uuid, int> vclock = new Map();

  VectorClock(this.vclock);

  static VclockStatus compare(Map<Uuid, int> vc1, Map<Uuid, int> vc2) {
    if (DeepCollectionEquality().equals(vc1, vc2)) {
      return VclockStatus.equal;
    }

    throw ("failed to compare vector clocks");
  }
}
