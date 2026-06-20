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

/// Holds a target widget at a fixed on-screen position for [holdDuration] after
/// [hold] is called — long enough to absorb a layout change above it that lands
/// on a *later* frame than the trigger.
///
/// Two cases this covers when an AI proposal is confirmed on the task page:
///  - a checklist item is **added** above the AI card (immediate growth), and
///  - a checklist item is **checked off** above it, whose row only collapses
///    after a delay (the row holds the checkmark, then cross-fades out — see
///    `checklistCompletionAnimationDuration` + `checklistCompletionFadeDuration`).
///    The shrink therefore arrives ~a second after the tap, well after a short
///    frame burst would have ended; [holdDuration] must span that gap.
///
/// On [hold] it captures the target's current viewport top (via [locate]) and,
/// each frame until the deadline, jumps [controller] so the target returns to
/// that captured top whenever it drifts. Because the window is long, the hold
/// **releases early the moment the user scrolls** (an offset change it did not
/// itself make) so it never fights a deliberate scroll. Correction math is the
/// pure [anchorCorrectionOffset]; the loop is driven by post-frame callbacks so
/// it is exercised by a normal widget `pump`, and the deadline is measured from
/// the frame timestamps so it is frame-rate independent and deterministic.
class ScrollAnchor {
  ScrollAnchor({
    required this.controller,
    required this.locate,
    this.holdDuration = const Duration(milliseconds: 400),
    this.tolerance = 0.5,
    SchedulerBinding? scheduler,
  }) : _scheduler = scheduler ?? SchedulerBinding.instance;

  /// The scroll controller to adjust.
  final ScrollController controller;

  /// Returns the anchored widget's current viewport-relative top, or `null`
  /// when it is not currently laid out / attached.
  final double? Function() locate;

  /// How long to keep holding after a [hold] call. Measured from frame
  /// timestamps, so it is independent of the device refresh rate.
  final Duration holdDuration;

  /// Drift below this (logical px) is ignored.
  final double tolerance;

  final SchedulerBinding _scheduler;

  double? _anchorTop;

  /// Frame-timestamp deadline; set lazily on the first frame of a hold so it is
  /// relative to that frame's clock (which `pump` advances deterministically).
  Duration? _deadline;

  /// The offset this anchor last established. If the controller's offset moves
  /// away from it between frames, the user scrolled and the hold bows out.
  double? _expectedOffset;

  bool _scheduled = false;
  bool _disposed = false;

  /// Whether a hold is currently active (visible for tests).
  @visibleForTesting
  bool get isHolding => _anchorTop != null;

  /// Begin holding: capture the current anchor position and start correcting.
  void hold() {
    if (_disposed) return;
    final top = locate();
    if (top == null || holdDuration <= Duration.zero) return;
    _anchorTop = top;
    _deadline = null;
    _expectedOffset = controller.positions.length == 1
        ? controller.offset
        : null;
    _schedule();
  }

  void _schedule() {
    if (_scheduled || _disposed) return;
    _scheduled = true;
    _scheduler
      ..addPostFrameCallback((timeStamp) {
        _scheduled = false;
        if (_disposed || _anchorTop == null) return;
        _deadline ??= timeStamp + holdDuration;
        if (timeStamp >= _deadline!) {
          _anchorTop = null;
          return;
        }
        _correctOnce();
        // A user scroll (or any released state) ends the hold immediately.
        if (_anchorTop == null) return;
        _schedule();
      })
      // A post-frame callback alone does not request a frame, so once the
      // page stops changing the hold would stall (and could later resume on
      // an unrelated frame). Explicitly request the next frame so the loop
      // keeps draining toward its deadline and always releases itself.
      ..scheduleFrame();
  }

  void _correctOnce() {
    final anchorTop = _anchorTop;
    // `positions.length != 1` guards both the no-client case and the
    // multi-client case: `controller.position` / `.offset` assert when the
    // controller drives more than one scroll view (possible during route
    // transitions or page-state reuse), which `hasClients` would not catch.
    if (anchorTop == null || controller.positions.length != 1) return;
    // The offset moved away from what we set → the user is scrolling. Release
    // rather than yank them back; the long hold window must never fight input.
    final expected = _expectedOffset;
    if (expected != null && (controller.offset - expected).abs() > tolerance) {
      _anchorTop = null;
      return;
    }
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
    if (target != null) {
      controller.jumpTo(target);
      _expectedOffset = target;
    } else {
      _expectedOffset = controller.offset;
    }
  }

  /// Stop any in-flight hold and release resources.
  void dispose() {
    _disposed = true;
    _anchorTop = null;
  }
}
