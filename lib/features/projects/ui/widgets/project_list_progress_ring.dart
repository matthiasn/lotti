// The tiny task-progress ring (threshold color + custom painter) —
// part of the project_list_shared library.
part of 'project_list_shared.dart';

Color _progressRingColor(
  BuildContext context,
  ProjectTaskRollupData taskRollup,
) {
  final completionPercent = taskRollup.completionPercent;

  if (completionPercent >= 80) {
    return ShowcasePalette.timeGreen(context);
  }
  if (completionPercent >= 50) {
    return ShowcasePalette.amber(context);
  }
  return ShowcasePalette.error(context);
}

class _TinyProgressRing extends StatelessWidget {
  const _TinyProgressRing({
    required this.progress,
    required this.progressColor,
    required this.trackColor,
    super.key,
  });

  final double progress;
  final Color progressColor;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 16,
      child: CustomPaint(
        painter: _TinyProgressRingPainter(
          progress: progress,
          trackColor: trackColor,
          progressColor: progressColor,
        ),
      ),
    );
  }
}

class _TinyProgressRingPainter extends CustomPainter {
  const _TinyProgressRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 2.285714;
    const inset = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas
      ..drawArc(rect, -math.pi / 2, math.pi * 2, false, trackPaint)
      ..drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * progress.clamp(0.0, 1.0),
        false,
        progressPaint,
      );
  }

  @override
  bool shouldRepaint(covariant _TinyProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progressColor != progressColor;
}
