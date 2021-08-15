import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:wisely/sync/vector_clock.dart';

String nodeId1 = Uuid().v1();
String nodeId2 = Uuid().v1();
String nodeId3 = Uuid().v1();

void main() {
  test('Compare two empty clocks', () {
    Map<String, int> vc1 = new Map();
    Map<String, int> vc2 = new Map();

    expect(VectorClock.compare(vc1, vc2), VclockStatus.equal);
  });

  test('Compare two similar clocks', () {
    Map<String, int> vc1 = new Map();
    vc1.addEntries([
      MapEntry(nodeId1, 1),
      MapEntry(nodeId2, 1),
      MapEntry(nodeId3, 1),
    ]);
    Map<String, int> vc2 = new Map();
    vc2.addEntries([
      MapEntry(nodeId3, 1),
      MapEntry(nodeId2, 1),
      MapEntry(nodeId1, 1),
    ]);
    expect(VectorClock.compare(vc1, vc2), VclockStatus.equal);
  });

  test('Compare two concurrent clocks', () {
    Map<String, int> vc1 = new Map();
    vc1.addEntries([
      MapEntry(nodeId1, 1),
      MapEntry(nodeId2, 2),
      MapEntry(nodeId3, 4),
    ]);

    Map<String, int> vc2 = new Map();
    vc2.addEntries([
      MapEntry(nodeId1, 3),
      MapEntry(nodeId2, 2),
      MapEntry(nodeId3, 3),
    ]);
    expect(VectorClock.compare(vc1, vc2), VclockStatus.concurrent);
  });

  test('Compare two clocks where vc1 is greater than vc2', () {
    Map<String, int> vc1 = new Map();
    vc1.addEntries([
      MapEntry(nodeId1, 3),
      MapEntry(nodeId2, 3),
      MapEntry(nodeId3, 3),
    ]);

    Map<String, int> vc2 = new Map();
    vc2.addEntries([
      MapEntry(nodeId1, 1),
      MapEntry(nodeId2, 2),
      MapEntry(nodeId3, 3),
    ]);
    expect(VectorClock.compare(vc1, vc2), VclockStatus.a_gt_b);
  });

  test('Compare two clocks where vc2 is greater than vc1', () {
    Map<String, int> vc1 = new Map();
    vc1.addEntries([
      MapEntry(nodeId1, 1),
      MapEntry(nodeId2, 2),
      MapEntry(nodeId3, 3),
    ]);

    Map<String, int> vc2 = new Map();
    vc2.addEntries([
      MapEntry(nodeId1, 3),
      MapEntry(nodeId2, 3),
      MapEntry(nodeId3, 3),
    ]);
    expect(VectorClock.compare(vc1, vc2), VclockStatus.b_gt_a);
  });

  test('Throws exception on invalid input', () {
    Map<String, int> vc1 = new Map();
    vc1.addEntries([
      MapEntry(nodeId1, -1),
      MapEntry(nodeId2, 2),
      MapEntry(nodeId3, 3),
    ]);

    Map<String, int> vc2 = new Map();
    vc2.addEntries([
      MapEntry(nodeId1, -3),
      MapEntry(nodeId2, 3),
      MapEntry(nodeId3, 3),
    ]);

    expect(
        () => VectorClock.compare(vc1, vc2), throwsA(isA<VclockException>()));
  });
}
