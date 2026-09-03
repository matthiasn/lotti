import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/ui/checklist_ticks.dart';

void main() {
  test('toggles per task and index, counting and notifying', () {
    final ticks = ChecklistTicks();
    var notified = 0;
    ticks.addListener(() => notified++);
    expect(ticks.isTicked('a', 0), isFalse);
    expect(ticks.tickedCount('a'), 0);

    ticks.toggle('a', 0);
    expect(ticks.isTicked('a', 0), isTrue);
    expect(ticks.isTicked('a', 1), isFalse);
    expect(ticks.isTicked('b', 0), isFalse);
    expect(ticks.tickedCount('a'), 1);

    ticks.toggle('a', 2);
    expect(ticks.tickedCount('a'), 2);
    ticks.toggle('a', 0);
    expect(ticks.isTicked('a', 0), isFalse);
    expect(ticks.tickedCount('a'), 1);
    expect(notified, 3);
  });
}
