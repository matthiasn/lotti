import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/vector_clock.dart';

// Fixed, deterministic node IDs — VectorClock treats these purely as opaque map
// keys, so concrete literals keep the tests reproducible (the previous
// Uuid().v1() values were time-based and non-deterministic).
const String nodeId1 = 'node-1';
const String nodeId2 = 'node-2';
const String nodeId3 = 'node-3';

void main() {
  test('Compare two empty clocks', () {
    const vc1 = VectorClock({});
    const vc2 = VectorClock({});

    expect(VectorClock.compare(vc1, vc2), VclockStatus.equal);
  });

  test('Compare two similar clocks', () {
    const vc1 = VectorClock({nodeId1: 0, nodeId2: 1, nodeId3: 1});
    const vc2 = VectorClock({nodeId1: 0, nodeId2: 1, nodeId3: 1});

    expect(VectorClock.compare(vc1, vc2), VclockStatus.equal);
  });

  test('Compare two concurrent clocks', () {
    const vc1 = VectorClock({nodeId1: 1, nodeId2: 2, nodeId3: 4});
    const vc2 = VectorClock({nodeId1: 3, nodeId2: 2, nodeId3: 3});

    expect(VectorClock.compare(vc1, vc2), VclockStatus.concurrent);
  });

  test('Compare two clocks where vc1 is greater than vc2', () {
    const vc1 = VectorClock({nodeId1: 3, nodeId2: 3, nodeId3: 3});
    const vc2 = VectorClock({nodeId1: 1, nodeId2: 2, nodeId3: 3});
    expect(VectorClock.compare(vc1, vc2), VclockStatus.a_gt_b);
  });

  test('Compare two clocks where vc2 is greater than vc1', () {
    const vc1 = VectorClock({nodeId1: 1, nodeId2: 2, nodeId3: 3});
    const vc2 = VectorClock({nodeId1: 3, nodeId2: 3, nodeId3: 3});
    expect(VectorClock.compare(vc1, vc2), VclockStatus.b_gt_a);
  });

  test('Throws exception on invalid input', () {
    const vc1 = VectorClock({nodeId1: -1, nodeId2: 2, nodeId3: 3});
    const vc2 = VectorClock({nodeId1: -3, nodeId2: 3, nodeId3: 3});

    expect(
      () => VectorClock.compare(vc1, vc2),
      throwsA(
        predicate(
          (e) =>
              e is VclockException &&
              e.toString() == 'Invalid vector clock inputs',
        ),
      ),
    );
  });

  test('Vector clock toString as expected', () {
    const vc = VectorClock({'nodeId1': 0, 'nodeId2': 1});
    expect(vc.toString(), '{nodeId1: 0, nodeId2: 1}');
  });
}
