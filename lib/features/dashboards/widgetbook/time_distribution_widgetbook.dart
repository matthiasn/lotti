import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lotti/features/dashboards/widgetbook/insights_mock_data.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:widgetbook/widgetbook.dart';

/// Accent color from Figma.
const _accent = Color(0xFF2BA184);

/// Delta-negative red.
const _deltaRed = Color(0xFFE5664D);

WidgetbookComponent buildTimeDistributionWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Time distribution',
    useCases: [
      WidgetbookUseCase(
        name: 'Detail',
        builder: (context) => const TimeDistributionDetailPage(),
      ),
    ],
  );
}

/// Time Distribution detail page — mobile layout.
///
/// Renders: Header with back + title + week dropdown →
/// Donut chart (180px) with center label → Category list with dots →
/// "vs last week" label → Week comparison rows.
class TimeDistributionDetailPage extends StatelessWidget {
  const TimeDistributionDetailPage({super.key});

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
                    // Donut chart
                    _DonutChartSection(tokens: tokens),
                    const SizedBox(height: 24),
                    // Category list
                    _CategoryListSection(tokens: tokens),
                    const SizedBox(height: 24),
                    // "vs last week" label
                    Text(
                      'vs last week',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: tokens.colors.text.highEmphasis,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Week comparison rows
                    _WeekComparisonSection(tokens: tokens),
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
// Detail Header — Back button + "Time distribution" title + Week dropdown
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
          // Back row
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
          // Title row with dropdown
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Time distribution',
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
// Donut Chart — 180×180 multi-segment donut with "24.5h total" center
// ---------------------------------------------------------------------------

class _DonutChartSection extends StatelessWidget {
  const _DonutChartSection({required this.tokens});
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 180,
        height: 180,
        child: CustomPaint(
          painter: _MultiSegmentDonutPainter(
            entries: InsightsMockData.timeDistribution,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '24.5h',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
                Text(
                  'total',
                  style: TextStyle(
                    fontSize: 12,
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MultiSegmentDonutPainter extends CustomPainter {
  _MultiSegmentDonutPainter({required this.entries});
  final List<TimeDistributionEntry> entries;

  /// Gap between segments in radians (~1.7°), matching Figma.
  static const _segmentGap = 0.03;

  @override
  void paint(Canvas canvas, Size size) {
    final outerRadius = size.shortestSide / 2;
    // Figma innerRadius = 0.65 → stroke = outerRadius * (1 - 0.65)
    final strokeWidth = outerRadius * 0.35;
    final radius = outerRadius - strokeWidth / 2;
    final center = Offset(size.width / 2, size.height / 2);

    // Segments with gaps
    final totalGap = _segmentGap * entries.length;
    final usableAngle = 2 * math.pi - totalGap;
    var startAngle = -math.pi / 2;

    for (final entry in entries) {
      final sweepAngle = usableAngle * entry.fraction;
      final paint = Paint()
        ..color = entry.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle + _segmentGap;
    }
  }

  @override
  bool shouldRepaint(_MultiSegmentDonutPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Category List — colored dot + name + hours + percentage, with dividers
// ---------------------------------------------------------------------------

class _CategoryListSection extends StatelessWidget {
  const _CategoryListSection({required this.tokens});
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    const entries = InsightsMockData.timeDistribution;
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          _CategoryRow(entry: entries[i], tokens: tokens),
          if (i < entries.length - 1)
            Divider(
              height: 1,
              color: tokens.colors.decorative.level01,
            ),
        ],
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.entry, required this.tokens});
  final TimeDistributionEntry entry;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          // Color dot
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: entry.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          // Category name
          Expanded(
            child: Text(
              entry.category,
              style: TextStyle(
                fontSize: 14,
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ),
          // Hours
          Text(
            '${entry.hours}h',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          const SizedBox(width: 12),
          // Percentage
          SizedBox(
            width: 36,
            child: Text(
              entry.percent,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
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
// Week Comparison — category + delta, gap 10
// ---------------------------------------------------------------------------

class _WeekComparisonSection extends StatelessWidget {
  const _WeekComparisonSection({required this.tokens});
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final entry in InsightsMockData.timeDistribution) ...[
          _WeekComparisonRow(entry: entry, tokens: tokens),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _WeekComparisonRow extends StatelessWidget {
  const _WeekComparisonRow({required this.entry, required this.tokens});
  final TimeDistributionEntry entry;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    final deltaColor = entry.weekDeltaPositive ? _accent : _deltaRed;

    return Row(
      children: [
        Expanded(
          child: Text(
            entry.category,
            style: TextStyle(
              fontSize: 14,
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ),
        Text(
          entry.weekDelta,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: deltaColor,
          ),
        ),
      ],
    );
  }
}
