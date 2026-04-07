import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lotti/features/dashboards/widgetbook/insights_mock_data.dart';
import 'package:lotti/features/dashboards/widgetbook/productivity_patterns_widgetbook.dart';
import 'package:lotti/features/dashboards/widgetbook/time_distribution_widgetbook.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:widgetbook/widgetbook.dart';

/// Accent color from Figma: rgb(94, 212, 183).
const _accent = Color(0xFF5ED4B7);

/// Delta-negative red from Figma: rgb(230, 102, 77).
const _deltaRed = Color(0xFFE5664D);

/// Neutral delta color: rgb(102, 102, 102).
const _deltaNeutral = Color(0xFF666666);

WidgetbookFolder buildInsightsWidgetbookFolder() {
  return WidgetbookFolder(
    name: 'Insights',
    children: [
      WidgetbookComponent(
        name: 'Insights dashboard',
        useCases: [
          WidgetbookUseCase(
            name: 'Overview',
            builder: (context) => const InsightsShowcasePage(),
          ),
        ],
      ),
      buildTimeDistributionWidgetbookComponent(),
      buildProductivityPatternsWidgetbookComponent(),
    ],
  );
}

/// Standalone Insights dashboard showcase — mobile layout.
///
/// Renders the full Insights page matching the Figma mobile design:
/// Header → Summary (2×2 metrics) → Time Distribution → Productivity
/// Patterns → Interruptions → Planning vs Reality → Wellbeing → Bottom nav.
/// All sections are stacked vertically in a single scrollable column.
class InsightsShowcasePage extends StatelessWidget {
  const InsightsShowcasePage({super.key});

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
              _PageHeader(tokens: tokens),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  children: [
                    _SummarySection(tokens: tokens),
                    const SizedBox(height: 24),
                    _TimeDistributionSection(tokens: tokens),
                    const SizedBox(height: 24),
                    _ProductivityPatternsSection(tokens: tokens),
                    const SizedBox(height: 24),
                    _InterruptionsSection(tokens: tokens),
                    const SizedBox(height: 24),
                    _PlanningVsRealitySection(tokens: tokens),
                    const SizedBox(height: 24),
                    _WellbeingSection(tokens: tokens),
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
// Page Header — "Insights" title, padding 12v / 16h
// ---------------------------------------------------------------------------

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.tokens});
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Insights',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: tokens.colors.text.highEmphasis,
              ),
            ),
          ),
          SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              Icons.notifications_outlined,
              size: 20,
              color: tokens.colors.text.highEmphasis,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary Section — "This week" + filter row, then 2×2 metric grid
// ---------------------------------------------------------------------------

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.tokens});
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    const cards = InsightsMockData.summaryCards;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'This week',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Filter',
                  style: TextStyle(
                    fontSize: 14,
                    color: tokens.colors.text.lowEmphasis,
                  ),
                ),
                const SizedBox(width: 12),
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
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _MetricCard(card: cards[0], tokens: tokens),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(card: cards[1], tokens: tokens),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _MetricCard(card: cards[2], tokens: tokens),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(card: cards[3], tokens: tokens),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.card, required this.tokens});
  final InsightStatCard card;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    final Color deltaColor;
    if (card.deltaPositive == true) {
      deltaColor = _accent;
    } else if (card.deltaPositive == null) {
      deltaColor = _deltaNeutral;
    } else {
      deltaColor = _accent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            card.label,
            style: TextStyle(
              fontSize: 12,
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            card.delta,
            style: TextStyle(fontSize: 12, color: deltaColor),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Time Distribution — horizontal bars, gap 16
// ---------------------------------------------------------------------------

class _TimeDistributionSection extends StatelessWidget {
  const _TimeDistributionSection({required this.tokens});
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'Time distribution', tokens: tokens),
        const SizedBox(height: 16),
        for (final entry in InsightsMockData.timeDistribution) ...[
          _TimeDistributionBar(entry: entry, tokens: tokens),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _TimeDistributionBar extends StatelessWidget {
  const _TimeDistributionBar({required this.entry, required this.tokens});
  final TimeDistributionEntry entry;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            entry.category,
            style: TextStyle(
              fontSize: 14,
              color: tokens.colors.text.mediumEmphasis,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final barWidth = constraints.maxWidth * entry.fraction;
              return Container(
                height: 20,
                decoration: BoxDecoration(
                  color: tokens.colors.background.level02,
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.centerLeft,
                child: Container(
                  width: barWidth,
                  height: 20,
                  decoration: BoxDecoration(
                    color: entry.color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 36,
          child: Text(
            '${entry.hours}h',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Productivity Patterns — donut rings + AI insight, gap 14
// ---------------------------------------------------------------------------

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

class _InterruptionsSection extends StatelessWidget {
  const _InterruptionsSection({required this.tokens});
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    const data = InsightsMockData.interruptionsData;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Interruptions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '↓ ${data.deltaPercent.abs()}% vs last week',
                  style: const TextStyle(fontSize: 12, color: _accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatColumn(
                  value: '12',
                  label: 'This week',
                  tokens: tokens,
                ),
              ),
              Expanded(
                child: _StatColumn(
                  value: '1.7',
                  label: 'Per session avg',
                  tokens: tokens,
                ),
              ),
              Expanded(
                child: _StatColumn(
                  value: 'Design',
                  label: 'Most interrupted',
                  tokens: tokens,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Stat column — value fontSize 16 Semi Bold, label fontSize 12, gap 2.
class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.value,
    required this.label,
    required this.tokens,
  });
  final String value;
  final String label;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: tokens.colors.text.highEmphasis,
          ),
        ),
        const SizedBox(height: 2),
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
// Planning vs Reality — no wrapper, gap 14
// ---------------------------------------------------------------------------

class _PlanningVsRealitySection extends StatelessWidget {
  const _PlanningVsRealitySection({required this.tokens});
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'Planning vs reality', tokens: tokens),
        const SizedBox(height: 14),
        for (final entry in InsightsMockData.planningVsReality) ...[
          _PlanVsActualRow(entry: entry, tokens: tokens),
          const SizedBox(height: 14),
        ],
        Row(
          children: [
            Expanded(
              child: _LegendDot(
                color: _accent.withValues(alpha: 0.16),
                label: 'Planned',
                tokens: tokens,
              ),
            ),
            Expanded(
              child: _LegendDot(
                color: _accent,
                label: 'Actual',
                tokens: tokens,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PlanVsActualRow extends StatelessWidget {
  const _PlanVsActualRow({required this.entry, required this.tokens});
  final PlanVsActualEntry entry;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                entry.category,
                style: TextStyle(
                  fontSize: 14,
                  color: tokens.colors.text.highEmphasis,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              entry.delta,
              style: const TextStyle(fontSize: 12, color: _deltaRed),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ComparisonBar(
                  fraction: entry.plannedFraction,
                  maxWidth: constraints.maxWidth,
                  color: _accent.withValues(alpha: 0.16),
                ),
                const SizedBox(height: 3),
                _ComparisonBar(
                  fraction: entry.actualFraction,
                  maxWidth: constraints.maxWidth,
                  color: _accent,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ComparisonBar extends StatelessWidget {
  const _ComparisonBar({
    required this.fraction,
    required this.maxWidth,
    required this.color,
  });
  final double fraction;
  final double maxWidth;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: maxWidth * fraction,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
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
// Wellbeing — stroke border, radius 16, padding 16, gap 12
// ---------------------------------------------------------------------------

class _WellbeingSection extends StatelessWidget {
  const _WellbeingSection({required this.tokens});
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    const data = InsightsMockData.wellbeingData;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wellbeing',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatColumn(
                  value: data.avgSession,
                  label: 'Avg session',
                  tokens: tokens,
                ),
              ),
              Expanded(
                child: _StatColumn(
                  value: data.breaksTaken.toString(),
                  label: 'Breaks taken',
                  tokens: tokens,
                ),
              ),
              Expanded(
                child: _StatColumn(
                  value: data.longStreaks.toString(),
                  label: '4h+ streaks',
                  tokens: tokens,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AiInsightCard(
            text: data.aiTip,
            tokens: tokens,
            radius: 10,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            sparkFontSize: 14,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared section header — title (16px Semi Bold) + "See all" (14px accent)
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.tokens});
  final String title;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: tokens.colors.text.highEmphasis,
            ),
          ),
        ),
        const Text(
          'See all',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _accent,
          ),
        ),
      ],
    );
  }
}
