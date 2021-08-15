import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:wisely/sync/vector_clock.dart';

void main() {
  test('Compare two empty clocks', () {
    Map<Uuid, int> vc1 = new Map();
    Map<Uuid, int> vc2 = new Map();

    expect(VectorClock.compare(vc1, vc2), VclockStatus.equal);
  });
}
