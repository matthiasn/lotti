import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:lotti/features/design_system/theme/motion_tokens.dart';
import 'package:lotti/features/tasks/util/scroll_anchor.dart';

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
  ScrollAnchor? _anchor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextController = TaskScrollStabilityScope.maybeControllerOf(context);
    if (identical(nextController, _controller)) return;
    _anchor?.dispose();
    _controller = nextController;
    _anchor = nextController == null
        ? null
        : ScrollAnchor(
            controller: nextController,
            locate: _bottomGlobal,
            holdDuration: widget.duration + MotionDurations.short2,
          );
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
    if (bottom <= viewportTop) _anchor?.hold();
  }

  bool _isFullyAboveViewport() {
    final bottom = _bottomGlobal();
    final viewportTop = _viewportTopGlobal();
    return bottom != null && viewportTop != null && bottom <= viewportTop;
  }

  @override
  void dispose() {
    _anchor?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) return widget.child;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return _HeightDeltaReporter(
      isFullyAboveViewport: _isFullyAboveViewport,
      onHeightDelta: (delta, {required wasFullyAboveViewport}) {
        if (wasFullyAboveViewport) {
          _anchor?.correctByLayoutDelta(delta, requireHold: false);
        }
      },
      child: AnimatedSize(
        alignment: Alignment.topCenter,
        duration: reduceMotion ? Duration.zero : widget.duration,
        curve: widget.curve,
        child: widget.child,
      ),
    );
  }
}

class _HeightDeltaReporter extends SingleChildRenderObjectWidget {
  const _HeightDeltaReporter({
    required this.isFullyAboveViewport,
    required this.onHeightDelta,
    required super.child,
  });

  final bool Function() isFullyAboveViewport;
  final void Function(
    double delta, {
    required bool wasFullyAboveViewport,
  })
  onHeightDelta;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderHeightDeltaReporter(
      isFullyAboveViewport: isFullyAboveViewport,
      onHeightDelta: onHeightDelta,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderHeightDeltaReporter renderObject,
  ) {
    renderObject
      ..isFullyAboveViewport = isFullyAboveViewport
      ..onHeightDelta = onHeightDelta;
  }
}

class _RenderHeightDeltaReporter extends RenderProxyBox {
  _RenderHeightDeltaReporter({
    required this.isFullyAboveViewport,
    required this.onHeightDelta,
  });

  bool Function() isFullyAboveViewport;
  void Function(
    double delta, {
    required bool wasFullyAboveViewport,
  })
  onHeightDelta;
  double? _previousHeight;
  bool _wasFullyAboveViewport = false;

  @override
  void performLayout() {
    // Use the position captured during the previous paint. Paint transforms
    // cannot be queried safely from inside layout, while the last painted
    // geometry is precisely the state whose visible position must be held.
    final previousHeight = _previousHeight;
    super.performLayout();
    final currentHeight = size.height;
    _previousHeight = currentHeight;
    if (previousHeight != null) {
      onHeightDelta(
        currentHeight - previousHeight,
        wasFullyAboveViewport: _wasFullyAboveViewport,
      );
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _wasFullyAboveViewport = isFullyAboveViewport();
    super.paint(context, offset);
  }
}
