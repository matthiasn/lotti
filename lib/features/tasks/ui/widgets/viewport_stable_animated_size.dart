import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:lotti/features/design_system/theme/motion_tokens.dart';
import 'package:lotti/features/tasks/util/scroll_anchor.dart';

/// A task-details scroll controller that preserves visible content while an
/// armed off-screen region changes the scrollable's extent.
///
/// The correction is applied from [ScrollPosition.correctForNewDimensions],
/// where the viewport can repeat layout with the corrected offset before it
/// paints. Correcting from the changing descendant's own layout is too late:
/// the viewport has already selected that frame's paint transform, producing
/// a one-frame jump before the new offset takes effect.
class ViewportStableScrollController extends ScrollController {
  ViewportStableScrollController({
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
  }) {
    addListener(_releaseOnUnexpectedOffsetChange);
  }

  bool _isExplicitlyHolding = false;
  bool _isAnimatedSizeHolding = false;
  double _pendingExtentDelta = 0;
  double? _expectedOffset;
  Timer? _explicitReleaseTimer;
  Timer? _animatedSizeReleaseTimer;

  static const _tolerance = 1.0;

  bool get _isHolding => _isExplicitlyHolding || _isAnimatedSizeHolding;

  /// Explicitly preserves reported-region content until [duration] elapses.
  ///
  /// This hold is independent of the shorter automatic holds owned by
  /// [ViewportStableAnimatedSize], so an unrelated animation ending cannot
  /// release a checklist suggestion batch early.
  void hold(Duration duration) {
    if (duration <= Duration.zero) return;
    _beginHold();
    _isExplicitlyHolding = true;
    _explicitReleaseTimer?.cancel();
    _explicitReleaseTimer = Timer(duration, _releaseExplicitHold);
  }

  void _holdAnimatedSize(Duration duration) {
    if (duration <= Duration.zero) return;
    _beginHold();
    _isAnimatedSizeHolding = true;
    _animatedSizeReleaseTimer?.cancel();
    _animatedSizeReleaseTimer = Timer(duration, _releaseAnimatedSizeHold);
  }

  void _beginHold() {
    _expectedOffset = positions.length == 1 ? offset : null;
  }

  void _releaseOnUnexpectedOffsetChange() {
    if (!_isHolding || positions.length != 1) return;
    final expectedOffset = _expectedOffset;
    if (expectedOffset == null) return;
    if ((offset - expectedOffset).abs() > _tolerance) {
      _releaseAllHolds();
    }
  }

  void _releaseExplicitHold() {
    _explicitReleaseTimer?.cancel();
    _explicitReleaseTimer = null;
    _isExplicitlyHolding = false;
    _resetIfIdle();
  }

  void _releaseAnimatedSizeHold() {
    _animatedSizeReleaseTimer?.cancel();
    _animatedSizeReleaseTimer = null;
    _isAnimatedSizeHolding = false;
    _resetIfIdle();
  }

  void _releaseAllHolds() {
    _explicitReleaseTimer?.cancel();
    _explicitReleaseTimer = null;
    _animatedSizeReleaseTimer?.cancel();
    _animatedSizeReleaseTimer = null;
    _isExplicitlyHolding = false;
    _isAnimatedSizeHolding = false;
    _resetIfIdle();
  }

  void _resetIfIdle() {
    if (_isHolding) return;
    _pendingExtentDelta = 0;
    _expectedOffset = null;
  }

  void _releaseAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _releaseAnimatedSizeHold();
    });
  }

  void _reportExtentDelta(double delta) {
    if (!_isHolding || delta.abs() <= _tolerance) {
      return;
    }
    _queueExtentDelta(delta);
  }

  void _reportExplicitExtentDelta(double delta) {
    if (!_isExplicitlyHolding || delta.abs() <= _tolerance) {
      return;
    }
    _queueExtentDelta(delta);
  }

  void _queueExtentDelta(double delta) {
    _pendingExtentDelta += delta;
    // The total scroll extent can remain unchanged when unrelated content
    // below shrinks in the same frame. Flag the position so
    // applyContentDimensions still invokes correctForNewDimensions, where the
    // region-specific delta is applied at the viewport boundary.
    if (positions.length == 1) position.correctBy(0);
  }

  double _takePendingExtentDelta() {
    final delta = _pendingExtentDelta;
    _pendingExtentDelta = 0;
    return delta;
  }

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _ViewportStableScrollPosition(
      controller: this,
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
  }

  @override
  void dispose() {
    removeListener(_releaseOnUnexpectedOffsetChange);
    _releaseAllHolds();
    super.dispose();
  }
}

class _ViewportStableScrollPosition extends ScrollPositionWithSingleContext {
  _ViewportStableScrollPosition({
    required this.controller,
    required super.physics,
    required super.context,
    required super.initialPixels,
    required super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  final ViewportStableScrollController controller;

  @override
  bool correctForNewDimensions(
    ScrollMetrics oldPosition,
    ScrollMetrics newPosition,
  ) {
    if (!super.correctForNewDimensions(oldPosition, newPosition)) return false;
    if (isScrollingNotifier.value) {
      controller._releaseAllHolds();
      return true;
    }

    if (!controller._isHolding) return true;
    final delta = controller._takePendingExtentDelta();
    if (delta.abs() <= ViewportStableScrollController._tolerance) return true;
    final target = (pixels + delta).clamp(
      newPosition.minScrollExtent,
      newPosition.maxScrollExtent,
    );
    if ((target - pixels).abs() <= ViewportStableScrollController._tolerance) {
      return true;
    }
    controller._expectedOffset = target;
    correctPixels(target);
    return false;
  }
}

/// Enables viewport-stable dynamic-size animation for descendants of the task
/// details scroll view.
class TaskScrollStabilityScope extends InheritedWidget {
  const TaskScrollStabilityScope({
    required this.controller,
    required super.child,
    super.key,
  });

  final ScrollController controller;

  static ScrollController? maybeControllerOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<TaskScrollStabilityScope>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(TaskScrollStabilityScope oldWidget) {
    return controller != oldWidget.controller;
  }
}

/// Reports this region's height changes to the task-details scroll controller.
///
/// The reporter adds no animation of its own. While the controller is
/// explicitly held, every measured height delta is consumed from the
/// viewport's layout cycle before paint. This is intended for regions such as
/// checklists that already animate their inserted rows but can receive several
/// asynchronous mutations from one user action.
///
/// Outside [TaskScrollStabilityScope] this is a direct pass-through.
class ViewportStableSizeReporter extends StatelessWidget {
  const ViewportStableSizeReporter({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final controller = TaskScrollStabilityScope.maybeControllerOf(context);
    if (controller is! ViewportStableScrollController) return child;
    return _LayoutInvalidationReporter(
      onWillLayout: _noop,
      onHeightDelta: controller._reportExplicitExtentDelta,
      child: child,
    );
  }

  static void _noop() {}
}

/// Smoothly follows child height changes while keeping later visible content
/// stationary when this entire region is already above the viewport.
///
/// Outside [TaskScrollStabilityScope] this is a pass-through, which keeps the
/// behavior deliberately scoped to task details.
class ViewportStableAnimatedSize extends StatefulWidget {
  const ViewportStableAnimatedSize({
    required this.child,
    this.duration = MotionDurations.medium2,
    this.curve = MotionCurves.emphasizedDecelerate,
    super.key,
  });

  final Widget child;
  final Duration duration;
  final Curve curve;

  @override
  State<ViewportStableAnimatedSize> createState() =>
      _ViewportStableAnimatedSizeState();
}

class _ViewportStableAnimatedSizeState
    extends State<ViewportStableAnimatedSize> {
  ScrollController? _controller;
  bool _shouldReportHeightDelta = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextController = TaskScrollStabilityScope.maybeControllerOf(context);
    if (identical(nextController, _controller)) return;
    _controller = nextController;
  }

  @override
  void didUpdateWidget(ViewportStableAnimatedSize oldWidget) {
    super.didUpdateWidget(oldWidget);
    _holdIfFullyAboveViewport();
  }

  double? _bottomGlobal() {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return null;
    }
    return renderObject
        .localToGlobal(
          Offset(0, renderObject.size.height),
        )
        .dy;
  }

  double? _viewportTopGlobal() {
    return viewportTopGlobal(context.findRenderObject());
  }

  void _holdIfFullyAboveViewport() {
    _shouldReportHeightDelta = false;
    final bottom = _bottomGlobal();
    final viewportTop = _viewportTopGlobal();
    if (bottom == null || viewportTop == null) return;
    final controller = _controller;
    if (bottom <= viewportTop && controller is ViewportStableScrollController) {
      _shouldReportHeightDelta = true;
      controller._holdAnimatedSize(widget.duration + MotionDurations.short2);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) return widget.child;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return _LayoutInvalidationReporter(
      onWillLayout: _holdIfFullyAboveViewport,
      onHeightDelta: (delta) {
        final controller = _controller;
        if (_shouldReportHeightDelta &&
            controller is ViewportStableScrollController) {
          controller._reportExtentDelta(delta);
        }
      },
      child: AnimatedSize(
        alignment: Alignment.topCenter,
        duration: reduceMotion ? Duration.zero : widget.duration,
        curve: widget.curve,
        onEnd: () {
          final controller = _controller;
          if (controller is ViewportStableScrollController) {
            controller._releaseAfterFrame();
          }
        },
        child: widget.child,
      ),
    );
  }
}

class _LayoutInvalidationReporter extends SingleChildRenderObjectWidget {
  const _LayoutInvalidationReporter({
    required this.onWillLayout,
    required this.onHeightDelta,
    required super.child,
  });

  final VoidCallback onWillLayout;
  final ValueChanged<double> onHeightDelta;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderLayoutInvalidationReporter(
      onWillLayout: onWillLayout,
      onHeightDelta: onHeightDelta,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderLayoutInvalidationReporter renderObject,
  ) {
    renderObject
      ..onWillLayout = onWillLayout
      ..onHeightDelta = onHeightDelta;
  }
}

class _RenderLayoutInvalidationReporter extends RenderProxyBox {
  _RenderLayoutInvalidationReporter({
    required this.onWillLayout,
    required this.onHeightDelta,
  });

  VoidCallback onWillLayout;
  ValueChanged<double> onHeightDelta;
  bool _hasLaidOut = false;
  double? _previousHeight;

  @override
  void markNeedsLayout() {
    if (_hasLaidOut) onWillLayout();
    super.markNeedsLayout();
  }

  @override
  void performLayout() {
    final previousHeight = _previousHeight;
    super.performLayout();
    final currentHeight = size.height;
    _previousHeight = currentHeight;
    _hasLaidOut = true;
    if (previousHeight != null) onHeightDelta(currentHeight - previousHeight);
  }
}
