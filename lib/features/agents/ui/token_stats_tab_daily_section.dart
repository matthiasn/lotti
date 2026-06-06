part of 'token_stats_tab.dart';

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
    if (comparison == null || !comparison.hasBaseline) {
      return const SizedBox(height: 20);
    }

    if (comparison.isAtAverage) return const SizedBox.shrink();

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
              style: context.textTheme.titleLarge?.copyWith(
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
