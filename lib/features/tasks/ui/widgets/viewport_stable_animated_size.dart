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
  int _holdRevision = 0;
  Timer? _releaseTimer;

  /// Preserves the current viewport content until [duration] elapses.
  void hold(Duration duration) {
    if (duration <= Duration.zero) return;
    if (!_isHolding) _holdRevision++;
    _isHolding = true;
    _releaseTimer?.cancel();
    _releaseTimer = Timer(duration, _releaseAnchor);
  }

  void _releaseAnchor() {
    _releaseTimer?.cancel();
    _releaseTimer = null;
    _isHolding = false;
  }

  void _releaseAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _releaseAnchor());
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
  int _holdRevision = -1;
  double? _correctedMaxScrollExtent;

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
    if (_holdRevision != controller._holdRevision) {
      _holdRevision = controller._holdRevision;
      _correctedMaxScrollExtent = null;
    }
    final previousMaxScrollExtent =
        _correctedMaxScrollExtent ?? oldPosition.maxScrollExtent;
    final delta = newPosition.maxScrollExtent - previousMaxScrollExtent;
    if (delta.abs() <= _tolerance) return true;
    _correctedMaxScrollExtent = newPosition.maxScrollExtent;
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
    final bottom = _bottomGlobal();
    final viewportTop = _viewportTopGlobal();
    if (bottom == null || viewportTop == null) return;
    final controller = _controller;
    if (bottom <= viewportTop && controller is ViewportStableScrollController) {
      controller.hold(widget.duration + MotionDurations.short2);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) return widget.child;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return _LayoutInvalidationReporter(
      onWillLayout: _holdIfFullyAboveViewport,
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
    required super.child,
  });

  final VoidCallback onWillLayout;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderLayoutInvalidationReporter(onWillLayout: onWillLayout);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderLayoutInvalidationReporter renderObject,
  ) {
    renderObject.onWillLayout = onWillLayout;
  }
}

class _RenderLayoutInvalidationReporter extends RenderProxyBox {
  _RenderLayoutInvalidationReporter({required this.onWillLayout});

  VoidCallback onWillLayout;
  bool _hasLaidOut = false;

  @override
  void markNeedsLayout() {
    if (_hasLaidOut) onWillLayout();
    super.markNeedsLayout();
  }

  @override
  void performLayout() {
    super.performLayout();
    _hasLaidOut = true;
  }
}
