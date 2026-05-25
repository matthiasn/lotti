import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// 220 px teal circle that fills its rim over [holdDuration] while
/// pressed. Releasing before completion bleeds the progress back to
/// zero. Reaching full fires [onConfirmed] once.
///
/// Mirrors `prototype/screens/commit.jsx → HoldToConfirm`.
class HoldToConfirm extends StatefulWidget {
  const HoldToConfirm({
    required this.onConfirmed,
    this.holdDuration = const Duration(milliseconds: 1200),
    this.size = 220,
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.holdDuration,
    )..addStatusListener(_onStatusChanged);
  }

  void _onStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_done) {
      _done = true;
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
    _controller.forward();
  }

  void _onPressUp() {
    if (_done) return;
    if (_controller.value < 1.0) {
      // Bleed off — design calls for a soft decay rather than a hard
      // snap-back, hence the eased reverse.
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final teal = tokens.colors.interactive.enabled;
    final tealDeep = tokens.colors.interactive.hover;
    final onTeal = tokens.colors.text.onInteractiveAlert;
    return GestureDetector(
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
                    _done ? Icons.check_rounded : Icons.lock_outline_rounded,
                    size: widget.size * 0.22,
                    color: onTeal,
                  ),
                  SizedBox(height: tokens.spacing.step2),
                  Text(
                    context.messages.dailyOsNextCommitHoldHint,
                    style: tokens.typography.styles.others.overline.copyWith(
                      color: onTeal.withValues(alpha: 0.85),
                    ),
                  ),
                  SizedBox(height: tokens.spacing.step1),
                  Text(
                    context.messages.dailyOsNextCommitHoldLabel,
                    style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                      color: onTeal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            // 6 px white progress rim painted over the gradient.
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _ProgressRingPainter(
                        progress: _controller.value,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  _ProgressRingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    const stroke = 6.0;
    final radius = size.shortestSide / 2 - stroke / 2;
    final center = Offset(size.width / 2, size.height / 2);
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
      old.progress != progress || old.color != color;
}
