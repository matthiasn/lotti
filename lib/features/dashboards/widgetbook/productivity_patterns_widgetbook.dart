import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:widgetbook/widgetbook.dart';

/// Colors matching the three rating categories.
const _productivityColor = Color(0xFF2BA184);
const _energyColor = Color(0xFFF29933);
const _focusColor = Color(0xFF5973D9);

WidgetbookComponent buildProductivityPatternsWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Productivity patterns',
    useCases: [
      WidgetbookUseCase(
        name: 'Detail',
        builder: (context) => const ProductivityPatternsDetailPage(),
      ),
    ],
  );
}

/// Productivity Patterns detail page — mobile layout.
///
/// Renders: Header → 3 score ring cards → Daily bar chart →
/// Highlights list.
class ProductivityPatternsDetailPage extends StatelessWidget {
  const ProductivityPatternsDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return DecoratedBox(
      decoration: BoxDecoration(color: tokens.colors.background.level01),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            children: [
              _DetailHeader(tokens: tokens),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  children: [
                    _RatingDonuts(tokens: tokens),
                    const SizedBox(height: 24),
                    _DailyBreakdownSection(tokens: tokens),
                    const SizedBox(height: 24),
                    _HighlightsSection(tokens: tokens),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header — Back + "Productivity patterns" + Week dropdown
// ---------------------------------------------------------------------------

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.tokens});
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.arrow_back_ios,
                  size: 20,
                  color: tokens.colors.text.highEmphasis,
                ),
                const SizedBox(width: 4),
                Text(
                  'Back',
                  style: TextStyle(
                    fontSize: 14,
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Productivity patterns',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: tokens.colors.background.level02,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Week',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: tokens.colors.text.highEmphasis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.expand_more,
                        size: 20,
                        color: tokens.colors.text.highEmphasis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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

// ---------------------------------------------------------------------------
// Daily Breakdown — title + 7-day bar chart + legend
// ---------------------------------------------------------------------------

class _DailyBreakdownSection extends StatelessWidget {
  const _DailyBreakdownSection({required this.tokens});
  final DsTokens tokens;

  /// Bar heights as fractions of max (120px). Order: productivity, energy, focus.
  static const List<({String day, List<double> bars})> _dayData = [
    (day: 'Mon', bars: [0.78, 0.67, 0.89]),
    (day: 'Tue', bars: [0.89, 0.78, 1.0]),
    (day: 'Wed', bars: [0.78, 0.56, 0.78]),
    (day: 'Thu', bars: [0.67, 0.56, 0.78]),
    (day: 'Fri', bars: [0.89, 0.78, 0.89]),
    (day: 'Sat', bars: [0.56, 0.44, 0.67]),
    (day: 'Sun', bars: [0.0, 0.0, 0.0]),
  ];

  static const List<Color> _barColors = [
    _productivityColor,
    _energyColor,
    _focusColor,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily breakdown',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: tokens.colors.text.highEmphasis,
          ),
        ),
        const SizedBox(height: 16),
        // Bar chart — 120px tall bars + 16px label = 140px
        SizedBox(
          height: 140,
          child: Row(
            children: [
              for (var i = 0; i < _dayData.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _DayColumn(
                    label: _dayData[i].day,
                    barFractions: _dayData[i].bars,
                    barColors: _barColors,
                    emptyColor: tokens.colors.background.level02,
                    labelColor: tokens.colors.text.mediumEmphasis,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Legend
        Row(
          children: [
            _LegendItem(
              color: _productivityColor,
              label: 'Productivity',
              tokens: tokens,
            ),
            const SizedBox(width: 16),
            _LegendItem(
              color: _energyColor,
              label: 'Energy',
              tokens: tokens,
            ),
            const SizedBox(width: 16),
            _LegendItem(
              color: _focusColor,
              label: 'Focus',
              tokens: tokens,
            ),
          ],
        ),
      ],
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.label,
    required this.barFractions,
    required this.barColors,
    required this.emptyColor,
    required this.labelColor,
  });
  final String label;
  final List<double> barFractions;
  final List<Color> barColors;
  final Color emptyColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Bars area — 120px, bottom-aligned
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < barFractions.length; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                Expanded(
                  child: FractionallySizedBox(
                    heightFactor: barFractions[i].clamp(0.02, 1.0),
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      decoration: BoxDecoration(
                        color: barFractions[i] > 0 ? barColors[i] : emptyColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: labelColor),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.tokens,
  });
  final Color color;
  final String label;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Highlights — title + 3 highlight cards with icons
// ---------------------------------------------------------------------------

class _HighlightsSection extends StatelessWidget {
  const _HighlightsSection({required this.tokens});
  final DsTokens tokens;

  static const List<({IconData icon, String text})> _highlights = [
    (
      icon: Icons.emoji_events,
      text: 'Best day: Tuesday — Productivity 8, Energy 7, Focus 9',
    ),
    (
      icon: Icons.trending_down,
      text: 'Lowest day: Saturday — Lower energy after a full week',
    ),
    (
      icon: Icons.trending_down,
      text: 'Peak hours: 9am – 12pm (focus avg 8.2)',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Highlights',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: tokens.colors.text.highEmphasis,
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < _highlights.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _HighlightCard(
            icon: _highlights[i].icon,
            text: _highlights[i].text,
            tokens: tokens,
          ),
        ],
      ],
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({
    required this.icon,
    required this.text,
    required this.tokens,
  });
  final IconData icon;
  final String text;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: tokens.colors.text.mediumEmphasis),
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
