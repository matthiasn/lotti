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
/// host's offset at write time. Two clocks are causally ordered when one
/// dominates the other component-wise (see [compare]); when neither does, the
/// edits are concurrent and surface as a conflict. [merge] takes the
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
  /// Missing node keys are treated as counter 0. Throws [VclockException] if
  /// either operand is invalid (contains a negative counter).
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
      final counterA = vc1.get(nodeId);
      final counterB = vc2.get(nodeId);

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
