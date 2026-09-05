import 'dart:async';
import 'dart:developer' show Timeline;

import 'package:flutter/scheduler.dart';

/// Requests only frames the scene will paint. A capped idle scene leaves no
/// recurring vsync callback behind; input can cancel the wait immediately.
class PlazaFramePacer {
  PlazaFramePacer({
    required this.onFrame,
    required this.cap,
    this.nowMicros = _nowMicros,
    int Function(FrameCallback)? schedule,
    void Function(int)? cancel,
  }) : _schedule = schedule ?? SchedulerBinding.instance.scheduleFrameCallback,
       _cancel = cancel ?? SchedulerBinding.instance.cancelFrameCallbackWithId;

  static int _nowMicros() => Timeline.now;

  final void Function(Duration) onFrame;
  final double? Function() cap;
  final int Function() nowMicros;
  final int Function(FrameCallback) _schedule;
  final void Function(int) _cancel;
  Timer? _timer;
  int? _frame;
  int? _requestedAt;
  bool _running = false;
  bool _disposed = false;
  Duration? _lastTimestamp;
  Duration _elapsed = Duration.zero;

  void start() {
    if (_disposed || _running) return;
    _running = true;
    requestFrame();
  }

  /// Wakes a capped scene on interaction, coalescing requests before vsync.
  void requestFrame() {
    if (!_running) return;
    _timer?.cancel();
    _timer = null;
    if (_frame == null) {
      _requestedAt = nowMicros();
      _frame = _schedule(_paint);
    }
  }

  void _paint(Duration timestamp) {
    _frame = null;
    if (!_running) return;
    final last = _lastTimestamp;
    if (last != null) _elapsed += timestamp - last;
    _lastTimestamp = timestamp;
    onFrame(_elapsed);
    if (!_running || _frame != null) return;
    final fps = cap();
    if (fps == null) {
      requestFrame();
    } else {
      // Pace requests, not completed callbacks. Engine delivery and frame
      // preparation consume this interval; adding a whole wait after them
      // drifts below the cap (30 Hz can become 20 Hz on a 60 Hz display).
      final due = _requestedAt! + (1e6 / fps).round();
      final remaining = due - nowMicros();
      if (remaining <= 0) {
        requestFrame();
      } else {
        _timer = Timer(Duration(microseconds: remaining), requestFrame);
      }
    }
  }

  /// Suspends rendering and the animation clock while the app is hidden.
  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    final pending = _frame;
    if (pending != null) _cancel(pending);
    _frame = null;
    _requestedAt = null;
    _lastTimestamp = null;
  }

  void dispose() {
    stop();
    _disposed = true;
  }
}
