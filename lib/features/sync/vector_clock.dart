// ignore_for_file: constant_identifier_names

import 'dart:math';

import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';

/// Thrown by [VectorClock.compare] when either operand contains a negative
/// counter (an invalid clock).
class VclockException implements Exception {
  @override
  String toString() => 'Invalid vector clock inputs';
}

/// Result of [VectorClock.compare]: whether clock A dominates B
/// ([a_gt_b]), B dominates A ([b_gt_a]), they are identical ([equal]), or
/// neither strictly dominates ([concurrent] — the conflict case).
enum VclockStatus {
  equal,
  concurrent,
  a_gt_b,
  b_gt_a,
}

/// A CRDT vector clock: a map from node id to a monotonically increasing
/// per-node counter, used to establish causal order between sync entries
/// across devices without a global clock.
///
/// One key exists per host that has ever written the entry; the value is that
/// host's offset at write time. A present key, whatever its counter, says the
/// host wrote; an absent key says it did not. Two clocks are causally ordered
/// when one dominates the other component-wise (see [compare]); when neither
/// does, the edits are concurrent and surface as a conflict. [merge] takes the
/// per-node maximum to fold two clocks into one.
class VectorClock extends Equatable {
  const VectorClock(this.vclock);

  factory VectorClock.fromJson(Map<String, dynamic> json) =>
      VectorClock(Map<String, int>.from(json));

  final Map<String, int> vclock;

  /// Establishes the causal relationship between [vc1] and [vc2].
  ///
  /// Returns [VclockStatus.a_gt_b] when every component of [vc1] is >= [vc2]
  /// and at least one is strictly greater (A dominates B), [VclockStatus.b_gt_a]
  /// in the opposite case, [VclockStatus.equal] when the clocks are identical,
  /// and [VclockStatus.concurrent] when some components favour each side — the
  /// signal that the two versions diverged and must be conflict-resolved.
  ///
  /// A node absent from a clock ranks below every counter it could carry, 0
  /// included (ADR 0080). A host's first counter is 0 on every host an older
  /// build created, so a write that extends a version by `host: 0` must
  /// dominate it rather than compare [VclockStatus.equal]. Only identical
  /// clocks are equal. Throws [VclockException] if either operand is invalid
  /// (contains a negative counter).
  static VclockStatus compare(VectorClock vc1, VectorClock vc2) {
    final comparisons = <VclockStatus>{};
    final nodeIds = <String>{};

    if (!vc1.isValid() || !vc2.isValid()) {
      throw VclockException();
    }

    if (const DeepCollectionEquality().equals(vc1.vclock, vc2.vclock)) {
      return VclockStatus.equal;
    }

    nodeIds
      ..addAll(vc1.vclock.keys)
      ..addAll(vc2.vclock.keys);

    for (final nodeId in nodeIds) {
      final counterA = vc1._rank(nodeId);
      final counterB = vc2._rank(nodeId);

      if (counterA == counterB) {
        comparisons.add(VclockStatus.equal);
      } else if (counterA > counterB) {
        comparisons.add(VclockStatus.a_gt_b);
      } else {
        comparisons.add(VclockStatus.b_gt_a);
      }
    }

    if (comparisons.length == 1 && comparisons.contains(VclockStatus.equal)) {
      return VclockStatus.equal;
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

  /// A total, replica-independent order on clocks, for choosing between two
  /// versions that [compare] finds concurrent. Compares each node's counter
  /// in sorted node order and returns the sign of the first difference: `1`
  /// if [a] is greater, `-1` if [b] is greater, `0` only if the clocks are
  /// identical. As in [compare], an absent node ranks below counter 0.
  /// Independent of map iteration order, so two devices comparing the same
  /// pair agree. It extends [compare]: a clock that dominates another is
  /// also greater here.
  static int compareCanonically(VectorClock a, VectorClock b) {
    final nodeIds = <String>{...a.vclock.keys, ...b.vclock.keys}.toList()
      ..sort();
    for (final nodeId in nodeIds) {
      final counterA = a._rank(nodeId);
      final counterB = b._rank(nodeId);
      if (counterA != counterB) return counterA > counterB ? 1 : -1;
    }
    return 0;
  }

  /// [node]'s counter for ordering: -1 when the node is absent, which ranks
  /// below every valid counter.
  int _rank(String node) => vclock[node] ?? -1;

  /// Folds two (possibly null) clocks into one by taking the per-node maximum
  /// across the union of their keys — the CRDT join. A null operand
  /// contributes nothing; merging two nulls yields an empty clock.
  // ignore: prefer_constructors_over_static_methods
  static VectorClock merge(VectorClock? vc1, VectorClock? vc2) {
    final merged = <String, int>{};
    final nodeIds = <String>{};

    if (vc1?.vclock != null) {
      nodeIds.addAll(vc1!.vclock.keys);
    }
    if (vc2?.vclock != null) {
      nodeIds.addAll(vc2!.vclock.keys);
    }

    for (final nodeId in nodeIds) {
      merged[nodeId] = max(
        vc1?.get(nodeId) ?? 0,
        vc2?.get(nodeId) ?? 0,
      );
    }

    return VectorClock(merged);
  }

  /// Merges an iterable of nullable VectorClocks into a deduplicated list.
  /// Returns null if no non-null clocks are provided.
  /// Uses Set for O(n) deduplication since VectorClock extends Equatable.
  static List<VectorClock>? mergeUniqueClocks(Iterable<VectorClock?> clocks) {
    final merged = clocks.whereType<VectorClock>().toSet().toList();
    return merged.isEmpty ? null : merged;
  }

  /// [node]'s counter, or 0 when the node is absent. For arithmetic such as
  /// [merge]; ordering distinguishes an absent node from counter 0 (see
  /// [compare]).
  int get(String node) {
    return vclock[node] ?? 0;
  }

  bool isValid() {
    final counters = <int>{}..addAll(vclock.values);

    for (final counter in counters) {
      if (counter < 0) {
        return false;
      }
    }
    return true;
  }

  @override
  String toString() {
    return vclock.toString();
  }

  Map<String, dynamic> toJson() => vclock;

  @override
  List<Object?> get props => [vclock];
}
