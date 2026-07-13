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
  });

  bool _isHolding = false;
  double _pendingExtentDelta = 0;
  Timer? _releaseTimer;

  /// Preserves the current viewport content until [duration] elapses.
  void hold(Duration duration) {
    if (duration <= Duration.zero) return;
    _isHolding = true;
    _releaseTimer?.cancel();
    _releaseTimer = Timer(duration, _releaseAnchor);
  }

  void _releaseAnchor() {
    _releaseTimer?.cancel();
    _releaseTimer = null;
    _isHolding = false;
    _pendingExtentDelta = 0;
  }

  void _releaseAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _releaseAnchor());
  }

  void _reportExtentDelta(double delta) {
    if (!_isHolding ||
        delta.abs() <= _ViewportStableScrollPosition._tolerance) {
      return;
    }
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
    _releaseAnchor();
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
  static const _tolerance = 0.5;

  @override
  bool correctForNewDimensions(
    ScrollMetrics oldPosition,
    ScrollMetrics newPosition,
  ) {
    if (!super.correctForNewDimensions(oldPosition, newPosition)) return false;
    if (isScrollingNotifier.value) {
      controller._releaseAnchor();
      return true;
    }

    if (!controller._isHolding) return true;
    final delta = controller._takePendingExtentDelta();
    if (delta.abs() <= _tolerance) return true;
    final target = (pixels + delta).clamp(
      newPosition.minScrollExtent,
      newPosition.maxScrollExtent,
    );
    if ((target - pixels).abs() <= _tolerance) return true;
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
      controller.hold(widget.duration + MotionDurations.short2);
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
