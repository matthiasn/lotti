import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/agents/model/daily_token_usage.dart';
import 'package:lotti/features/agents/ui/token_stats_tab.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

class InteractiveWeeklyChart extends StatelessWidget {
  const InteractiveWeeklyChart({
    required this.days,
    required this.selectedIndex,
    required this.onBarTap,
    super.key,
  });

  final List<DailyTokenUsage>? days;
  final int? selectedIndex;
  final ValueChanged<int> onBarTap;

  static const _chartHeight = 120.0;

  @override
  Widget build(BuildContext context) {
    if (days == null) return const SizedBox(height: _chartHeight);
    return _buildChart(context, days!);
  }

  Widget _buildChart(BuildContext context, List<DailyTokenUsage> days) {
    final tokens = context.designTokens;
    final maxTokens = days.fold<int>(0, (m, d) => math.max(m, d.totalTokens));

    if (maxTokens == 0) {
      return SizedBox(
        height: _chartHeight,
        child: Center(
          child: Text(
            context.messages.agentStatsNoUsage,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final pastDays = days.where((d) => !d.isToday).toList();
    final avgTotal = pastDays.isEmpty
        ? 0.0
        : pastDays.fold<int>(0, (s, d) => s + d.tokensByTimeOfDay) /
              pastDays.length;
    final avgFraction = maxTokens > 0 ? avgTotal / maxTokens : 0.0;

    return Column(
      children: [
        SizedBox(
          height: _chartHeight,
          child: Stack(
            children: [
              // Average line — painted at exact Y, no layout hacks.
              if (avgTotal > 0)
                Positioned.fill(
                  child: CustomPaint(
                    painter: AverageDashedLinePainter(
                      fraction: avgFraction,
                      color: context.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.4,
                      ),
                    ),
                  ),
                ),
              // "Average" label, right-aligned at the line's Y.
              if (avgTotal > 0)
                Positioned(
                  bottom: _chartHeight * avgFraction,
                  right: 0,
                  child: Text(
                    context.messages.agentStatsAverageLabel,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < days.length; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: days.length > 10
                              ? 0.5
                              : tokens.spacing.step1,
                        ),
                        child: _DayBar(
                          day: days[i],
                          maxTokens: maxTokens,
                          chartHeight: _chartHeight,
                          isSelected: selectedIndex == i,
                          onTap: () => onBarTap(i),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.spacing.step2),
        _DayLabelsRow(
          days: days,
          selectedIndex: selectedIndex,
          onBarTap: onBarTap,
        ),
      ],
    );
  }
}

// ── Day Labels Row ──────────────────────────────────────────────────────────

class _DayLabelsRow extends StatelessWidget {
  const _DayLabelsRow({
    required this.days,
    required this.selectedIndex,
    required this.onBarTap,
  });

  final List<DailyTokenUsage> days;
  final int? selectedIndex;
  final ValueChanged<int> onBarTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // For 7 days: show every label (day-of-week letter).
    // For 30 days: show every 7th day as a date number.
    final showEvery = days.length <= 10 ? 1 : 7;

    return Row(
      children: [
        for (var i = 0; i < days.length; i++)
          Expanded(
            child: GestureDetector(
              onTap: () => onBarTap(i),
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: i % showEvery == 0 || i == days.length - 1
                    ? Text(
                        days.length <= 10
                            ? DateFormat.E()
                                  .format(days[i].date)
                                  .substring(0, 1)
                            : '${days[i].date.day}',
                        style: context.textTheme.labelSmall?.copyWith(
                          fontSize: days.length > 10 ? 9 : null,
                          color: days[i].isToday
                              ? tokens.colors.alert.warning.defaultColor
                              : selectedIndex == i
                              ? context.colorScheme.onSurface
                              : context.colorScheme.onSurfaceVariant,
                          fontWeight: days[i].isToday || selectedIndex == i
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Single Day Bar ──────────────────────────────────────────────────────────

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.day,
    required this.maxTokens,
    required this.chartHeight,
    this.isSelected = false,
    this.onTap,
  });

  final DailyTokenUsage day;
  final int maxTokens;
  final double chartHeight;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final totalFraction = maxTokens > 0 ? day.totalTokens / maxTokens : 0.0;
    final byTimeFraction = maxTokens > 0
        ? day.tokensByTimeOfDay / maxTokens
        : 0.0;

    if (totalFraction == 0) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: const SizedBox.expand(),
      );
    }

    final totalHeight = chartHeight * math.max(0.04, totalFraction);
    final byTimeHeight =
        chartHeight * math.max(0.0, math.min(byTimeFraction, totalFraction));

    final fullBarColor = day.isToday
        ? tokens.colors.alert.warning.defaultColor
        : isSelected
        ? context.colorScheme.onSurfaceVariant.withValues(alpha: 0.55)
        : context.colorScheme.onSurfaceVariant.withValues(alpha: 0.35);
    final byTimeColor = day.isToday
        ? tokens.colors.alert.warning.defaultColor.withValues(alpha: 0.6)
        : isSelected
        ? context.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)
        : context.colorScheme.onSurfaceVariant.withValues(alpha: 0.55);

    final showByTimePortion = byTimeHeight > 0 && !day.isToday;
    // When by-time fills the whole bar, it needs full rounding.
    final byTimeIsFullBar =
        showByTimePortion && (byTimeHeight >= totalHeight - 0.5);
    final cornerRadius = Radius.circular(tokens.radii.xs);
    final selectedBorder = isSelected
        ? Border.all(
            color: context.colorScheme.onSurface.withValues(alpha: 0.5),
          )
        : null;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: totalHeight,
        child: Column(
          children: [
            if (!byTimeIsFullBar)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: fullBarColor,
                    borderRadius: BorderRadius.vertical(top: cornerRadius),
                    border: selectedBorder,
                  ),
                ),
              ),
            if (showByTimePortion)
              SizedBox(
                height: byTimeIsFullBar ? totalHeight : byTimeHeight,
                child: Container(
                  decoration: BoxDecoration(
                    color: byTimeColor,
                    borderRadius: byTimeIsFullBar
                        ? BorderRadius.vertical(top: cornerRadius)
                        : BorderRadius.zero,
                    border: selectedBorder,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Selected Day Detail ─────────────────────────────────────────────────────

class SelectedDayDetail extends StatelessWidget {
  const SelectedDayDetail({required this.day, super.key});

  final DailyTokenUsage day;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final dateLabel = DateFormat.MMMEd().format(day.date);

    return Container(
      padding: EdgeInsets.all(tokens.spacing.step4),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.5,
        ),
        borderRadius: BorderRadius.circular(tokens.radii.m),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                dateLabel,
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                formatTokenCount(day.totalTokens),
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              SizedBox(width: tokens.spacing.step1),
              Text(
                context.messages.agentStatsTokensUnit,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.step3),

          // Token breakdown bars.
          _TokenBreakdownRow(
            label: context.messages.agentStatsInputLabel,
            value: day.inputTokens,
            total: day.totalTokens,
            color: context.colorScheme.primary,
          ),
          SizedBox(height: tokens.spacing.step2),
          _TokenBreakdownRow(
            label: context.messages.agentStatsOutputLabel,
            value: day.outputTokens,
            total: day.totalTokens,
            color: tokens.colors.alert.info.defaultColor,
          ),
          if (day.thoughtsTokens > 0) ...[
            SizedBox(height: tokens.spacing.step2),
            _TokenBreakdownRow(
              label: context.messages.agentStatsThoughtsLabel,
              value: day.thoughtsTokens,
              total: day.totalTokens,
              color: tokens.colors.alert.warning.defaultColor,
            ),
          ],
          SizedBox(height: tokens.spacing.step4),

          // Metrics row — only shown when wake data is available.
          if (day.wakeCount > 0 || day.cacheRate > 0)
            Row(
              children: [
                if (day.wakeCount > 0)
                  _MiniMetric(
                    label: context.messages.agentStatsWakesLabel,
                    value: '${day.wakeCount}',
                  ),
                if (day.wakeCount > 0) SizedBox(width: tokens.spacing.step5),
                if (day.tokensPerWake > 0)
                  _MiniMetric(
                    label: context.messages.agentStatsTokensPerWakeLabel,
                    value: formatTokenCount(day.tokensPerWake),
                  ),
                if (day.tokensPerWake > 0)
                  SizedBox(width: tokens.spacing.step5),
                if (day.cacheRate > 0)
                  _MiniMetric(
                    label: context.messages.agentStatsCacheRateLabel,
                    value: '${(day.cacheRate * 100).round()}%',
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TokenBreakdownRow extends StatelessWidget {
  const _TokenBreakdownRow({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  final String label;
  final int value;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final fraction = total > 0 ? value / total : 0.0;

    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        SizedBox(width: tokens.spacing.step2),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radii.xs),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: context.colorScheme.onSurfaceVariant.withValues(
                alpha: 0.1,
              ),
              color: color,
              minHeight: 6,
            ),
          ),
        ),
        SizedBox(width: tokens.spacing.step3),
        SizedBox(
          width: 52,
          child: Text(
            formatTokenCount(value),
            textAlign: TextAlign.end,
            style: context.textTheme.bodySmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
        SizedBox(height: tokens.spacing.step1),
        Text(
          value,
          style: context.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

// ── Chart Legend ─────────────────────────────────────────────────────────────

class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final timeStr = currentTimeString();

    return Row(
      children: [
        _LegendDot(
          color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
        ),
        SizedBox(width: tokens.spacing.step2),
        Text(
          context.messages.agentStatsAllDayLegend,
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(width: tokens.spacing.step5),
        _LegendDot(
          color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
        ),
        SizedBox(width: tokens.spacing.step2),
        Text(
          context.messages.agentStatsByTimeLegend(timeStr),
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
