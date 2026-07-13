import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/motion_tokens.dart';

/// Reveals newly inserted content with a one-shot vertical expansion and fade.
///
/// Existing content should pass `animate: false` so initial page construction
/// remains immediate. Reduced-motion settings also resolve the transition
/// immediately.
class SizeFadeEntrance extends StatefulWidget {
  const SizeFadeEntrance({
    required this.child,
    this.animate = true,
    this.duration = MotionDurations.medium2,
    super.key,
  });

  final Widget child;
  final bool animate;
  final Duration duration;

  @override
  State<SizeFadeEntrance> createState() => _SizeFadeEntranceState();
}

class _SizeFadeEntranceState extends State<SizeFadeEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _size = CurvedAnimation(
    parent: _controller,
    curve: MotionCurves.emphasizedDecelerate,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: MotionCurves.standard,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.animate && !MediaQuery.disableAnimationsOf(context)) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      alignment: Alignment.topCenter,
      sizeFactor: _size,
      child: FadeTransition(opacity: _fade, child: widget.child),
    );
  }
}
