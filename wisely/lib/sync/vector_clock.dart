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
  Map<String, int> vclock = Map<String, int>();

  VectorClock(this.vclock);

  // Compares two vector clocks. A and B are maps with node id strings as keys
  // and an integer as value, which is the offset on the node associated with
  // persisting the particular entry. See examples in the tests.

  // Will return VclockStatus.a_gt_b if clock A dominates B, VclockStatus.b_gt_a
  // in the opposite case, VclockStatus.equal if they are the same, and
  // VclockStatus.concurrent if no strict order could be determined.

  // Throws an exception when input is invalid.
  static VclockStatus compare(VectorClock vc1, VectorClock vc2) {
    Set<VclockStatus> comparisons = <VclockStatus>{};
    Set<String> nodeIds = <String>{};
    Set<int> counters = <int>{};

    counters.addAll(vc1.vclock.values);
    counters.addAll(vc2.vclock.values);

    for (int counter in counters) {
      if (counter < 1) {
        throw VclockException();
      }
    }

    if (const DeepCollectionEquality().equals(vc1.vclock, vc2.vclock)) {
      return VclockStatus.equal;
    }

    nodeIds.addAll(vc1.vclock.keys);
    nodeIds.addAll(vc2.vclock.keys);

    for (String nodeId in nodeIds) {
      int counterA = vc1.vclock[nodeId] ?? 0;
      int counterB = vc2.vclock[nodeId] ?? 0;

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
