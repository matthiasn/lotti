part of 'productivity_patterns_widgetbook.dart';

// ---------------------------------------------------------------------------
// Rating Donuts — 3 score ring cards, gap 10
// ---------------------------------------------------------------------------

class _RatingDonuts extends StatelessWidget {
  const _RatingDonuts({required this.tokens});
  final DsTokens tokens;

  static const List<
    ({String label, double value, double fraction, Color color})
  >
  _scores = [
    (
      label: 'Productivity',
      value: 7.2,
      fraction: 0.72,
      color: _productivityColor,
    ),
    (label: 'Energy', value: 6.1, fraction: 0.61, color: _energyColor),
    (label: 'Focus', value: 7.8, fraction: 0.78, color: _focusColor),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Stack vertically when width is too tight for 3 cards
        if (constraints.maxWidth < 300) {
          return Column(
            children: [
              for (var i = 0; i < _scores.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _ScoreRingCard(
                  label: _scores[i].label,
                  value: _scores[i].value,
                  fraction: _scores[i].fraction,
                  color: _scores[i].color,
                  tokens: tokens,
                ),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < _scores.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: _ScoreRingCard(
                  label: _scores[i].label,
                  value: _scores[i].value,
                  fraction: _scores[i].fraction,
                  color: _scores[i].color,
                  tokens: tokens,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ScoreRingCard extends StatelessWidget {
  const _ScoreRingCard({
    required this.label,
    required this.value,
    required this.fraction,
    required this.color,
    required this.tokens,
  });
  final String label;
  final double value;
  final double fraction;
  final Color color;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 48,
              maxWidth: 72,
              maxHeight: 72,
            ),
            child: AspectRatio(
              aspectRatio: 1,
              child: CustomPaint(
                painter: _DonutPainter(
                  fraction: fraction,
                  color: color,
                  trackColor: tokens.colors.decorative.level01,
                ),
                child: Center(
                  child: Text(
                    value.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: tokens.colors.text.mediumEmphasis,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.fraction,
    required this.color,
    required this.trackColor,
  });

  final double fraction;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final outerRadius = size.shortestSide / 2;
    final strokeWidth = outerRadius * 0.35;
    final radius = outerRadius - strokeWidth / 2;
    final center = Offset(size.width / 2, size.height / 2);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    canvas.drawCircle(center, radius, trackPaint);

    final sweepAngle = 2 * math.pi * fraction;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      fraction != oldDelegate.fraction ||
      color != oldDelegate.color ||
      trackColor != oldDelegate.trackColor;
}
