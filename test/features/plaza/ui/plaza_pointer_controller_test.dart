import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/ui/debug_overlay.dart';
import 'package:lotti/features/plaza/ui/plaza_pointer_controller.dart';

void main() {
  test('releasing a drag allows auto mode to return to its idle cap', () {
    final pointer = PlazaPointerController()
      ..down(const PointerDownEvent(pointer: 1), 0);
    expect(
      pointer.move(
        const PointerMoveEvent(
          pointer: 1,
          position: Offset(10, 0),
          delta: Offset(10, 0),
        ),
      ),
      const Offset(10, 0),
    );
    expect(PlazaFrameRate.auto.capFor(moving: pointer.dragging), isNull);
    expect(pointer.up(const PointerUpEvent(pointer: 1), 0.1), isNull);
    expect(pointer.dragging, isFalse);
    expect(PlazaFrameRate.auto.capFor(moving: pointer.dragging), 15);
  });

  test('a short tap is returned once; a long press is ignored', () {
    final pointer = PlazaPointerController()
      ..down(const PointerDownEvent(pointer: 1), 0);
    expect(
      pointer.move(const PointerMoveEvent(pointer: 1, position: Offset(3, 0))),
      isNull,
    );
    const up = PointerUpEvent(pointer: 1, position: Offset(3, 0));
    expect(pointer.up(up, 0.1), const Offset(3, 0));
    expect(pointer.up(up, 0.1), isNull);
    pointer.down(const PointerDownEvent(pointer: 1), 1);
    expect(pointer.up(up, 2), isNull);
  });

  for (final lostButtons in [false, true]) {
    test('cancellation clears a drag (lost buttons: $lostButtons)', () {
      final pointer = PlazaPointerController()
        ..down(const PointerDownEvent(pointer: 1), 0)
        ..move(const PointerMoveEvent(pointer: 1, position: Offset(10, 0)));
      expect(pointer.dragging, isTrue);
      if (lostButtons) {
        pointer.move(const PointerMoveEvent(pointer: 1, buttons: 0));
      } else {
        pointer.cancel(1);
      }
      expect(pointer.dragging, isFalse);
      expect(pointer.up(const PointerUpEvent(pointer: 1), 0.1), isNull);
      pointer.down(const PointerDownEvent(pointer: 2), 1);
      expect(pointer.up(const PointerUpEvent(pointer: 2), 1.1), Offset.zero);
    });
  }

  test('secondary buttons and unrelated pointers cannot change a drag', () {
    final pointer = PlazaPointerController()
      ..down(const PointerDownEvent(pointer: 2, buttons: kSecondaryButton), 0);
    expect(pointer.up(const PointerUpEvent(pointer: 2), 0.1), isNull);
    pointer
      ..down(const PointerDownEvent(pointer: 1), 1)
      ..move(const PointerMoveEvent(pointer: 1, position: Offset(10, 0)))
      ..down(const PointerDownEvent(pointer: 2), 1.1)
      ..cancel(2);
    expect(pointer.up(const PointerUpEvent(pointer: 2), 1.2), isNull);
    expect(pointer.move(const PointerMoveEvent(pointer: 2)), isNull);
    expect(pointer.dragging, isTrue);
    pointer.up(const PointerUpEvent(pointer: 1), 1.2);
    expect(pointer.dragging, isFalse);
  });
}
