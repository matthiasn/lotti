import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/queue/live_anchor_hold.dart';

void main() {
  late LiveAnchorHold hold;

  setUp(() => hold = LiveAnchorHold());

  test('holds nothing until an event arrives', () {
    expect(hold.arrived, 0);
    expect(hold.isSealed, isTrue);
  });

  test('an arrival holds until a seal covers it', () {
    hold.noteArrival();
    expect(hold.isSealed, isFalse);

    hold.seal(1, generation: hold.generation);
    expect(hold.isSealed, isTrue);
  });

  test('a seal covers its snapshot, not what arrived after it', () {
    hold.noteArrival();
    final upTo = hold.arrived;
    hold
      ..noteArrival()
      ..seal(upTo, generation: hold.generation);
    expect(hold.isSealed, isFalse);

    hold.seal(hold.arrived, generation: hold.generation);
    expect(hold.isSealed, isTrue);
  });

  test('an older snapshot never uncovers what a newer seal covered', () {
    hold
      ..noteArrival()
      ..noteArrival()
      ..seal(2, generation: hold.generation)
      ..seal(1, generation: hold.generation);
    expect(hold.isSealed, isTrue);
  });

  test('a seal snapshotted before a reset covers nothing after it', () {
    hold
      ..noteArrival()
      ..noteArrival();
    final staleGeneration = hold.generation;
    hold
      ..reset()
      ..noteArrival()
      ..seal(2, generation: staleGeneration);

    expect(hold.arrived, 1);
    expect(hold.isSealed, isFalse);
  });
}
