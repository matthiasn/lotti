part of 'insights_widgetbook.dart';

class _ProductivityPatternsSection extends StatelessWidget {
  const _ProductivityPatternsSection({required this.tokens});
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'Productivity patterns', tokens: tokens),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            const scores = InsightsMockData.productivityScores;
            // Stack vertically when width is too tight for 3 cards
            if (constraints.maxWidth < 300) {
              return Column(
                children: [
                  for (var i = 0; i < scores.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _ScoreRingCard(score: scores[i], tokens: tokens),
                  ],
                ],
              );
            }
            return Row(
              children: [
                for (var i = 0; i < scores.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: _ScoreRingCard(
                      score: scores[i],
                      tokens: tokens,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        _AiInsightCard(
          text: InsightsMockData.aiInsight,
          tokens: tokens,
        ),
      ],
    );
  }
}

class _ScoreRingCard extends StatelessWidget {
  const _ScoreRingCard({required this.score, required this.tokens});
  final ProductivityScore score;
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
                  fraction: score.fraction,
                  color: score.color,
                  trackColor: tokens.colors.decorative.level01,
                ),
                child: Center(
                  child: Text(
                    score.value.toString(),
                    style: TextStyle(
                      fontSize: 16,
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
            score.label,
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
    final strokeWidth = outerRadius * 0.3;
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

// ---------------------------------------------------------------------------
// AI Insight Card
// ---------------------------------------------------------------------------

class _AiInsightCard extends StatelessWidget {
  const _AiInsightCard({
    required this.text,
    required this.tokens,
    this.radius = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    this.sparkFontSize = 16,
  });
  final String text;
  final DsTokens tokens;
  final double radius;
  final EdgeInsets padding;
  final double sparkFontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '✦',
            style: TextStyle(fontSize: sparkFontSize, color: _accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Interruptions — background fill, radius 16, padding 16, gap 12
// ---------------------------------------------------------------------------
