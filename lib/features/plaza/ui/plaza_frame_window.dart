import 'dart:math' as math;
import 'dart:typed_data';

/// A bounded frame-time window: insertion overwrites one sample instead of
/// shifting a list. Aggregate stats are read only when the HUD is published.
class PlazaFrameWindow {
  PlazaFrameWindow({int capacity = 120}) : _samples = _allocate(capacity);

  static Float64List _allocate(int capacity) {
    if (capacity < 1) throw ArgumentError.value(capacity, 'capacity');
    return Float64List(capacity);
  }

  final Float64List _samples;
  var _cursor = 0;
  var _count = 0;
  double _sum = 0;

  int get count => _count;
  double get average => _count == 0 ? 0 : _sum / _count;
  double get worst => _samples.take(_count).fold(0, math.max);

  void add(double milliseconds) {
    if (!milliseconds.isFinite || milliseconds <= 0) return;
    _sum += milliseconds - _samples[_cursor];
    _samples[_cursor] = milliseconds;
    _cursor = (_cursor + 1) % _samples.length;
    if (_count < _samples.length) _count++;
  }
}
