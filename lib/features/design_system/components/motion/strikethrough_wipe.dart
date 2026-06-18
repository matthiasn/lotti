import 'package:flutter/material.dart';

/// Animates a strikethrough onto [text] left→right when [done] flips to true,
/// rather than hard-swapping the line on — the small reward beat for the most
/// repeated micro-interaction (checking a list item off).
///
/// It renders the unstruck text as the base and reveals a struck copy over it
/// through an expanding clip, so multi-line text strikes cleanly and the two
/// layers stay glyph-aligned (same string, style metrics, and wrapping). Under
/// reduced motion the struck state applies instantly with no wipe. A row that
/// is already done on first build shows the struck text immediately (the wipe
/// only plays on the transition).
class StrikethroughWipe extends StatefulWidget {
  const StrikethroughWipe({
    required this.done,
    required this.text,
    required this.baseStyle,
    required this.struckStyle,
    this.maxLines,
    this.overflow,
    this.duration = const Duration(milliseconds: 220),
    super.key,
  });

  final bool done;
  final String text;

  /// Style for the un-struck text (the resting state).
  final TextStyle baseStyle;

  /// Style for the struck text — same metrics as [baseStyle] plus
  /// `TextDecoration.lineThrough` (and usually a muted color).
  final TextStyle struckStyle;

  final int? maxLines;
  final TextOverflow? overflow;
  final Duration duration;

  @override
  State<StrikethroughWipe> createState() => _StrikethroughWipeState();
}

class _StrikethroughWipeState extends State<StrikethroughWipe>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: widget.done ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(StrikethroughWipe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.done == widget.done) return;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller.value = widget.done ? 1 : 0;
    } else if (widget.done) {
      _controller.forward(from: 0);
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
    final base = Text(
      widget.text,
      style: widget.baseStyle,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
    final struck = Text(
      widget.text,
      style: widget.struckStyle,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
    return Stack(
      children: [
        base,
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              if (_controller.value <= 0) return const SizedBox.shrink();
              return ClipRect(
                clipper: _RevealClipper(_controller.value),
                child: struck,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Clips to the left [progress] fraction of the available width, revealing the
/// struck text from the start of the line outward.
class _RevealClipper extends CustomClipper<Rect> {
  _RevealClipper(this.progress);

  final double progress;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * progress, size.height);

  @override
  bool shouldReclip(_RevealClipper oldClipper) =>
      oldClipper.progress != progress;
}
