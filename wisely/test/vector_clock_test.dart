import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:wisely/sync/vector_clock.dart';

String nodeId1 = const Uuid().v1();
String nodeId2 = const Uuid().v1();
String nodeId3 = const Uuid().v1();

void main() {
  test('Compare two empty clocks', () {
    VectorClock vc1 = VectorClock({});
    VectorClock vc2 = VectorClock({});

    expect(VectorClock.compare(vc1, vc2), VclockStatus.equal);
  });

  test('Compare two similar clocks', () {
    VectorClock vc1 = VectorClock({nodeId1: 0, nodeId2: 1, nodeId3: 1});
    VectorClock vc2 = VectorClock({nodeId1: 0, nodeId2: 1, nodeId3: 1});

    expect(VectorClock.compare(vc1, vc2), VclockStatus.equal);
  });

  test('Compare two concurrent clocks', () {
    VectorClock vc1 = VectorClock({nodeId1: 1, nodeId2: 2, nodeId3: 4});
    VectorClock vc2 = VectorClock({nodeId1: 3, nodeId2: 2, nodeId3: 3});

    expect(VectorClock.compare(vc1, vc2), VclockStatus.concurrent);
  });

  test('Compare two clocks where vc1 is greater than vc2', () {
    VectorClock vc1 = VectorClock({nodeId1: 3, nodeId2: 3, nodeId3: 3});
    VectorClock vc2 = VectorClock({nodeId1: 1, nodeId2: 2, nodeId3: 3});
    expect(VectorClock.compare(vc1, vc2), VclockStatus.a_gt_b);
  });

  test('Compare two clocks where vc2 is greater than vc1', () {
    VectorClock vc1 = VectorClock({nodeId1: 1, nodeId2: 2, nodeId3: 3});
    VectorClock vc2 = VectorClock({nodeId1: 3, nodeId2: 3, nodeId3: 3});
    expect(VectorClock.compare(vc1, vc2), VclockStatus.b_gt_a);
  });

  test('Throws exception on invalid input', () {
    VectorClock vc1 = VectorClock({nodeId1: -1, nodeId2: 2, nodeId3: 3});
    VectorClock vc2 = VectorClock({nodeId1: -3, nodeId2: 3, nodeId3: 3});

    expect(
        () => VectorClock.compare(vc1, vc2), throwsA(isA<VclockException>()));
  });
}
