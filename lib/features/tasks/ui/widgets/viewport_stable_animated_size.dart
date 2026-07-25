import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:lotti/features/design_system/theme/motion_tokens.dart';
import 'package:lotti/features/tasks/util/scroll_anchor.dart';

/// A task-details scroll controller that preserves visible content while an
/// armed off-screen region changes the scrollable's extent.
///
/// The position consumes exact region deltas while applying new content
/// dimensions, where the viewport can repeat layout with the corrected offset
/// before it paints. If unrelated content below the held region shrinks far
/// enough to force a range clamp, the position temporarily retains that
/// trailing extent until the user scrolls back inside the real range. This
/// avoids both a one-frame displacement and a delayed jump when the hold ends.
class ViewportStableScrollController extends ScrollController
    implements CooperativeScrollStabilizer {
  ViewportStableScrollController({
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
  }) {
    addListener(_releaseOnUnexpectedOffsetChange);
  }

  bool _isExplicitlyHolding = false;
  bool _isAnimatedSizeHolding = false;

  /// Whether the current explicit hold also admits regions that are stabilized
  /// only while they are scrolled above the viewport. See [hold].
  bool _isOffscreenRegionHoldArmed = false;
  double _pendingExtentDelta = 0;
  double? _expectedOffset;
  Timer? _explicitReleaseTimer;
  Timer? _animatedSizeReleaseTimer;

  static const _tolerance = 1.0;

  bool get _isHolding => _isExplicitlyHolding || _isAnimatedSizeHolding;

  double? get _desiredHeldOffset {
    final expectedOffset = _expectedOffset;
    if (!_isHolding || expectedOffset == null) return null;
    return expectedOffset + _pendingExtentDelta;
  }

  /// Explicitly preserves reported-region content until [duration] elapses.
  ///
  /// This hold is independent of the shorter automatic holds owned by
  /// [ViewportStableAnimatedSize], so an unrelated animation ending cannot
  /// release a checklist suggestion batch early.
  ///
  /// [includeOffscreenRegions] additionally admits deltas from regions built as
  /// `ViewportStableSizeReporter(offscreenOnly: true)` — regions whose own
  /// height change must be compensated only while they are out of sight. The
  /// AI card is the case this exists for: a proposal row collapsing inside it
  /// drags everything below the card up, which matters only when the card
  /// itself cannot be seen. While it is visible that reflow is the animation
  /// the user is watching, and compensating it would slide the card out from
  /// under their next tap.
  ///
  /// The caller owns that predicate rather than the region, because the caller
  /// must pick a matching post-frame [ScrollAnchor] in the same breath: the
  /// anchors either side of such a region cannot both be satisfied. Two
  /// mechanisms evaluating "is it off-screen?" independently would disagree
  /// over the padding between their reference points and then fight every
  /// frame.
  void hold(Duration duration, {bool includeOffscreenRegions = false}) {
    if (duration <= Duration.zero) return;
    _beginHold();
    _isExplicitlyHolding = true;
    _isOffscreenRegionHoldArmed = includeOffscreenRegions;
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

  @override
  bool ownsOffset(double offset) {
    final expectedOffset = _expectedOffset;
    return expectedOffset != null &&
        (offset - expectedOffset).abs() <= _tolerance;
  }

  @override
  void adoptCorrection(double target) {
    if (!_isHolding) return;
    _expectedOffset = target;
  }

  void _releaseOnUnexpectedOffsetChange() {
    if (positions.length != 1) return;
    final stablePosition = position;
    if (stablePosition is _ViewportStableScrollPosition) {
      stablePosition._releaseRetainedExtentIfWithinRealRange();
    }
    if (!_isHolding) return;
    final expectedOffset = _expectedOffset;
    if (expectedOffset == null) return;
    if ((offset - expectedOffset).abs() > _tolerance) {
      _releaseAllHolds();
    } else {
      _expectedOffset = offset;
    }
  }

  void _releaseExplicitHold() {
    _explicitReleaseTimer?.cancel();
    _explicitReleaseTimer = null;
    _isExplicitlyHolding = false;
    _isOffscreenRegionHoldArmed = false;
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
    _isOffscreenRegionHoldArmed = false;
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

  /// A delta from a region that is compensated only while it is off-screen;
  /// see [hold]'s `includeOffscreenRegions`.
  void _reportOffscreenRegionExtentDelta(double delta) {
    if (!_isOffscreenRegionHoldArmed) return;
    _reportExplicitExtentDelta(delta);
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
  double? _realMaxScrollExtent;
  double? _retainedMaxScrollExtent;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    _realMaxScrollExtent = maxScrollExtent;
    final desiredHeldOffset = controller._desiredHeldOffset;
    if (desiredHeldOffset != null && desiredHeldOffset > maxScrollExtent) {
      _retainedMaxScrollExtent = math.max(
        _retainedMaxScrollExtent ?? maxScrollExtent,
        desiredHeldOffset,
      );
      controller
        .._expectedOffset = desiredHeldOffset
        .._takePendingExtentDelta();
      if ((pixels - desiredHeldOffset).abs() >
          ViewportStableScrollController._tolerance) {
        correctPixels(desiredHeldOffset);
      }
    } else if ((_retainedMaxScrollExtent ?? double.infinity) <=
        maxScrollExtent + ViewportStableScrollController._tolerance) {
      _retainedMaxScrollExtent = null;
    }

    return super.applyContentDimensions(
      minScrollExtent,
      math.max(maxScrollExtent, _retainedMaxScrollExtent ?? maxScrollExtent),
    );
  }

  /// Keeps a temporary trailing extent while held content would otherwise be
  /// clamped upward by a simultaneous shrink below it. The extent remains
  /// until the user naturally scrolls back inside the real range, avoiding a
  /// delayed jump when the timed hold ends.
  void _releaseRetainedExtentIfWithinRealRange() {
    final realMaxScrollExtent = _realMaxScrollExtent;
    if (_retainedMaxScrollExtent == null || realMaxScrollExtent == null) return;
    if (pixels >
        realMaxScrollExtent + ViewportStableScrollController._tolerance) {
      return;
    }
    _retainedMaxScrollExtent = null;
    correctBy(0);
    final root = context.storageContext.findRenderObject();
    RenderAbstractViewport? viewport;
    void findViewport(RenderObject child) {
      if (viewport != null) return;
      if (child is RenderAbstractViewport) {
        viewport = child;
        return;
      }
      child.visitChildren(findViewport);
    }

    if (root is RenderAbstractViewport) {
      viewport = root;
    } else {
      root?.visitChildren(findViewport);
    }
    viewport?.markNeedsLayout();
  }

  @override
  bool correctForNewDimensions(
    ScrollMetrics oldPosition,
    ScrollMetrics newPosition,
  ) {
    if (isScrollingNotifier.value) {
      controller._releaseAllHolds();
      return super.correctForNewDimensions(oldPosition, newPosition);
    }

    if (controller._isHolding) {
      final delta = controller._takePendingExtentDelta();
      if (delta.abs() > ViewportStableScrollController._tolerance) {
        // Derive the correction from the last offset owned by the hold, not
        // [pixels]. When content below the reported region shrinks in the same
        // layout pass, Flutter may already have clamped [pixels] to the new max
        // extent before this hook runs. Applying [delta] to that clamped value
        // counts the reported shrink twice and visibly moves the held content.
        final heldOffset = controller._expectedOffset ?? pixels;
        final target = (heldOffset + delta).clamp(
          newPosition.minScrollExtent,
          newPosition.maxScrollExtent,
        );
        if ((target - pixels).abs() >
            ViewportStableScrollController._tolerance) {
          controller._expectedOffset = target;
          correctPixels(target);
          return false;
        }
      }
    }

    return super.correctForNewDimensions(oldPosition, newPosition);
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
///
/// Nest these only deliberately: two reporters over the same subtree both
/// accumulate into the same pending delta, and so does a
/// [ViewportStableAnimatedSize] wrapped inside one. Each band gets exactly one.
class ViewportStableSizeReporter extends StatelessWidget {
  const ViewportStableSizeReporter({
    required this.child,
    this.offscreenOnly = false,
    super.key,
  });

  final Widget child;

  /// Report this region's deltas only while the page armed its hold with
  /// [ViewportStableScrollController.hold]'s `includeOffscreenRegions` — i.e.
  /// only while the page has determined that this region is scrolled fully
  /// above the viewport.
  ///
  /// Regions the user can see must never be compensated this way: a proposal
  /// row collapsing inside a *visible* AI card is the reflow the user is
  /// watching, and correcting it would scroll the page under their pointer.
  /// The predicate lives with the page rather than here because the page must
  /// pick the matching anchor from the same answer — see
  /// [ViewportStableScrollController.hold].
  final bool offscreenOnly;

  @override
  Widget build(BuildContext context) {
    final controller = TaskScrollStabilityScope.maybeControllerOf(context);
    if (controller is! ViewportStableScrollController) return child;
    return _LayoutInvalidationReporter(
      onWillLayout: _noop,
      onHeightDelta: offscreenOnly
          ? controller._reportOffscreenRegionExtentDelta
          : controller._reportExplicitExtentDelta,
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
