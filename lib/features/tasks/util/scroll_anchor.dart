import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Pure helper: the scroll offset needed to hold an anchored widget visually
/// fixed in the viewport after content *above* it changed height.
///
/// [anchorTop] and [currentTop] are the widget's top in the same (global /
/// viewport) coordinate space; [currentOffset] is the controller's current
/// scroll offset. Returns the offset to jump to, clamped into
/// `[minScrollExtent, maxScrollExtent]`, or `null` when no correction is
/// needed (drift within [tolerance], or clamping would leave the offset
/// effectively unchanged — avoiding a pointless jitter jump every frame).
double? anchorCorrectionOffset({
  required double anchorTop,
  required double currentTop,
  required double currentOffset,
  required double minScrollExtent,
  required double maxScrollExtent,
  double tolerance = 0.5,
}) {
  final drift = currentTop - anchorTop;
  if (drift.abs() <= tolerance) return null;
  final target = currentOffset + drift;
  final clamped = math.min(math.max(target, minScrollExtent), maxScrollExtent);
  if ((clamped - currentOffset).abs() <= tolerance) return null;
  return clamped;
}

/// Holds a target widget at a fixed on-screen position across a short burst of
/// frames after [hold] is called — long enough to absorb an async layout
/// change above it (e.g. a checklist item added when an AI proposal is
/// confirmed, which would otherwise shove the AI card and the proposal the
/// user just tapped downward).
///
/// On [hold] it captures the target's current viewport top (via [locate]) and,
/// for the next [maxFrames] frames, jumps [controller] so the target returns
/// to that captured top whenever it drifts. The frame budget covers the gap
/// between the trigger and the relayout actually landing. Correction math is
/// the pure [anchorCorrectionOffset]; the loop is driven by post-frame
/// callbacks so it is exercised by a normal widget `pump`.
class ScrollAnchor {
  ScrollAnchor({
    required this.controller,
    required this.locate,
    this.maxFrames = 24,
    this.tolerance = 0.5,
    SchedulerBinding? scheduler,
  }) : _scheduler = scheduler ?? SchedulerBinding.instance;

  /// The scroll controller to adjust.
  final ScrollController controller;

  /// Returns the anchored widget's current viewport-relative top, or `null`
  /// when it is not currently laid out / attached.
  final double? Function() locate;

  /// How many frames to keep holding after a [hold] call.
  final int maxFrames;

  /// Drift below this (logical px) is ignored.
  final double tolerance;

  final SchedulerBinding _scheduler;

  double? _anchorTop;
  int _framesLeft = 0;
  bool _scheduled = false;
  bool _disposed = false;

  /// Whether a hold is currently active (visible for tests).
  @visibleForTesting
  bool get isHolding => _anchorTop != null;

  /// Begin holding: capture the current anchor position and start correcting.
  void hold() {
    if (_disposed) return;
    final top = locate();
    if (top == null || maxFrames <= 0) return;
    _anchorTop = top;
    _framesLeft = maxFrames;
    _schedule();
  }

  void _schedule() {
    if (_scheduled || _disposed) return;
    _scheduled = true;
    _scheduler
      ..addPostFrameCallback((_) {
        _scheduled = false;
        if (_disposed) return;
        // Decrement before correcting so a hold runs exactly [maxFrames]
        // corrections (not maxFrames + 1).
        if (_framesLeft <= 0) {
          _anchorTop = null;
          return;
        }
        _framesLeft--;
        _correctOnce();
        if (_framesLeft > 0) {
          _schedule();
        } else {
          _anchorTop = null;
        }
      })
      // A post-frame callback alone does not request a frame, so once the
      // page stops changing the hold would stall (and could later resume on
      // an unrelated frame). Explicitly request the next frame so the budget
      // drains promptly and the hold always releases itself.
      ..scheduleFrame();
  }

  void _correctOnce() {
    final anchorTop = _anchorTop;
    // `positions.length != 1` guards both the no-client case and the
    // multi-client case: `controller.position` / `.offset` assert when the
    // controller drives more than one scroll view (possible during route
    // transitions or page-state reuse), which `hasClients` would not catch.
    if (anchorTop == null || controller.positions.length != 1) return;
    final currentTop = locate();
    if (currentTop == null) return;
    final position = controller.position;
    final target = anchorCorrectionOffset(
      anchorTop: anchorTop,
      currentTop: currentTop,
      currentOffset: controller.offset,
      minScrollExtent: position.minScrollExtent,
      maxScrollExtent: position.maxScrollExtent,
      tolerance: tolerance,
    );
    if (target != null) controller.jumpTo(target);
  }

  /// Stop any in-flight hold and release resources.
  void dispose() {
    _disposed = true;
    _anchorTop = null;
    _framesLeft = 0;
  }
}
