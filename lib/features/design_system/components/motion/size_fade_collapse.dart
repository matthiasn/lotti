import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lotti/features/design_system/theme/motion_tokens.dart';

/// Collapses content away — and brings it back — as a single unit.
///
/// The subtree is laid out **once at its natural size** and then painted
/// through a uniform scale, while the space it reserves shrinks by the *same*
/// factor. Painted size therefore equals reserved size on every frame, which is
/// the whole point of this widget: children can never spill out of the
/// shrinking box and get cropped.
///
/// That coupling is what a plain [AnimatedCrossFade]/[SizeTransition] collapse
/// does *not* give you. Those shrink the box while the child keeps its full
/// layout size, so a fixed-size child — a checkbox, an avatar, an icon — holds
/// its original dimensions and is sliced by the clip as the box closes around
/// it. [AnimatedCrossFade] is worse still: swapping to a zero-sized second
/// child re-lays-out the outgoing subtree against zero-size constraints, so its
/// contents jump to new positions on the first frame of the transition.
///
/// The scale anchor and the size anchor are both top-start and are deliberately
/// **not** configurable — if they diverged, the painted content would drift
/// outside the reserved band and the cropping would come straight back.
///
/// This is the exit counterpart to `SizeFadeEntrance`.
class SizeFadeCollapse extends StatefulWidget {
  const SizeFadeCollapse({
    required this.collapsed,
    required this.duration,
    required this.child,
    this.onCollapsed,
    super.key,
  });

  /// Whether the content should be collapsed away. Flipping this animates;
  /// the initial value is applied without animation.
  final bool collapsed;

  /// How long the collapse (and the reverse reveal) takes. Required rather
  /// than defaulted: callers routinely coordinate other timing with it — a
  /// scroll anchor waiting out the reflow, a hold timer ahead of it — and a
  /// silent default would let the two drift apart unnoticed.
  final Duration duration;

  final Widget child;

  /// Called once the content has fully collapsed away — after the animation,
  /// or at once under reduced motion. Lets an owner that keeps a departed
  /// subtree mounted only for the sake of this exit drop it afterwards, at
  /// zero height where unmounting moves nothing. Not called for content that
  /// starts out collapsed.
  final VoidCallback? onCollapsed;

  @override
  State<SizeFadeCollapse> createState() => _SizeFadeCollapseState();
}

class _SizeFadeCollapseState extends State<SizeFadeCollapse>
    with SingleTickerProviderStateMixin {
  /// 0 = fully shown, 1 = fully collapsed.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.collapsed ? 1 : 0,
  );

  /// The single factor behind the reserved height, the paint scale **and** the
  /// opacity. Deliberately one animation rather than three: nothing here can
  /// drift out of step with anything else, which is the property the widget
  /// exists to guarantee.
  ///
  /// [MotionCurves.standard] rather than an exit- or reflow-specific curve —
  /// this factor is simultaneously the content leaving and the gap closing, and
  /// the supporting-motion easing serves both without slamming the reflow shut
  /// at the end the way an accelerate curve would.
  late final Animation<double> _factor = Tween<double>(begin: 1, end: 0)
      .animate(
        CurvedAnimation(parent: _controller, curve: MotionCurves.standard),
      );

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_onStatus);
  }

  /// Reports a collapse that ran to the end. A status listener rather than
  /// the `forward()` future, so the reduced-motion snap — a plain value
  /// assignment — reports the same way. Delivered after the frame: the snap
  /// fires from [didUpdateWidget], mid-build, where an owner's `setState`
  /// would be illegal, and at zero height one frame's delay is invisible.
  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onCollapsed?.call();
    });
  }

  @override
  void didUpdateWidget(SizeFadeCollapse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.collapsed == widget.collapsed) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = widget.collapsed ? 1 : 0;
    } else if (widget.collapsed) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _factor,
      // Built once and passed through: only the cheap wrappers below rebuild
      // per frame, never the collapsing subtree itself.
      child: FadeTransition(opacity: _factor, child: widget.child),
      builder: (context, child) {
        final factor = _factor.value.clamp(0.0, 1.0);
        return TickerMode(
          // Stop the subtree's own animations only once it is fully gone —
          // muting them mid-collapse would freeze them half-played.
          enabled: factor > 0,
          child: ExcludeSemantics(
            excluding: widget.collapsed,
            child: ExcludeFocus(
              excluding: widget.collapsed,
              // On its way out it must not be tappable, even while still
              // partly visible.
              child: IgnorePointer(
                ignoring: widget.collapsed,
                child: ClipRect(
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    heightFactor: factor,
                    child: Transform.scale(
                      scale: factor,
                      alignment: AlignmentDirectional.topStart,
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
