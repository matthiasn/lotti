import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// 168 px teal circle that fills its rim over [holdDuration] while
/// pressed. Releasing before completion bleeds the progress back off
/// over ~400 ms. Reaching full fires [onConfirmed] once.
///
/// Inside the circle: just the lock icon and a single word —
/// `Hold` → `Keep holding` → `Committed` — no stacked sub-labels
/// (handoff v2 item 4). A quiet helper line sits below the circle.
///
/// Mirrors `prototype/screens/commit.jsx → HoldToConfirm`.
class HoldToConfirm extends StatefulWidget {
  const HoldToConfirm({
    required this.onConfirmed,
    this.holdDuration = const Duration(milliseconds: 1200),
    this.size = 168,
    super.key,
  });

  final VoidCallback onConfirmed;
  final Duration holdDuration;
  final double size;

  @override
  State<HoldToConfirm> createState() => _HoldToConfirmState();
}

class _HoldToConfirmState extends State<HoldToConfirm>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _done = false;
  bool _holding = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.holdDuration,
      // Releasing early bleeds the ring off — soft decay, no snap-back.
      reverseDuration: const Duration(milliseconds: 400),
    )..addStatusListener(_onStatusChanged);
  }

  void _onStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_done) {
      setState(() => _done = true);
      widget.onConfirmed();
    }
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_onStatusChanged)
      ..dispose();
    super.dispose();
  }

  void _onPressDown() {
    if (_done) return;
    setState(() => _holding = true);
    _controller.forward();
  }

  void _onPressUp() {
    if (_done) return;
    setState(() => _holding = false);
    if (_controller.value < 1.0) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final teal = tokens.colors.interactive.enabled;
    final tealDeep = tokens.colors.interactive.hover;
    final onTeal = tokens.colors.text.onInteractiveAlert;
    final word = _done
        ? messages.dailyOsNextCommitHoldWordDone
        : _holding
        ? messages.dailyOsNextCommitHoldWordHolding
        : messages.dailyOsNextCommitHoldWordIdle;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTapDown: (_) => _onPressDown(),
          onTapUp: (_) => _onPressUp(),
          onTapCancel: _onPressUp,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [teal, tealDeep],
                      stops: const [0.2, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: teal.withValues(alpha: 0.35),
                        blurRadius: 48,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _done
                            ? Icons.check_rounded
                            : Icons.lock_outline_rounded,
                        size: widget.size * 0.18,
                        color: onTeal,
                      ),
                      SizedBox(height: tokens.spacing.step2),
                      Text(
                        word,
                        style: tokens.typography.styles.subtitle.subtitle2
                            .copyWith(color: onTeal),
                      ),
                    ],
                  ),
                ),
                // 6 px progress rim over a faint full track ring.
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _ProgressRingPainter(
                            progress: _controller.value,
                            color: Colors.white,
                            trackColor: Colors.white.withValues(alpha: 0.18),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: tokens.spacing.step4),
        // Helper keeps its slot after completion so the layout
        // doesn't jump when the text empties.
        SizedBox(
          height: tokens.typography.lineHeight.caption,
          child: Text(
            _done ? '' : messages.dailyOsNextCommitHoldHelper,
            style: calmGreetingStyle(tokens),
          ),
        ),
      ],
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  _ProgressRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 6.0;
    final radius = size.shortestSide / 2 - stroke / 2;
    final center = Offset(size.width / 2, size.height / 2);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      progress * 2 * 3.14159,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor;
}
