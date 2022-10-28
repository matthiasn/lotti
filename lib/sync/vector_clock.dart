// ignore_for_file: constant_identifier_names

import 'dart:math';

import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';

class VclockException implements Exception {
  @override
  String toString() => 'Invalid vector clock inputs';
}

enum VclockStatus {
  equal,
  concurrent,
  a_gt_b,
  b_gt_a,
}

class VectorClock extends Equatable {
  const VectorClock(this.vclock);

  factory VectorClock.fromJson(Map<String, dynamic> json) =>
      VectorClock(Map<String, int>.from(json));

  final Map<String, int> vclock;

  // Compares two vector clocks. A and B are maps with node id strings as keys
  // and an integer as value, which is the offset on the node associated with
  // persisting the particular entry. See examples in the tests.

  // Will return VclockStatus.a_gt_b if clock A dominates B, VclockStatus.b_gt_a
  // in the opposite case, VclockStatus.equal if they are the same, and
  // VclockStatus.concurrent if no strict order could be determined.

  // Throws an exception when input is invalid.
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
