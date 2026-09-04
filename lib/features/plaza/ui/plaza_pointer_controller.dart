import 'package:flutter/gestures.dart';

/// Distinguishes a short primary-button tap from a camera drag. Owns the
/// active pointer so release and cancellation always end movement.
class PlazaPointerController {
  int? _pointer;
  Offset? _down;
  double _downAt = 0;
  bool _dragging = false;

  bool get dragging => _dragging;

  void down(PointerDownEvent event, double seconds) {
    if (event.buttons != kPrimaryButton || _pointer != null) return;
    _pointer = event.pointer;
    _down = event.localPosition;
    _downAt = seconds;
    _dragging = false;
  }

  /// The look delta after crossing the existing six-pixel drag threshold.
  Offset? move(PointerMoveEvent event) {
    final down = _down;
    if (event.pointer != _pointer || down == null) return null;
    if (event.buttons == 0) {
      cancel(event.pointer);
      return null;
    }
    if ((event.localPosition - down).distance > 6) _dragging = true;
    return _dragging ? event.delta : null;
  }

  /// Returns the tap position, if any, and releases all gesture state.
  Offset? up(PointerUpEvent event, double seconds) {
    if (event.pointer != _pointer) return null;
    final tap = !_dragging && seconds - _downAt <= 0.25;
    cancel(event.pointer);
    return tap ? event.localPosition : null;
  }

  void cancel(int pointer) {
    if (pointer != _pointer) return;
    _pointer = null;
    _down = null;
    _dragging = false;
  }
}
