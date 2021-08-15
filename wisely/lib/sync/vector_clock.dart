import 'package:collection/collection.dart';

class VclockException implements Exception {
  String errMsg() => 'Invalid vector clock inputs';

  VclockException();
}

enum VclockStatus {
  equal,
  concurrent,
  a_gt_b,
  b_gt_a,
}

class VectorClock {
  Map<String, int> vclock = new Map<String, int>();

  VectorClock(this.vclock);

  // Compares two vector clocks. A and B are maps with node id strings as keys
  // and an integer as value, which is the offset on the node associated with
  // persisting the particular entry. See examples in the tests.

  // Will return VclockStatus.a_gt_b if clock A dominates B, VclockStatus.b_gt_a
  // in the opposite case, VclockStatus.equal if they are the same, and
  // VclockStatus.concurrent if no strict order could be determined.

  // Throws an exception when input is invalid.
  static VclockStatus compare(Map<String, int> vc1, Map<String, int> vc2) {
    Set<VclockStatus> comparisons = new Set<VclockStatus>();
    Set<String> nodeIds = new Set<String>();
    Set<int> counters = new Set<int>();

    counters.addAll(vc1.values);
    counters.addAll(vc2.values);

    for (int counter in counters) {
      if (counter < 1) {
        throw VclockException();
      }
    }

    if (DeepCollectionEquality().equals(vc1, vc2)) {
      return VclockStatus.equal;
    }

    nodeIds.addAll(vc1.keys);
    nodeIds.addAll(vc2.keys);

    for (String nodeId in nodeIds) {
      int counterA = vc1[nodeId] ?? 0;
      int counterB = vc2[nodeId] ?? 0;

      if (counterA == counterB) {
        comparisons.add(VclockStatus.equal);
      } else if (counterA > counterB) {
        comparisons.add(VclockStatus.a_gt_b);
      } else if (counterB > counterA) {
        comparisons.add(VclockStatus.b_gt_a);
      }
    }

    if (comparisons.contains(VclockStatus.a_gt_b) &&
        !comparisons.contains(VclockStatus.b_gt_a)) {
      return VclockStatus.a_gt_b;
    }

    if (comparisons.contains(VclockStatus.b_gt_a) &&
        !comparisons.contains(VclockStatus.a_gt_b)) {
      return VclockStatus.b_gt_a;
    }

    return VclockStatus.concurrent;
  }
}
