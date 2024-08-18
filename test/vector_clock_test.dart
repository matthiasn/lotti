import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:uuid/uuid.dart';

String nodeId1 = const Uuid().v1();
String nodeId2 = const Uuid().v1();
String nodeId3 = const Uuid().v1();

void main() {
  test('Compare two empty clocks', () {
    const vc1 = VectorClock({});
    const vc2 = VectorClock({});

    expect(VectorClock.compare(vc1, vc2), VclockStatus.equal);
  });

  test('Compare two similar clocks', () {
    final vc1 = VectorClock({nodeId1: 0, nodeId2: 1, nodeId3: 1});
    final vc2 = VectorClock({nodeId1: 0, nodeId2: 1, nodeId3: 1});

    expect(VectorClock.compare(vc1, vc2), VclockStatus.equal);
  });

  test('Compare two concurrent clocks', () {
    final vc1 = VectorClock({nodeId1: 1, nodeId2: 2, nodeId3: 4});
    final vc2 = VectorClock({nodeId1: 3, nodeId2: 2, nodeId3: 3});

    expect(VectorClock.compare(vc1, vc2), VclockStatus.concurrent);
  });

  test('Compare two clocks where vc1 is greater than vc2', () {
    final vc1 = VectorClock({nodeId1: 3, nodeId2: 3, nodeId3: 3});
    final vc2 = VectorClock({nodeId1: 1, nodeId2: 2, nodeId3: 3});
    expect(VectorClock.compare(vc1, vc2), VclockStatus.a_gt_b);
  });

  test('Compare two clocks where vc2 is greater than vc1', () {
    final vc1 = VectorClock({nodeId1: 1, nodeId2: 2, nodeId3: 3});
    final vc2 = VectorClock({nodeId1: 3, nodeId2: 3, nodeId3: 3});
    expect(VectorClock.compare(vc1, vc2), VclockStatus.b_gt_a);
  });

  test('Throws exception on invalid input', () {
    final vc1 = VectorClock({nodeId1: -1, nodeId2: 2, nodeId3: 3});
    final vc2 = VectorClock({nodeId1: -3, nodeId2: 3, nodeId3: 3});

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
