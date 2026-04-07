import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/agents/model/daily_token_usage.dart';
import 'package:lotti/features/agents/state/token_stats_providers.dart';
import 'package:lotti/features/agents/ui/agent_token_usage_section.dart';
import 'package:lotti/features/agents/ui/wake_activity_chart.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';

/// Stats tab showing token usage in an iOS battery-usage-inspired layout.
///
/// Sections:
/// 1. Wake activity chart (migrated from pending wakes)
/// 2. Summary comparison card with interactive 7-day chart
/// 3. Per-model charts
/// 4. Per-template source breakdown list
class TokenStatsTab extends ConsumerStatefulWidget {
  const TokenStatsTab({super.key});

  @override
  ConsumerState<TokenStatsTab> createState() => _TokenStatsTabState();
}

class _TokenStatsTabState extends ConsumerState<TokenStatsTab> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final dailyAsync = ref.watch(dailyTokenUsageProvider(_days));
    final comparisonAsync = ref.watch(tokenUsageComparisonProvider(_days));
    final breakdownAsync = ref.watch(tokenSourceBreakdownProvider);
    final byModelAsync = ref.watch(dailyTokenUsageByModelProvider(_days));
    final tokens = context.designTokens;

    return ListView(
      padding: EdgeInsets.only(bottom: tokens.spacing.step10),
      children: [
        const WakeActivityChart(),
        SizedBox(height: tokens.spacing.step4),
        _DailyUsageSection(
          days: _days,
          dailyAsync: dailyAsync,
          comparisonAsync: comparisonAsync,
          onDaysChanged: (days) => setState(() => _days = days),
        ),
        SizedBox(height: tokens.spacing.step6),
        _PerModelChartsSection(byModelAsync: byModelAsync),
        SizedBox(height: tokens.spacing.step6),
        _SourceBreakdownSection(breakdownAsync: breakdownAsync),
      ],
    );
  }
}

// ── Daily Usage Section ─────────────────────────────────────────────────────

class _DailyUsageSection extends StatefulWidget {
  const _DailyUsageSection({
    required this.days,
    required this.dailyAsync,
    required this.comparisonAsync,
    required this.onDaysChanged,
  });

  final int days;
  final AsyncValue<List<DailyTokenUsage>> dailyAsync;
  final AsyncValue<TokenUsageComparison> comparisonAsync;
  final ValueChanged<int> onDaysChanged;

  @override
  State<_DailyUsageSection> createState() => _DailyUsageSectionState();
}

class _DailyUsageSectionState extends State<_DailyUsageSection> {
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.days - 1;
  }

  @override
  void didUpdateWidget(covariant _DailyUsageSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.days != widget.days) {
      _selectedIndex = widget.days - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final daysList = widget.dailyAsync.value;
    final periodTotal =
        daysList?.fold<int>(0, (s, d) => s + d.totalTokens) ?? 0;
    final periodWakes = daysList?.fold<int>(0, (s, d) => s + d.wakeCount) ?? 0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.messages.agentStatsDailyUsageHeading,
                style: context.textTheme.titleSmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              _DayRangeSelector(
                selected: widget.days,
                onChanged: widget.onDaysChanged,
              ),
            ],
          ),
          if (periodTotal > 0)
            Padding(
              padding: EdgeInsets.only(top: tokens.spacing.step1),
              child: Text(
                '${_formatTokenCount(periodTotal)} '
                '${context.messages.agentStatsTokensUnit}'
                '${periodWakes > 0 ? ' · $periodWakes ${context.messages.agentStatsWakesLabel.toLowerCase()}' : ''}',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          SizedBox(height: tokens.spacing.step3),

          // Card.
          Container(
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              borderRadius: BorderRadius.circular(tokens.radii.sectionCards),
            ),
            padding: EdgeInsets.all(tokens.spacing.step5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ComparisonSummary(
                  comparisonAsync: widget.comparisonAsync,
                ),
                SizedBox(height: tokens.spacing.step5),
                _ComparisonMetrics(
                  comparisonAsync: widget.comparisonAsync,
                ),
                SizedBox(height: tokens.spacing.step5),
                _InteractiveWeeklyChart(
                  days: daysList,
                  selectedIndex: _selectedIndex,
                  onBarTap: (i) => setState(
                    () => _selectedIndex = _selectedIndex == i ? null : i,
                  ),
                ),
                SizedBox(height: tokens.spacing.step3),
                const _ChartLegend(),
                // Detail panel for selected day.
                if (_selectedIndex != null &&
                    daysList != null &&
                    _selectedIndex! < daysList.length)
                  Padding(
                    padding: EdgeInsets.only(top: tokens.spacing.step4),
                    child: _SelectedDayDetail(day: daysList[_selectedIndex!]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Day Range Selector ──────────────────────────────────────────────────────

class _DayRangeSelector extends StatelessWidget {
  const _DayRangeSelector({
    required this.selected,
    required this.onChanged,
  });

  final int selected;
  final ValueChanged<int> onChanged;

  static const _options = [7, 30];

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.5,
        ),
        borderRadius: BorderRadius.circular(tokens.radii.s),
      ),
      padding: EdgeInsets.all(tokens.spacing.step1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final days in _options)
            GestureDetector(
              onTap: () => onChanged(days),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step3,
                  vertical: tokens.spacing.step1,
                ),
                decoration: BoxDecoration(
                  color: selected == days
                      ? tokens.colors.interactive.enabled.withValues(
                          alpha: 0.2,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(tokens.radii.xs),
                ),
                child: Text(
                  '${days}D',
                  style: context.textTheme.labelSmall?.copyWith(
                    color: selected == days
                        ? tokens.colors.interactive.enabled
                        : context.colorScheme.onSurfaceVariant,
                    fontWeight: selected == days
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Comparison Summary ──────────────────────────────────────────────────────

class _ComparisonSummary extends StatelessWidget {
  const _ComparisonSummary({required this.comparisonAsync});

  final AsyncValue<TokenUsageComparison> comparisonAsync;

  @override
  Widget build(BuildContext context) {
    final comparison = comparisonAsync.value;
    if (comparison == null) return const SizedBox(height: 20);

    final timeStr = _currentTimeString();
    final message = comparison.isAboveAverage
        ? context.messages.agentStatsUsageAboveAverage(timeStr)
        : context.messages.agentStatsUsageBelowAverage(timeStr);

    return Text(
      message,
      style: context.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ── Average vs Today Metrics ────────────────────────────────────────────────

class _ComparisonMetrics extends StatelessWidget {
  const _ComparisonMetrics({required this.comparisonAsync});

  final AsyncValue<TokenUsageComparison> comparisonAsync;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final comparison = comparisonAsync.value;
    if (comparison == null) return const SizedBox(height: 40);

    return Row(
      children: [
        _MetricColumn(
          label: context.messages.agentStatsAverageLabel,
          value: _formatTokenCount(comparison.averageTokensByTimeOfDay),
          unit: context.messages.agentStatsTokensUnit,
          valueColor: context.colorScheme.onSurfaceVariant,
        ),
        SizedBox(width: tokens.spacing.step7),
        _MetricColumn(
          label: context.messages.agentStatsTodayLabel,
          value: _formatTokenCount(comparison.todayTokens),
          unit: context.messages.agentStatsTokensUnit,
          valueColor: comparison.isAboveAverage
              ? tokens.colors.alert.warning.defaultColor
              : tokens.colors.interactive.enabled,
        ),
      ],
    );
  }
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({
    required this.label,
    required this.value,
    required this.unit,
    required this.valueColor,
  });

  final String label;
  final String value;
  final String unit;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.textTheme.bodySmall?.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: tokens.spacing.step1),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: context.textTheme.headlineMedium?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            SizedBox(width: tokens.spacing.step1),
            Text(
              unit,
              style: context.textTheme.bodySmall?.copyWith(
                color: valueColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Interactive Weekly Chart ────────────────────────────────────────────────

class _InteractiveWeeklyChart extends StatelessWidget {
  const _InteractiveWeeklyChart({
    required this.days,
    required this.selectedIndex,
    required this.onBarTap,
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
                    painter: _AverageDashedLinePainter(
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

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: totalHeight,
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: fullBarColor,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(tokens.radii.xs),
                  ),
                  border: isSelected
                      ? Border.all(
                          color: context.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            if (byTimeHeight > 0 && !day.isToday)
              SizedBox(
                height: byTimeHeight,
                child: Container(
                  decoration: BoxDecoration(
                    color: byTimeColor,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(tokens.radii.xs),
                    ),
                    border: isSelected
                        ? Border.all(
                            color: context.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          )
                        : null,
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

class _SelectedDayDetail extends StatelessWidget {
  const _SelectedDayDetail({required this.day});

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
                _formatTokenCount(day.totalTokens),
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

          // Metrics row.
          Row(
            children: [
              _MiniMetric(
                label: context.messages.agentStatsWakesLabel,
                value: '${day.wakeCount}',
              ),
              SizedBox(width: tokens.spacing.step5),
              if (day.tokensPerWake > 0)
                _MiniMetric(
                  label: context.messages.agentStatsTokensPerWakeLabel,
                  value: _formatTokenCount(day.tokensPerWake),
                ),
              if (day.tokensPerWake > 0) SizedBox(width: tokens.spacing.step5),
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
            _formatTokenCount(value),
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

class _ChartLegend extends StatelessWidget {
  const _ChartLegend();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final timeStr = _currentTimeString();

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

// ── Per-Model Charts Section ────────────────────────────────────────────────

class _PerModelChartsSection extends StatelessWidget {
  const _PerModelChartsSection({required this.byModelAsync});

  final AsyncValue<Map<String, List<DailyTokenUsage>>> byModelAsync;

  @override
  Widget build(BuildContext context) {
    final byModel = byModelAsync.value;
    if (byModel == null || byModel.length <= 1) {
      return const SizedBox.shrink();
    }

    final tokens = context.designTokens;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in byModel.entries) ...[
            _ModelChartCard(modelId: entry.key, days: entry.value),
            SizedBox(height: tokens.spacing.step3),
          ],
        ],
      ),
    );
  }
}

class _ModelChartCard extends StatefulWidget {
  const _ModelChartCard({
    required this.modelId,
    required this.days,
  });

  final String modelId;
  final List<DailyTokenUsage> days;

  @override
  State<_ModelChartCard> createState() => _ModelChartCardState();
}

class _ModelChartCardState extends State<_ModelChartCard> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final totalTokens = widget.days.fold<int>(0, (s, d) => s + d.totalTokens);

    final shortName = shortModelName(widget.modelId);

    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.4,
        ),
        borderRadius: BorderRadius.circular(tokens.radii.sectionCards),
      ),
      padding: EdgeInsets.all(tokens.spacing.step4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  shortName,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _formatTokenCount(totalTokens),
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
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
          _InteractiveWeeklyChart(
            days: widget.days,
            selectedIndex: _selectedIndex,
            onBarTap: (i) => setState(
              () => _selectedIndex = _selectedIndex == i ? null : i,
            ),
          ),
          if (_selectedIndex != null && _selectedIndex! < widget.days.length)
            Padding(
              padding: EdgeInsets.only(top: tokens.spacing.step3),
              child: _SelectedDayDetail(
                day: widget.days[_selectedIndex!],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Source Breakdown Section ─────────────────────────────────────────────────

class _SourceBreakdownSection extends StatelessWidget {
  const _SourceBreakdownSection({required this.breakdownAsync});

  final AsyncValue<List<TokenSourceBreakdown>> breakdownAsync;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final breakdowns = breakdownAsync.value;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.messages.agentStatsSourceActivityHeading,
            style: context.textTheme.titleSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: tokens.spacing.step3),
          if (breakdowns == null)
            const SizedBox(height: 40)
          else if (breakdowns.isEmpty)
            Text(
              context.messages.agentStatsNoUsage,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final source in breakdowns) _SourceListTile(source: source),
        ],
      ),
    );
  }
}

class _SourceListTile extends StatelessWidget {
  const _SourceListTile({required this.source});

  final TokenSourceBreakdown source;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final warningColor = tokens.colors.alert.warning.defaultColor;

    return InkWell(
      onTap: () =>
          beamToNamed('/settings/agents/templates/${source.templateId}'),
      borderRadius: BorderRadius.circular(tokens.radii.m),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: tokens.spacing.step3,
          horizontal: tokens.spacing.step2,
        ),
        child: Row(
          children: [
            Container(
              width: tokens.spacing.step9,
              height: tokens.spacing.step9,
              decoration: BoxDecoration(
                color: context.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(tokens.radii.s),
              ),
              child: Icon(
                Icons.smart_toy_outlined,
                color: context.colorScheme.onPrimaryContainer,
                size: tokens.spacing.step6,
              ),
            ),
            SizedBox(width: tokens.spacing.step3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source.displayName,
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: tokens.spacing.step1),
                  Text(
                    _activityDescription(context, source),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (source.isHighUsage)
              Padding(
                padding: EdgeInsets.only(right: tokens.spacing.step2),
                child: Icon(
                  Icons.error_rounded,
                  color: warningColor,
                  size: tokens.spacing.step5,
                ),
              ),
            Text(
              '${source.percentage.round()} %',
              style: context.textTheme.bodyMedium?.copyWith(
                color: source.isHighUsage
                    ? warningColor
                    : context.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            SizedBox(width: tokens.spacing.step2),
            Icon(
              Icons.chevron_right,
              color: context.colorScheme.onSurfaceVariant,
              size: tokens.spacing.step5,
            ),
          ],
        ),
      ),
    );
  }

  String _activityDescription(
    BuildContext context,
    TokenSourceBreakdown source,
  ) {
    final parts = <String>[];
    if (source.totalDuration > Duration.zero) {
      parts.add(
        context.messages.agentStatsSourceActiveFor(
          _formatDuration(source.totalDuration),
        ),
      );
    }
    parts.add(context.messages.agentStatsSourceWakes(source.wakeCount));
    return parts.join(' \u00b7 ');
  }
}

// ── Dashed Line Painter ─────────────────────────────────────────────────────

/// Paints a dashed horizontal line at [fraction] of the canvas height
/// (measured from the bottom), directly on the canvas with no layout overhead.
class _AverageDashedLinePainter extends CustomPainter {
  _AverageDashedLinePainter({
    required this.fraction,
    required this.color,
  });

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const dashWidth = 4.0;
    const dashSpace = 3.0;
    final y = size.height * (1 - fraction);
    var startX = 0.0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, y),
        Offset(math.min(startX + dashWidth, size.width), y),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_AverageDashedLinePainter oldDelegate) =>
      fraction != oldDelegate.fraction || color != oldDelegate.color;
}

// ── Helpers ─────────────────────────────────────────────────────────────────

String _currentTimeString() {
  final now = clock.now().toLocal();
  return '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}';
}

String _formatTokenCount(int tokens) {
  if (tokens >= 1000000) {
    return '${(tokens / 1000000).toStringAsFixed(1)}M';
  }
  if (tokens >= 1000) {
    return '${(tokens / 1000).toStringAsFixed(1)}K';
  }
  return tokens.toString();
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  return '${minutes}m';
}
